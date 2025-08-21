using StringEncodings

"""
    read_data(filen)

Read the data from path filen into the ESM structure for writing.

Args:

- `filen::String`: String to where the excel file is.
"""
function read_data(filen)
    samples = groupby(DataFrame(XLSX.readtable(filen, "Samples")), :Plate)
    groups = DataFrame(XLSX.readtable(filen, "Groups"))
    trans = DataFrame(XLSX.readtable(filen, "Transformations"))
    views = DataFrame(XLSX.readtable(filen, "Views"))
    ID = DataFrame(XLSX.readtable(filen, "ID"))
    # Create the dict to show what channels need to be changed
    id_dict = Dict(i."Current" => i."Target" for i in eachrow(ID))
    sample_dict = OrderedDict()
    group_dict = OrderedDict(i.Group => Dict(
                                 "sample_IDs" => expand_groups(i.Name),
                                 :type => "experimental",
                                 "metadata" => Dict(j => i[j, :]
                                 for j in names(i) if !(j in ["Group", "Name"])))
    for i in eachrow(groups)) # Get all the experimental groups.
    @info "Reading $(length(keys(samples))) plates"
    for i in range(1, length(keys(samples)))
        data = Dict()
        # Check what instrument was used
        ins_type = Set(samples[i].Type)
        if contains(samples[i]."Data Location"[1], "\$GITHUB_WORKSPACE")
            samples[i]."Data Location"[1] = replace.(samples[i]."Data Location"[1], "\$GITHUB_WORKSPACE" => ENV["GITHUB_WORKSPACE"])
        end
        try
            length(ins_type) == 1
        catch
            error("All experiments on one plate must be from the same instrument types. \nInstrument types used here are: $(Set(samples[i].Type))")
        end
        # TODO Get channels should be its own function with separate tests
        # Process channels
        channels = []
        for j in samples[i].Channels
            # Add any channels that are in brackets to the list of channels
            for k in eachmatch(r"\(.+?\)", j)
                # Remove the brackets
                push!(channels, replace((string(k.match)), "(" => "", ")" => ""))
            end
            # Remove the bracket channels from the string
            j = replace(j, r"\(.+?\)" => "")
            # Add the remaining channels to the list
            for k in split(j, ",")
                push!(channels, k)
            end
        end
        channels = [c for c in channels if !isempty(c)]
        # Create the channel map
        channel_map = Dict(i => if i in keys(id_dict)
                                id_dict[i]
                            else
                                i
                            end for i in channels)
        @info "Channels $(join([string(j)*", " for j in channels])[1:end-2]) being used to process plate $i"
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
            error("Unknown instrument type: $ins_type")
        end
        # Add the physical plate to the group dict. This shouldn't be used by the user - this is more for record keeping
        group_dict["plate_0$i"] = Dict("sample_IDs" => broad_g, :type => "physical",
            "metadata" => :autodefined => "true")
    end
    # Add the transformations
    trans_dict = OrderedDict(i.Name => "equation" => i.Equation for i in eachrow(trans))
    # Add the views
    views_dict = OrderedDict(i.Name => :data => [split(i.Groups, ",")...]
    for i in eachrow(views))
    return OrderedDict(:samples => sample_dict, :groups => group_dict,
        :transformations => trans_dict, :views => views_dict)
end

"""
    expand_group(group::AbstractString)

Expand a condensed group name into the sample IDs it contains.
For example, if the group is "plate_0[1,2]_[a:c]2", it will return all sample IDs
from plate 1 to 2 and wells a2, b2, and c2.

Args:
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
                    append!(expanded, string.(parse(Int, start):parse(Int, step):parse(Int, stop)))
                else
                    append!(expanded, collect(start[1]:parse(Int, step):stop[1]))
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
            @show expanded
        else
            push!(expanded, well)
        end
        @show well
    end
    return expanded
end

"""
    write_esm(esm_dict, name)

Write the esm_dict from read_data() to the path/file `name`.

Args:

- `esm_dict::Dict`: Dictionary describing the esm.
- `name::String`: Path to deposit the ESM to.
"""
function write_esm(esm_dict, name)
    open(name, "w") do file
        JSON.print(file, esm_dict, 4)
    end
    @info "ESM written to $name"
end

"""
    read_pr(samples,sample_dict,channels,broad_g,channel_map)

Reads plate reader data - the master controller function.

Args:

