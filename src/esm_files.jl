using Parameters
using DataFrames
using XLSX
using JSON
using DataStructures

@with_kw struct esm_zones
    samples::DataFrame
    groups::Any
    transformations::Any
    views::Any
end

"""
    read_esm(file::AbstractString)

Parse an esm file found at `file` into an esm_zones object.
"""
function read_esm(file::AbstractString)
    @info "Reading ESM file at: $file"
    # Read in the file in a JSON format
    ef = JSON.parsefile(file)
    max_len = 0
    # Loop over the samples to look for maximum length of array
    for i in keys(ef["samples"])
        for j in keys(ef["samples"][i]["values"])
            k = length(ef["samples"][i]["values"][j])
            if k > max_len
                max_len = k
            end
        end
    end
    # Create the ESM object
    es = esm_zones(
        samples = DataFrame(
            [(lowercase(i),
                 j,
                 ef["samples"][i]["type"],
                 replace(ef["samples"][i]["values"][j], nothing => NaN),
                 if !isempty(keys(ef["samples"][i]["meta"]))
                     ef["samples"][i]["meta"][j]
                 else
                     ef["samples"][i]["meta"]
                 end,
                 [i in lowercase.(ef["groups"][k]["sample_IDs"])
                  for k in keys(ef["groups"])]...) for i in keys(ef["samples"])
             for j in keys(ef["samples"][i]["values"])],
            ["name", "channel", "type", "values", "meta",
                [k for k in keys(ef["groups"])]...]),
        groups = DataFrame(
            [(i,
                 lowercase.(ef["groups"][i]["sample_IDs"]),
                 ef["groups"][i]["metadata"],
                 :(filter(row -> row.name in ef["groups"][i]["sample_IDs"],
                     samples, view = true))) for i in keys(ef["groups"])],
            ["group", "sample_IDs", "metadata", "meta_select"]),
        transformations = ef["transformations"],
        views = ef["views"]
    )
    # Add channels to sample names
    es.samples.name = string.(es.samples.name, ".", es.samples.channel)
    @info "ESM file successfully read."
    return es
end

"""
    write_esm(data, file::AbstractString)

Write the esm data to the path `file`.
"""
function write_esm(data, file::AbstractString)
    open(file, "w") do file
        JSON.print(file, data, 4)
    end
    @info "ESM written to $file"
end

