using GLM
using Statistics
using CSV
using Printf
using XLSX
using StringEncodings
using NonlinearSolve
import Base.read
using RegularizationTools
using DataInterpolations

abstract type AbstractPlateReader <: AbstractESMDataType end

abstract type AbstractPlateReaderMethod <: AbstractESMMethod end

abstract type AbstractGrowthRateMethod <: AbstractPlateReaderMethod end

abstract type AbstractCalibrationMethod <: AbstractPlateReaderMethod end

abstract type AbstractFluorescenceMethod <: AbstractPlateReaderMethod end

"""
    read_pr(samples,sample_dict,channels,broad_g,channel_map)

Reads plate reader data.

Arguments:
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
    length(loc) == 1 ||
        error("Please give the location of only one folder containing all the CSVs for one \
        plate. \nLocations given here are: $(Set(samples[!,"Data Location"])...)")
    length(ptype) == 1 ||
        error("Only one plate type can be used per plate. \
        $(Set(samples[!,"Plate brand"])...) given.")
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
    read_multipr_file(file,ptype,channels,channel_map)

Function for reading files containing multiple reads from multple channels from a single CSV
    file.
Returns a Dictionary of DataFrames with keys being the channels.

Arguments:
- `file::String`: File to read from.
- `ptype::String`: The plate reader type being used.
- `channels::Vector`: Channels to be read in.
- `channel_map`: The new names for the channels.
"""
function read_multipr_file(file, ptype, channels, channel_map)
    # TODO: Add bmg labtech reading
    if lowercase(ptype) == "spectramax"
        ptype = SpectraMax()
    elseif lowercase(ptype) == "biotek"
        ptype = BioTek()
    elseif lowercase(ptype) == "tecan"
        ptype = Tecan()
    elseif lowercase(ptype) == "generic"
        ptype = GenericTabular()
    else
        error("Unknown plate reader type: $ptype.")
    end
    o_dict = read(file, ptype; channels = channels)
    # Apply channel map
    o_dict = Dict(get(channel_map, k, k) => v for (k, v) in o_dict)
    for i in keys(o_dict)
        o_dict[i] = o_dict[i][!, Not(all.(ismissing, eachcol(o_dict[i])))]
    end
    return o_dict
end

function read_into_lines(file)
    encodings = ["UTF-16", "UTF-8", "windows-1252", "ISO-8859-1", "ASCII"]
    true_encoding = ""
    bytes = read(file)
    for enc in encodings
        try
            str = decode(bytes, enc)
            if occursin("Time", str)
                true_encoding = enc
                break
            end
        catch
        end
    end
    true_encoding == "" &&
        error("Could not determine encoding for file $file.")
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

function read_standard(file, offset)
    f = read_into_lines(file)
    containsTime = [occursin(r"\d{1,2}:\d\d:\d\d", j) ? 1 : 0 for j in f]
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Push header onto table (first row before i that contains Time and row above)
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

function correct_data_length(data, delim)
    for d in data
        # Find the most common number of columns
        col_lengths = [length(split(row, delim)) for row in d]
        max_length = maximum(col_lengths)
        # Fill in missing columns with empty cells
        for i in eachindex(d)
            current_length = length(split(d[i], delim))
            if current_length < max_length
                num_missing = max_length - current_length
                d[i] *= repeat(delim, num_missing)
            end
        end
    end
    return data
end

struct SpectraMax <: AbstractPlateReader end

"""
    read(file::AbstractString, ::AbstractPlateReader; channels)

Read data from plate reader file `file` of assuming the format of `AbstractPlateReader`.

Arguments:
- `file::AbstractString`: File to read from.
- `::AbstractPlateReader`: Plate reader type.
- `channels`: Vector of channels (as strings) to be read in. Defaults to nothing (all
    channels).
"""
function Base.read(file::AbstractString, ::SpectraMax; channels = nothing)
    data = read_standard(file, 1)
    data = correct_data_length(data, "\t")
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

function Base.read(filen::AbstractString, ::BioTek; channels = nothing)
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

struct Tecan <: AbstractPlateReader end

