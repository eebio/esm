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
                                 "sample_IDs" => replace.(
                                     Vector(split(i.Name, ",")), " " => ""),
                                 :type => "experimental",
                                 "metadata" => Dict(j => i[j, :]
                                 for j in names(i) if !(j in ["Group", "Name"])))
    for i in eachrow(groups)) # Get all the experimental groups.
    @info "Reading $(length(keys(samples))) plates"
    for i in range(1, length(keys(samples)))
        data = Dict()
        # Check what instrument was used
        ins_type = Set(samples[i].Type)
        try
            length(ins_type) == 1
        catch
            error("All experiments on one plate must be from the same instrument types. \nInstrument types used here are: $(Set(samples[i].Type))")
        end
        if true in [occursin('(', j) for j in unique(samples[i].Channels)]
            # Channel checks - is this a comma separated channel
            # Process channels
            channels = unique([filter(s -> !all(isempty, s),
                                   unique(split.(samples[i].Channels, r",\(.+?\)"))[1])
                               [[replace((string(k.match)), "(" => "", ")" => "")
                                 for k in j]
                                for j in eachmatch.(r"\(.+?\)", unique(samples[i].Channels))]...])
            # Create the channel map
            channel_map = Dict(i => if i in keys(id_dict)
                                   id_dict[i]
                               else
                                   i
                               end for i in channels)
        else
            # Same as above but life is a bit easier
            channels = unique(split.(samples[i].Channels, ","))[1]
            channel_map = Dict(i => if i in keys(id_dict)
                                   id_dict[i]
                               else
                                   i
                               end for i in channels)
        end
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
    write_esm(esm_dict;name)

Write the esm_dict from read_data() to the path/file `name`.

Args:

- `esm_dict::Dict`: Dictionary describing the esm.
- `name::String`: Path to deposit the ESM to.
"""
function write_esm(esm_dict; name = "")
    if name == ""
        # No name? No problem
        name = "out"
    end
    open("$name.esm", "w") do file
        JSON.print(file, esm_dict, 4)
    end
    @info "ESM written to $name.esm."
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
    ptype = unique(samples[!, "Plate reader brand"])
    try
        length(loc) == 1
    catch
        error("Please give the location of only one folder containing all the CSVs for one plate. \nLocations given here are: $(Set(samples[!,"Data Location"])...)")
    end
    data = Dict()
    # Is there only one file being passed?
    if length(samples.Plate) == 1
        if isdir(loc)
            # Are the channels separated into different files named after the channels? - This is useful for generic data
            data = read_sep_chans_pr(channel_map, loc[1], channels)
        else
            length(ptype) == 1 ||
                error("Only one plat type can be used per plate. $(Set(samples[!,"Plate reader brand"])...) given. ")
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
    else
        # This allows for the renaming of the samples if defined per well
        if isdir(loc)
            data = read_sep_chans_pr(channel_map, loc, channels)
        else
            length(ptype) == 1 ||
                error("Only one plat type can be used per plate. $(Set(samples[!,"Plate reader brand"])) given. ")
            data = read_multipr_file("$(loc...)", ptype[1], channels, channel_map)
        end
        channels = keys(data)
        for j in eachrow(samples)
            if ismissing(j.Name)
                name = "plate_0$(j.Plate)_$(j.Well)"
            else
                name = j.Name
            end
            if !("plate_0$(j.Plate)_time" in keys(sample_dict))
                sample_dict["plate_0$(j.Plate)_time"] = Dict([
                    :values => Dict(), :type => "timeseries", :meta => Dict()])
                sample_dict["plate_0$(j.Plate)_time"][:values] = Dict(x => data[x][
                                                                          !, "Time"]
                for x in channels)
            end
            temp = Dict()
            temp[:type] = "timeseries"
            temp[:values] = Dict(x => data[x][!, j.Well] for x in channels)
            temp[:meta] = Dict()
            sample_dict[name] = temp
            broad_g = [broad_g; [name]]
        end
    end
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
    if ptype == "tecan"
        i = [j for j in split(read(filen, String), r"\n,+?\n") if (length(j) > 1500)]
        o_dict = Dict(channel_map[match(r"([A-Za-z0-9]+)", j).match] => CSV.read(
                          IOBuffer(j), DataFrame, transpose = true)
        for j in i if match(r"([A-Za-z0-9]+)", j).match in channels)
    elseif ptype == "agilent"
        i = [i
             for i in split(read(filen, String), r"(\r\n.+?\r\n\r\n)")
             if (length(i) > 8 && (length(i) > 1000 && string(i)[1:7] != "Results"))]
        o_dict = Dict(channel_map[match(r":([A-Za-z0-9,\[\]]+)", j).match[2:end]] => CSV.read(
                          IOBuffer("Time" * split(j, "\nTime")[2]), DataFrame)
        for j in i if match(r":([A-Za-z0-9,]+)", j).match[2:end] in channels)
    elseif ptype == "spectramax"
        f = IOBuffer(transcode(UInt8, ltoh.(reinterpret(UInt16, read(filen)))))
        i = [j
             for j in split(read(f, String), r"\#\#Blocks= |\n~End")
             if (length(split.(split(j, "\n")[2], "\t")) > 1)]
        o_dict = Dict(channel_map[split.(split(i[j], "\n")[2], "\t")[2]] => CSV.read(
                          IOBuffer(i[j]), DataFrame, header = 3, delim = "\t")
        for j in 1:length(i) if (split.(split(i[j], "\n")[2], "\t")[2] in channels))
    else
        i = [j for j in split(read(filen, String), r"\n,+?\n") if (length(j) > 1500)]
        o_dict = Dict(channel_map[match(r"([A-Za-z0-9]+)", j).match] => CSV.read(
                          IOBuffer(j), DataFrame, transpose = true)
        for j in i if match(r"([A-Za-z0-9]+)", j).match in channels)
    end
    for i in keys(o_dict)
        o_dict[i] = o_dict[i][!, Not(all.(ismissing, eachcol(o_dict[i])))]
    end
    return o_dict
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
    return Dict(channel_map[j[1:(end - 4)]] => CSV.read(loc * "/" * j, DataFrame)
    for j in readdir(loc) if j[1:(end - 4)] in channels)
end
