using GLM
using Statistics
using CSV
using StringEncodings
using NonlinearSolve
import Base.read

abstract type AbstractPlateReader <: AbstractESMDataType end

abstract type AbstractPlateReaderMethod <: AbstractESMMethod end

abstract type AbstractGrowthRateMethod <: AbstractPlateReaderMethod end

abstract type AbstractCalibrationMethod <: AbstractPlateReaderMethod end

abstract type AbstractFluorescenceMethod <: AbstractPlateReaderMethod end

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
    length(ptype) == 1 ||
        error("Only one plate type can be used per plate. $(Set(samples[!,"Plate brand"])...) given. ")
    data = read_multipr_file("$(loc...)", ptype[1], channels, channel_map)
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
    if lowercase(ptype) == "spectramax"
        ptype = SpectraMax()
    elseif lowercase(ptype) == "biotek"
        ptype = BioTek()
    elseif lowercase(ptype) == "generic"
        ptype = GenericTabular()
    else
        error("Unknown plate reader type: $ptype.")
    end
    o_dict = read(filen, ptype; channels = channels)
    # Apply channel map
    o_dict = Dict(get(channel_map, k, k) => v for (k, v) in o_dict)
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
    return split(str, r"\n")
end

function runlength(a, i)
    if i == length(a)
        return 1
    elseif a[i] == 1
        return runlength(a, i + 1) + 1
    else
        return 0
    end
end

function read_standard(filen, offset)
    f = read_into_lines(filen)
    containsTime = [occursin(r"\d{1,2}:\d\d:\d\d", j) ? 1 : 0 for j in f]
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Find and push header onto table (first row before i that contains Time and the row above it)
        for j in (i - 1):-1:1
            if occursin("Time", f[j])
                push!(table, f[j - offset])
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
    return data
end

struct SpectraMax <: AbstractPlateReader end

"""
    read(filen::AbstractString, ::AbstractPlateReader; channels)

Read data from plate reader file `filen` of assuming the format of `AbstractPlateReader`.

Args:
- `filen::AbstractString`: File to read from.
- `::AbstractPlateReader`: Plate reader type.

Optional Args:
- `channels::Vector{String}`: Channels to be read in. Defaults to all channels.
"""
function Base.read(filen::AbstractString, ::SpectraMax; channels=nothing)
    data = read_standard(filen, 1)
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        tmp = split(data[i][1], "\t")
        channel = strip(tmp[6] == "Fluorescence" ? tmp[14] : tmp[13])
        if !isnothing(channels) && !(channel in channels)
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
        out[channel] = df
    end
    return out
end

struct BioTek <: AbstractPlateReader end

function Base.read(filen::AbstractString, ::BioTek; channels=nothing)
    data = read_standard(filen, 2)
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        channel = strip(split(data[i][1], ":")[end])
        if !isnothing(channels) && !(channel in channels)
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
        out[channel] = df
    end
    return out
end

struct GenericTabular <: AbstractPlateReader end

function Base.read(filen::AbstractString, ::GenericTabular; channels=nothing)
    out = Dict()
    for j in readdir(filen)
        channel = splitext(j)[1] # Remove file extension
        if !isnothing(channels) && !(channel in channels)
            @info "Skipping channel $channel as not in requested channels."
            continue
        end
        out[channel] = CSV.read(joinpath(filen, j), DataFrame)
    end
    return out
end

"""
    doubling_time(df, time_col)
    doubling_time(df, time_col, method::AbstractGrowthRateMethod; kwargs...)

Calculates the doubling time of a given DataFrame. Returns result in minutes.

Args:

- `df=<DataFrame>`: DataFrame containing the data.
- `time_col=<DatFrame>`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.

Optional Args:
- `kwargs...`: Additional keyword arguments to pass to the growth rate method.
"""
function doubling_time(args...; kwargs...)
    return log(2) ./ growth_rate(args...; kwargs...)
end

@kwdef struct Endpoints <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

"""
    growth_rate(df, timecol)
    growth_rate(df, time_col, method::AbstractGrowthRateMethod)

Calculates the growth rate of a given dataframe. Returns in min^-1 using base e.

Args:

- `df=<DataFrame>`: DataFrame containing the data.
- `time_col=<DataFrame>`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.
"""
function growth_rate(df, time_col, method::Endpoints)
    dict_2 = Dict()
    for i in names(df)
        start_od = at_time(df, time_col, method.start_time) # It is broken because at_time is always returning the last value - maybe weird unit stuff?
        end_od = at_time(df, time_col, method.end_time)
        start_time = at_time(df2time(time_col), time_col, method.start_time)[1] / 60
        end_time = at_time(df2time(time_col), time_col, method.end_time)[1] / 60
        dict_2[i] = (log(end_od[i]) - log(start_od[i])) /
                     (end_time - start_time)
    end
    return DataFrame(dict_2)
end

@kwdef struct MovingWindow <: AbstractGrowthRateMethod
    window_size::Int = 10
end

function growth_rate(df, time_col, method::MovingWindow)
    window_size = method.window_size
    dict = Dict()
    time_col = df2time(time_col)
    for i in names(df)
        max_rate = 0.0
        for j in 1:(nrow(df) - window_size)
            # TODO change this to allow any method to be used as a moving window
            rate = (log(df[j + window_size, i]) - log(df[j, i])) /
                   (time_col[j + window_size, 1]/60 - time_col[j, 1]/60)
            if rate > max_rate
                max_rate = rate
            end
        end
        dict[i] = max_rate
    end
    return DataFrame(dict)
end

