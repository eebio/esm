using GLM
using CSV
using StringEncodings

"""
    doubling_time(df, time_col;max_od)

Calculates the growth rate/doubling time of a given dataframe. returns in min^-1

equation = (t_end - t_start)/log_2(max_od/min_od)

Args:

- `df=<DataFrame>`: DataFrame containing the data.
- `time_col=<DatFrame>`: DataFrame containing the times.
- `max_od=<Float64>`: Maximum OD. Defaults to 0.4 - min_od is 1/4 of this value.
"""
function doubling_time(df::DataFrame, time_col::DataFrame; max_od::Float64 = 0.4)
    min_od = max_od / 4
    dict_2 = Dict()
    time_col = df2time(time_col)
    for i in names(df)
        indexes = index_between_vals(df; minv = min_od, maxv = max_od)[i]
        # Is the max greater than what we can deal with?
        if max_od > maximum(df[:, i])
            @warn "Skipping $i as the max_od 4 x min_od ($max_od) is greater than in this sample ($(maximum(df[:,i])))."
        else
            dict_2[i] = (time_col[indexes[2], 1] - time_col[indexes[1], 1]) /
                        log2(df[indexes[2], 1] / df[indexes[1], 1]) / 60
        end
    end
    return DataFrame(dict_2)
end

"""
    growth_rate(df; window_size=10)

Calculates the growth rate of a given dataframe. Returns in min^-1 using base e.

Args:

- `df=<DataFrame>`: DataFrame containing the data.
- `window_size=10`: Size of the window (in minutes) to use for calculating the growth rate. Defaults to 10.
"""
function growth_rate(df, time_col; window_size = 10)
    dict_2 = Dict()
    time_col = df2time(time_col)
    df = hcat(df, time_col)
    for i in names(df)
        if i in names(time_col)
            continue
        end
        growth_rate = []
        starttime = time_col[1, 1] / 60 # convert to minutes
        while true
            endtime = starttime + window_size
            sub_df = between_times(
                df, time_col; mint = starttime, maxt = endtime)
            starttime = endtime
            if starttime > time_col[end, 1] / 60 + window_size
                break
            end
            if nrow(sub_df) < 2
                continue
            end
            tvals = sub_df[!, end] ./ 60 # convert to minutes
            yvals = log.(sub_df[!, i])
            lmfit = lm(@formula(y~t), DataFrame(y = yvals, t = tvals))
            rate = coef(lmfit)[2]
            push!(growth_rate, rate)
        end
        if length(growth_rate) == 0
            error("No growth rate could be calculated for $i. The window size may be too small.")
        end
        dict_2[i] = maximum(growth_rate)
    end
    return DataFrame(dict_2)
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
            temp_name = names(df)[2]
            rename!(df, temp_name => "temperature")
            time_name = names(df)[1]
            rename!(df, time_name => "time")
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
            temp_name = names(df)[2]
            rename!(df, temp_name => "temperature")
            time_name = names(df)[1]
            rename!(df, time_name => "time")
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