- `samples::DataFrame`: Dataframe of samples to be read into sample_dict.
- `sample_dict::Dict`: A dictionary of the samples.
- `channels::Vector`: Channels to use.
- `broad_g::Vector`: The larger plate that this belongs to.
- `channel_map::Dict`: What to rename the channel to.
"""
function read_pr(samples, sample_dict, channels, broad_g, channel_map)
    @info "Processing plate reader data from plate $(unique(samples.Plate)[1])"
    # Check there is only one loc
    loc = unique(samples[!, "Data Location"])
    # Check what the plate-reader type is
    ptype = unique(samples[!, "Plate brand"])
    try
        length(loc) == 1
    catch
        error("Please give the location of only one folder containing all the CSVs for one plate. \nLocations given here are: $(Set(samples[!,"Data Location"])...)")
    end
    data = Dict()
    if isdir(loc)
        # Are the channels separated into different files named after the channels? - This is useful for generic data
        data = read_sep_chans_pr(channel_map, loc[1], channels)
    else
        length(ptype) == 1 ||
            error("Only one plat type can be used per plate. $(Set(samples[!,"Plate brand"])...) given. ")
        data = read_multipr_file("$(loc...)", ptype[1], channels, channel_map)
    end
    channels = keys(data)
    # Just so that the broader physical group can be defined using the set difference
    pre = keys(sample_dict)
    sample_dict = merge(sample_dict,
        OrderedDict("plate_0$(samples.Plate[1])_$(lowercase(k))" => Dict(
                        :type => "timeseries",
                        :values => Dict(i => data[i][!, k]
                        for i in channels if k in names(data[i])),
                        :meta => Dict())
        for k in names(data[Vector([channels...])[1]]) if isvalid(k)))
    broad_g = [i for i in keys(sample_dict) if !(i in pre)]
    return sample_dict, broad_g
end

"""
    extract_flow(fcs,chan)

Extract the metadata from a fcs file.

Args:

- `fcs::FCSFile`: The read FCS file
- `chan::String`: The channel being read from
"""
function extract_flow(fcs, chan)
    p = findfirst([i == chan for i in fcs.data.axes[1]])
    props = unique([i.match[4]
                    for i in eachmatch(Regex("\\\$P$(p)[A-Z]"), join(keys(fcs.params)))])
    Dict(
        :name => if 'N' in props
            fcs.params["\$P$(p)N"]
        else
            missing
        end,
        :amp_type => if 'E' in props
            fcs.params["\$P$(p)E"]
        else
            missing
        end,
        :range => if 'R' in props
            fcs.params["\$P$(p)R"]
        else
            missing
        end,
        :filter => if 'F' in props
            fcs.params["\$P$(p)F"]
        else
            missing
        end,
        :amp_gain => if 'G' in props
            fcs.params["\$P$(p)G"]
        else
            missing
        end,
        :ex_wav => if 'L' in props
            fcs.params["\$P$(p)L"]
        else
            missing
        end,
        :ex_pow => if 'O' in props
            fcs.params["\$P$(p)O"]
        else
            missing
        end,
        :perc_em => if 'P' in props
            fcs.params["\$P$(p)P"]
        else
            missing
        end,
        :name_s => if 'S' in props
            fcs.params["\$P$(p)S"]
        else
            missing
        end,
        :det_type => if 'T' in props
            fcs.params["\$P$(p)T"]
        else
            missing
        end,
        :det_volt => if 'V' in props
            fcs.params["\$P$(p)V"]
        else
            missing
        end
    )
end

"""
    read_flow(samples, sample_dict,channels,broad_g,channel_map)

Read the flow cytometry data from a file.

Args:

- `samples::DataFrame`: DataFrame of samples to read from.
- `sample_dict::Dict`: Output sample Dict.
- `channels::Vector`: Channels to read.
- `broad_g::Vector`: The physical group that this is part of.
- `channel_map::Dict`: The names to replace the old channel names with.
"""
function read_flow(samples, sample_dict, channels, broad_g, channel_map)
    @info "Processing flow cytometer data from plate $(unique(samples.Plate)[1])"
    for j in eachrow(samples)
        if ismissing(j.Name)
            name = "plate_0$(j.Plate)_$(lowercase(j.Well))"
        else
            name = j.Name
        end
        try
            temp = Dict()
            temp[:type] = "population"
            temp_data = load(j."Data Location")
            temp[:values] = Dict(channel_map[x] => temp_data["$(x)"] for x in channels)
            temp[:meta] = Dict(channel_map[x] => extract_flow(temp_data, "$x")
            for x in channels)
            sample_dict[name] = temp
        catch e
            @warn "\n\nFatal error encountered for well $name as file $(j."Data Location") is invalid - check the specified location or if the file is corrupted."
            throw(e)
        end
        broad_g = [broad_g; [name]]
    end
    return sample_dict, broad_g
end

"""
    read_multipr_file(filen,ptype,channels,channel_map)

Function for reading files containing multiple reads from multple channels from a single CSV file.
Returns a Dictionary of DataFrames with keys being the channels.
Currently works for Agilent (agilent), Tecan (tecan) and Spectramax (spectramax).
Presently uses regexes to seperate the files.

Args:

