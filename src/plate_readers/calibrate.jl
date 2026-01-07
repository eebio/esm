using GLM
using Statistics
using DataInterpolations

abstract type AbstractCalibrationMethod <: AbstractPlateReaderMethod end

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