function Base.read(file::AbstractString, ::Tecan; channels = nothing)
    workbook = XLSX.readxlsx(file)
    sh = workbook["Sheet2"]
    isdata = .! ismissing.(sh[:, 1])
    rl = [runlength(isdata, i) for i in eachindex(isdata)]
    datalocations = findall(isequal("Cycle Nr."), vec(sh[:, 1])) .- 1
    data = []
    for i in datalocations
        # Find and push the data onto table
        tmp = sh[i:(i + rl[i] - 1), :]
        push!(data, permutedims(tmp))
    end
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        channel = data[i][1, 1]
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        df = DataFrame(data[i][2:end, 3:end], :auto)
        rename!(df, convert(Vector{String}, data[i][1, 3:end]))
        temp_name = names(df)[2]
        rename!(df, temp_name => "temperature")
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        # Change time format
        function seconds_to_hms(x)
            h = x ÷ 3600
            m = (x % 3600) ÷ 60
            s = round(x % 60)
            return @sprintf("%02d:%02d:%02d", h, m, s)
        end
        df[!, "time"] = seconds_to_hms.(convert(Vector{Int}, round.(df[!, "time"])))
        # Remove empty columns
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Do I need to drop temperature?)
        out[channel] = df
    end
    return out
end

struct GenericTabular <: AbstractPlateReader end

function Base.read(file::AbstractString, ::GenericTabular; channels = nothing)
    out = Dict()
    for j in readdir(file)
        channel = splitext(j)[1] # Remove file extension
        if !isnothing(channels) && !(channel in channels)
            continue
        end
        out[channel] = CSV.read(joinpath(file, j), DataFrame)
    end
    return out
end

"""
    doubling_time(df, time_col, method::AbstractGrowthRateMethod; kwargs...)

Calculates the doubling time of a given DataFrame. Returns result in minutes.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.
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
    growth_rate(df, time_col, method::AbstractGrowthRateMethod)

Calculates the growth rate of a given dataframe. Returns in min^-1 using base e.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.
"""
function growth_rate(df, time_col, method::Endpoints)
    dict_2 = Dict()
    for i in names(df)
        start_od = at_time(df, time_col, method.start_time)
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
    method::Symbol = :Endpoints
end

function growth_rate(df, time_col, method::MovingWindow)
    window_size = method.window_size
    dict = Dict()
    for i in names(df)
        max_rate = -Inf
        for j in 1:(nrow(df) - window_size)
            start_time = df2time(time_col)[j, 1] / 60
            end_time = df2time(time_col)[j + window_size - 1, 1] / 60
            if method.method == :Endpoints
                rate = growth_rate(df, time_col, Endpoints(start_time, end_time))
            elseif method.method == :LinearOnLog
                rate = growth_rate(df, time_col, LinearOnLog(start_time, end_time))
            elseif method.method == :ExpOnLinear
                rate = growth_rate(df, time_col, ExpOnLinear(start_time, end_time))
            else
                error("Unknown moving window method: $(method.method).")
            end
            if rate[1, i] > max_rate
                max_rate = rate[1, i]
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
    if indexes[2] - indexes[1] < 1
        @warn "Not enough data points between $start_time and $end_time to calculate \
            growth rate."
    end
    indexes = indexes[1]:indexes[2]
    for i in names(df)
        lm_df = DataFrame(time = time_col[indexes, 1], log_od = log.(df[indexes, i]))
        lm_model = lm(@formula(log_od~time), lm_df)
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
    if indexes[2] - indexes[1] < 1
        @warn "Not enough data points between $start_time and $end_time to calculate \
            growth rate."
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
        nonlinfun = NonlinearFunction(residuals!, resid_prototype = zeros(length(y)))
        prob = NonlinearLeastSquaresProblem(nonlinfun, u0)
        sol = NonlinearSolve.solve(prob; verbose = false, maxiters = 200)
        psol = sol.u
        dict[i] = psol[2]
    end
    return DataFrame(dict)
end

struct ParametricGrowthRate <: AbstractGrowthRateMethod
    func::Function
    initial_params::Vector{Float64}
end

# TODO these equations need fixing to ensure they make sense biologically
function Logistic()
    return ParametricGrowthRate(
        (t, p) -> p[2] ./ (1 .+ exp.(4*p[1]/p[2] .* (p[3] .- t) .+ 2)),
        [1.0, 4.0, 5.0])
end

function Gompertz()
    return ParametricGrowthRate(
        (t, p) -> p[2] .* exp.(-exp.(p[1].*exp(1)./p[2] .* (p[3] .- t) .+ 1)),
        [1.0, 4.0, 5.0])
end

function ModifiedGompertz()
    return ParametricGrowthRate(
        (t, p) -> p[2] .* exp.(-exp.((p[1] .* exp(1) ./ p[2]) .* (p[3] .- t) .+ 1)) .+ p[2] .* exp.(p[4]*(t .- p[5])),
        [1.0, 4.0, 5.0, 1.0, 4.0])
end