- `filen::String`: File to read from.
- `ptype::String`: The plate reader type being used.
- `channels::Vector`: Channels to be read in.
- `channel_map`: The new names for the channels.
"""
function read_multipr_file(filen, ptype, channels, channel_map)
    # TODO: Add bmg labtech reading
    o_dict = Dict()
    if ptype == "spectramax"
        o_dict = read_spectramax(filen, channels, channel_map)
    elseif ptype == "biotek"
        o_dict = read_biotek(filen, channels, channel_map)
    else
        error("Unknown plate reader type: $ptype.")
    end
    for i in keys(o_dict)
        o_dict[i] = o_dict[i][!, Not(all.(ismissing, eachcol(o_dict[i])))]
    end
    return o_dict
end

function read_into_lines(filen)
    encodings = ["UTF-16", "UTF-8", "windows-1252", "ISO-8859-1", "ASCII"]
    true_encoding = ""
    bytes = read(filen)
    for enc in encodings
        try
            str = decode(bytes, enc)
            if occursin("Time", str)
                true_encoding = enc
                break
            end
        catch e
            continue
        end
    end
    if true_encoding == ""
        error("Could not determine encoding for file $filen.")
    end
    str = decode(bytes, true_encoding)
    str = replace(str, "\r\n" => "\n")  # Normalize line endings
    str = replace(str, "\r" => "\n")    # Handle any remaining carriage returns
    return split(str, r"\n")  # Split into lines
end

function read_spectramax(filen, channels, channel_map)
    f = read_into_lines(filen)
    containsTime = [occursin(r"\d\d:\d\d:\d\d", j) ? 1 : 0 for j in f]
    function runlength(a, i)
        if i == length(a)
            return 1
        elseif a[i] == 1
            return runlength(a, i + 1) + 1
        else
            return 0
        end
    end
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Find and push header onto table (first row before i that contains Time and the row above it)
        for j in (i - 1):-1:1
            if occursin("Time", f[j])
                push!(table, f[j - 1])
                push!(table, f[j])
                break
            end
        end
        # Find and push the data onto table
        for j in i:length(f)
            if containsTime[j] == 1
                push!(table, f[j])
            else
                break
            end
        end
        push!(data, table)
    end
    # Create the dataframes
    out = Dict()
    for chan in channels
        for i in eachindex(data)
            if !occursin(chan, data[i][1])
                continue
            end
            # Get the data
            df = CSV.read(IOBuffer(join(data[i][2:end], "\n")), DataFrame, delim = "\t")
            # Remove empty columns
            df = df[:, Not(all.(ismissing, eachcol(df)))]
            # Do I need to drop temperature?)
            out[channel_map[chan]] = df
        end
    end
    return out
end

function read_biotek(filen, channels, channel_map)
    f = read_into_lines(filen)
    containsTime = [occursin(r"\d{1,2}:\d\d:\d\d", j) ? 1 : 0 for j in f]
    function runlength(a, i)
        if i == length(a)
            return 1
        elseif a[i] == 1
            return runlength(a, i + 1) + 1
        else
            return 0
        end
    end
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Find and push header onto table (first row before i that contains Time and the row above it)
        for j in (i - 1):-1:1
            if occursin("Time", f[j])
                push!(table, f[j - 2])
                push!(table, f[j])
                break
            end
        end
        # Find and push the data onto table
        for j in i:length(f)
            if containsTime[j] == 1
                push!(table, f[j])
            else
                break
            end
        end
        push!(data, table)
    end
    # Create the dataframes
    out = Dict()
    for chan in channels
        for i in eachindex(data)
            if !occursin(chan, data[i][1])
                continue
            end
            # Remove channel name from the first row
            data[i][2] = replace(data[i][2], " $(data[i][1])" => "")
            # Read the data into a DataFrame
            df = CSV.read(IOBuffer(join(data[i][2:end], "\n")), DataFrame)
            # Remove empty columns
            df = df[:, Not(all.(ismissing, eachcol(df)))]
            # Do I need to drop temperature?)
            out[channel_map[chan]] = df
        end
    end
    return out
end

"""
    read_sep_chans_pr(channel_map,loc,channels)

Function to read a separated set of csvs into the ESM.
All files are found in one dir and the names of them are the channel names.

Args:

- `channel_map::Dict`: What to rename the channel to once read.
- `loc::String`: Where the file actually is.
- `channels::Vector`: The channels to use to read the files.
"""
function read_sep_chans_pr(channel_map, loc, channels)
    # TODO Is there really only one format here? If so, do we still need to specify the brand for folders
    # TODO 1:(end-4) is a bit of a hack - this is to remove the .csv/.tsv from the end of the file
    out = Dict()
    for j in readdir(loc)
        if j[1:(end - 4)] in channels
            out[channel_map[j[1:(end - 4)]]] = CSV.read(joinpath(loc, j), DataFrame)
        elseif j[1:(end - 4)] in [channel_map[channel] for channel in channels]
            out[j[1:(end - 4)]] = CSV.read(joinpath(loc, j), DataFrame)
        end
    end
    return out
end