"""
    read_data(file::AbstractString)

Read the data from path `file` into the correct structure.
"""
function read_data(file::AbstractString)
    samples = groupby(DataFrame(XLSX.readtable(file, "Samples")), :Plate)
    groups = DataFrame(XLSX.readtable(file, "Groups"))
    trans = DataFrame(XLSX.readtable(file, "Transformations"))
    views = DataFrame(XLSX.readtable(file, "Views"))
    channel_map = DataFrame(XLSX.readtable(file, "Channel Map"))
    # Create the dict to show what channels need to be changed
    channel_map = Dict(i."Channel" => i."New name" for i in eachrow(channel_map))
    sample_dict = OrderedDict()
    group_dict = OrderedDict(i.Name => Dict(
                                 "sample_IDs" => expand_groups(i.Samples),
                                 :type => "experimental",
                                 "metadata" => Dict(j => i[j, :]
                                 for j in names(i) if !(j in ["Name", "Samples"])))
    for i in eachrow(groups)) # Get all the experimental groups.
    @info "Reading $(length(keys(samples))) plates"
    for i in range(1, length(keys(samples)))
        data = Dict()
        # Check what instrument was used
        ins_type = Set(samples[i].Type)
        if contains(samples[i]."Data Location"[1], "\$GITHUB_WORKSPACE")
            samples[i]."Data Location"[1] = replace.(samples[i]."Data Location"[1],
                "\$GITHUB_WORKSPACE" => ENV["GITHUB_WORKSPACE"])
        end
        length(ins_type) == 1 ||
            error("All experiments on one plate must be from the same instrument types. \
            Instrument types used here are: $(Set(samples[i].Type))")
        # TODO Get channels should be its own function with separate tests
        # Process channels
        channels = []
        for j in samples[i].Channels
            # Convert to string if not already
            str_j = string(j)
            # Add any channels that are in brackets to the list of channels
            for k in eachmatch(r"\(.+?\)", str_j)
                # Remove the brackets
                push!(channels, replace((string(k.match)), "(" => "", ")" => ""))
            end
            # Remove the bracket channels from the string
            str_j = replace(str_j, r"\(.+?\)" => "")
            # Add the remaining channels to the list
            for k in split(str_j, ",")
                push!(channels, k)
            end
        end
        channels = [c for c in channels if !isempty(c)]
        # Create the channel map
        channel_map = Dict(i => if i in keys(channel_map)
                               channel_map[i]
                           else
                               i
                           end for i in channels)
        tmp = join([string(j) * ", " for j in channels])[1:(end - 2)]
        @info "Channels $tmp being used to process plate $i"
        # Just for pretty printing. Makes the channel map look nice
        prb = ["$j -> $(channel_map[j])\n" for j in keys(channel_map)]
        @info "Channel map: \n$(prb...)\n"
        broad_g = []
        if "plate reader" in lowercase.(ins_type)
            sample_dict, broad_g = read_pr(
                samples[i], sample_dict, channels, broad_g, channel_map)
        elseif "flow" in lowercase.(ins_type)
            sample_dict, broad_g = read_flow(
                samples[i], sample_dict, channels, broad_g, channel_map)
        else
            error("Unknown instrument type: $(first(ins_type))")
        end
        # Add the physical plate to the group dict
        group_dict["plate_0$i"] = Dict("sample_IDs" => broad_g, :type => "physical",
            "metadata" => :autodefined => "true")
    end
    # Add the transformations
    trans_dict = OrderedDict(i.Name => "equation" => i.Equation for i in eachrow(trans))
    # Add the views
    views_dict = OrderedDict(i.Name => :data => [split(i.View, ",")...]
    for i in eachrow(views))
    return OrderedDict(:samples => sample_dict, :groups => group_dict,
        :transformations => trans_dict, :views => views_dict)
end

"""
    expand_group(group::AbstractString)

Expand a condensed group name into the sample IDs it contains.
For example, if the group is "plate_0[1,2]_[a:c]2", it will return all sample IDs
from plate 1 to 2 and wells a2, b2, and c2.

Arguments:
- `group::AbstractString`: The group name to expand.

Returns:
- `Vector{String}`: A vector of sample IDs contained in the group.
"""
function expand_group(group::AbstractString)
    parts = []
    for match in eachmatch(r"\[([^\]]+)\]", group)
        s = match.captures[1]
        expanded = []
        for item in split(s, ",")
            item = strip(item)
            if occursin(":", item)
                if count(==(':'), item) == 2
                    start, step, stop = split(item, ":")
                else
                    start, stop = split(item, ":")
                    step = "1"
                end
                if occursin(r"\d", start)
                    indexes = parse(Int, start):parse(Int, step):parse(Int, stop)
                    append!(expanded,
                        string.(indexes))
                else
                    indexes = start[1]:parse(Int, step):stop[1]
                    append!(expanded, collect(indexes))
                end
            else
                push!(expanded, item)
            end
        end
        push!(parts, expanded)
    end
    # Replace bracketed sections with "{}" for formatting
    fmt = replace(group, r"\[[^\]]+\]" => "{}")
    ids = []
    for x in Iterators.product(parts...)
        id = fmt
        for (i, y) in enumerate(eachmatch(r"\{\}", fmt))
            id = replace(id, y.match => x[i], count = 1)
        end
        push!(ids, id)
    end
    return ids
end

"""
    expand_groups(groups::AbstractString)

Iteratively call `expand_group` on a comma-separated list of group names.
"""
function expand_groups(groups::AbstractString)
    expanded = []
    # Split on commas not inside brackets
    # Split on commas not inside brackets
    wells = split(groups, r",(?![^\[]*\])")
    for well in wells
        well = strip(well)
        if occursin(r"\[|\]", well)
            append!(expanded, expand_group(well))
        else
            push!(expanded, well)
        end
    end
    return expanded
end