function Richards()
    return ParametricGrowthRate(
        (t, p) -> p[2] ./ ((1 .+ exp(p[4]) .* exp(1+exp(p[4])) .* exp.(p[1]/p[2] .* (1+exp(p[4]))^(1+1/exp(p[4])) .* (p[3] .- t))) .^ (1 ./ exp(p[4]))),
        [1.0, 4.0, 5.0, 0.0]) # Shape parameter is log transformed to ensure it's positive
end

function growth_rate(df, time_col, method::ParametricGrowthRate)
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    for i in names(df)
        t = time_col[!, 1]
        y = df[!, i]

        t = t[y .> 0]
        y = y[y .> 0]
        ly = log.(y./first(y))
        # residual function for NonlinearLeastSquaresProblem
        # signature (res, u, p, t) is used by NonlinearSolve
        residuals! = function (res, u, _)
            for k in eachindex(t)
                res[k] = method.func(t[k], u) .- ly[k]
            end
            return nothing
        end

        # initial guess: A ~ max(y), b small, c ~ end of time
        u0 = method.initial_params
        nonlinfun = NonlinearFunction(residuals!, resid_prototype = zeros(length(y)))
        prob = NonlinearLeastSquaresProblem(nonlinfun, u0)
        sol = NonlinearSolve.solve(prob; verbose = false, maxiters = 200)
        psol = sol.u
        dict[i] = psol[1]
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

        t = t[y .> 0]
        y = y[y .> 0]
        ly = log.(y)

        n = length(t)
        if n < 2
            @warn "Not enough time points to compute finite differences for $i."
            dict[i] = NaN
            continue
        end

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

@kwdef struct Regularization <: AbstractGrowthRateMethod
    order::Int = 4
end

function growth_rate(df, time_col, method::Regularization)
    d = method.order
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    for i in names(df)
        t = time_col[!, 1]
        y = df[!, i]

        t = t[y .> 0]
        y = y[y .> 0]
        ly = log.(y)

        n = length(t)
        if n < 2
            @warn "Not enough time points to compute finite differences for $i."
            dict[i] = NaN
            continue
        end

        A = RegularizationSmooth(ly, t, d; alg = :gcv_svd)
        deriv = [DataInterpolations.derivative(A, ti) for ti in t]
        # maximum derivative (growth rate)
        dict[i] = maximum(deriv)
    end
    return DataFrame(dict)
end

@kwdef struct TimeseriesBlank <: AbstractCalibrationMethod
    blanks::DataFrame
    time_col::Union{DataFrame, Nothing} = nothing
end

"""
    calibrate(data, time_col, method::AbstractCalibrationMethod)

Calibrate data, for example, to remove background OD signal.

Arguments:
- `data::DataFrame`: DataFrame containing the data to be calibrated.
- `time_col::Union{DataFrame, Nothing}`: Time column associated with the data.
- `method::AbstractCalibrationMethod`: Method to use for calibration.
"""
function calibrate(data, time_col, method::TimeseriesBlank)
    blanks = deepcopy(method.blanks)
    if !isnothing(method.time_col)
        blank_time_col = method.time_col
    else
        blank_time_col = time_col
    end
    averaged_blanks = colmean(blanks)
    # Interpolate blanks to data time points if necessary
    if !isequal(blank_time_col, time_col)
        li = LinearInterpolation(averaged_blanks,
            ESM.df2time(blank_time_col)[!, 1];
            extrapolation = ExtrapolationType.Constant)
        averaged_blanks = li.(ESM.df2time(time_col)[!, 1])
    end
    return data .- averaged_blanks
end

@kwdef struct SmoothedTimeseriesBlank <: AbstractCalibrationMethod
    blanks::DataFrame
    time_col::Union{DataFrame, Nothing} = nothing
end

function calibrate(data, time_col, method::SmoothedTimeseriesBlank)
    blanks = deepcopy(method.blanks)
    if !isnothing(method.time_col)
        blank_time_col = method.time_col
    else
        blank_time_col = time_col
    end
    averaged_blanks = colmean(blanks)
    df = DataFrame(od = averaged_blanks, Time = ESM.df2time(blank_time_col)[!, 1])
    model = lm(@formula(od~Time), df)
    smoothed_blanks = predict(model, ESM.df2time(time_col))
    return data .- smoothed_blanks
end

@kwdef struct MeanBlank <: AbstractCalibrationMethod
    blanks::DataFrame
end

function calibrate(data, _, method::MeanBlank)
    blanks = method.blanks
    # Average blanks over time
    means = mean(colmean(blanks))
    return data .- means
end

@kwdef struct MinBlank <: AbstractCalibrationMethod
    blanks::DataFrame
end

function calibrate(data, _, method::MinBlank)
    blanks = method.blanks
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