@kwdef struct LinearOnLog <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function growth_rate(df, time_col, method::LinearOnLog)
    start_time = method.start_time
    end_time = method.end_time
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    # Get the indexes for the time range
    indexes = index_between_vals(
        time_col; minv = start_time, maxv = end_time)[names(time_col)[1]]
    if length(indexes) < 2
        @warn "Not enough data points between $start_time and $end_time to calculate growth rate."
    end
    for i in names(df)
        lm_df = DataFrame(time = time_col[indexes[1]:indexes[2], 1],
                         log_od = log.(df[indexes[1]:indexes[2], i]))
        lm_model = lm(@formula(log_od ~ time), lm_df)
        dict[i] = coef(lm_model)[2]
    end
    return DataFrame(dict)
end

@kwdef struct ExpOnLinear <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function growth_rate(df, time_col, method::ExpOnLinear)
    start_time = method.start_time
    end_time = method.end_time
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    # Get the indexes for the time range
    indexes = index_between_vals(
        time_col; minv = start_time, maxv = end_time)[names(time_col)[1]]
    if length(indexes) < 2
        @warn "Not enough data points between $start_time and $end_time to calculate growth rate."
    end
    for i in names(df)
        t = time_col[indexes[1]:indexes[2], 1]
        y = df[indexes[1]:indexes[2], i]

        # residual function for NonlinearLeastSquaresProblem
        # signature (res, u, p, t) is used by NonlinearSolve
        residuals! = function (res, u, _)
            for k in eachindex(t)
                res[k] = u[1] * exp(u[2] * t[k]) - y[k]
            end
            return nothing
        end

        # initial guess: A ~ max(y), b small
        u0 = [maximum(y), 1e-3]

        prob = NonlinearLeastSquaresProblem(NonlinearFunction(residuals!, resid_prototype = zeros(length(y))), u0)
        sol = solve(prob; verbose = false, maxiters = 200)
        psol = sol.u
        dict[i] = psol[2]
    end
    return DataFrame(dict)
end

struct Logistic <: AbstractGrowthRateMethod
end

function growth_rate(df, time_col, ::Logistic)
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    for i in names(df)
        t = time_col[!, 1]
        y = df[!, i]

        # residual function for NonlinearLeastSquaresProblem
        # signature (res, u, p, t) is used by NonlinearSolve
        residuals! = function (res, u, _)
            for k in eachindex(t)
                res[k] = u[1] / (1 + exp(-u[2] * (t[k] - u[3]))) - y[k]
            end
            return nothing
        end

        # initial guess: A ~ max(y), b small, c ~ end of time
        u0 = [maximum(y), 1e-3, t[end]]

        prob = NonlinearLeastSquaresProblem(NonlinearFunction(residuals!, resid_prototype = zeros(length(y))), u0)
        sol = solve(prob; verbose = false, maxiters = 200)
        psol = sol.u
        dict[i] = psol[2]
    end
    return DataFrame(dict)
end

@kwdef struct FiniteDiff <: AbstractGrowthRateMethod
    type = :central
end

function growth_rate(df, time_col, method::FiniteDiff)
    type = method.type
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    for i in names(df)
        t = time_col[!, 1]
        y = df[!, i]

        n = length(t)
        if n < 2
            @warn "Not enough time points to compute finite differences for $i."
            dict[i] = NaN
            continue
        end

        # compute log of y to match other methods (growth in log-space)
        if any(y .<= 0)
            @warn "Non-positive values in column $i; log will produce NaN/Inf."
        end
        ly = log.(y)

        deriv = zeros(length(ly))

        if type == :central
            # first and last use one-sided differences
            for k in 2:(n - 1)
                deriv[k] = (ly[k + 1] - ly[k - 1]) / (t[k + 1] - t[k - 1])
            end
        elseif type == :onesided
            for k in 1:(n - 1)
                deriv[k] = (ly[k + 1] - ly[k]) / (t[k + 1] - t[k])
            end
        else
            error("Unknown finite difference type: $type")
        end

        # maximum derivative (growth rate)
        dict[i] = maximum(deriv)
    end
    return DataFrame(dict)
end

struct TimeseriesBlank <: AbstractCalibrationMethod end

"""
    calibrate(data, method::AbstractCalibrationMethod)
    calibrate(data, blanks, method::AbstractCalibrationMethod)

Calibrate data, for example, to remove background OD signal.

Args:
- `data=<DataFrame>`: DataFrame containing the data to be calibrated.
- `blanks=<DataFrame>`: DataFrame containing the blank measurements.
- `method::AbstractCalibrationMethod`: Method to use for calibration.
"""
function calibrate(data, blanks, ::TimeseriesBlank)
    return data .- colmean(blanks)
end

struct MeanBlank <: AbstractCalibrationMethod end

function calibrate(data, blanks, ::MeanBlank)
    # Average blanks over time
    means = mean(colmean(blanks))
    return data .- means
end

struct MinBlank <: AbstractCalibrationMethod end

function calibrate(data, blanks, ::MinBlank)
    # Minimum blank over time
    mins = minimum(minimum(eachcol(blanks)))
    return data .- mins
end

struct MinData <: AbstractCalibrationMethod end

function calibrate(data, _, ::MinData)
    data = deepcopy(data)
    # Minimum data over time
    mins = [minimum(i) for i in eachcol(data)]
    for i in 1:ncol(data)
        data[!, i] .-= mins[i]
    end
    return data
end

function calibrate(data, ::MinData)
    calibrate(data, nothing, MinData())
end

struct StartZero <: AbstractCalibrationMethod end

function calibrate(data, _, ::StartZero)
    # Set starting value to zero
    data = deepcopy(data)
    starts = data[1, :]
    for i in 1:ncol(data)
        data[!, i] .-= starts[i]
    end
    return data
end

function calibrate(data, ::StartZero)
    calibrate(data, nothing, StartZero())
end
