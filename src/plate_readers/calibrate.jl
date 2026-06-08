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

Keywords:
- `offset::Number`: Value to add to the calibrated data after calibration (default: 0).
"""
function calibrate(data, time_col, method::AbstractCalibrationMethod; offset)
    data = calibrate(data, time_col, method)
    return data .+ offset
end

function calibrate(data, time_col, method::TimeseriesBlank)
    check_multiple_channels(method.blanks)
    blanks = deepcopy(method.blanks)
    if !isnothing(method.time_col)
        blank_time_col = method.time_col
    else
        blank_time_col = time_col
    end
    averaged_blanks = mean(eachcol(blanks)) # here
    # Interpolate blanks to data time points if necessary
    if !isequal(blank_time_col, time_col)
        li = LinearInterpolation(averaged_blanks,
            blank_time_col[!, 1];
            extrapolation = ExtrapolationType.Constant)
        averaged_blanks = li.(skipmissing(time_col[!, 1]))
    end
    return data .- averaged_blanks
end

@kwdef struct SmoothedTimeseriesBlank <: AbstractCalibrationMethod
    blanks::DataFrame
    time_col::Union{DataFrame, Nothing} = nothing
end

function calibrate(data, time_col, method::SmoothedTimeseriesBlank)
    check_multiple_channels(method.blanks)
    blanks = deepcopy(method.blanks)
    if !isnothing(method.time_col)
        blank_time_col = method.time_col
    else
        blank_time_col = time_col
    end
    averaged_blanks = mean(eachcol(blanks))
    df = DataFrame(od = averaged_blanks, Time = blank_time_col[!, 1]) # here
    model = lm(@formula(od~Time), df)
    smoothed_blanks = predict(model, DataFrame(Time = collect(skipmissing(time_col[!, 1]))))
    return data .- smoothed_blanks
end

@kwdef struct MeanBlank <: AbstractCalibrationMethod
    blanks::DataFrame
end

function calibrate(data, _, method::MeanBlank)
    check_multiple_channels(method.blanks)
    blanks = method.blanks
    # Average blanks over time
    means = mean(skipmissing(mean(eachcol(blanks))))
    return data .- means
end

@kwdef struct MinBlank <: AbstractCalibrationMethod
    blanks::DataFrame
end

function calibrate(data, _, method::MinBlank)
    check_multiple_channels(method.blanks)
    blanks = method.blanks
    # Minimum blank over time
    mins = minimum(skipmissing(minimum(skipmissing(eachcol(blanks)))))
    return data .- mins
end

struct MinData <: AbstractCalibrationMethod end

function calibrate(data, _, ::MinData)
    data = deepcopy(data)
    # Minimum data over time
    mins = [minimum(skipmissing(i)) for i in eachcol(data)]
    for i in 1:ncol(data)
        data[!, i] .-= mins[i]
    end
    return data
end

struct StartData <: AbstractCalibrationMethod end

function calibrate(data, _, ::StartData)
    # Set starting value to zero
    data = deepcopy(data)
    starts = [first(skipmissing(i)) for i in eachcol(data)]
    for i in 1:ncol(data)
        data[!, i] .-= starts[i]
    end
    return data
end

function check_multiple_channels(blanks)
    # First check if there are channels in the blanks DataFrame
    columnnames = names(blanks)
    if all([!contains(name, ".") for name in columnnames])
        return nothing
    end
    # Since there are channels, get them
    channels = unique([convert(String, split(name, ".")[end]) for name in columnnames if contains(name, ".")])
    if length(channels) > 1
        throw(ArgumentError("Multiple channels detected in blanks DataFrame. You may have forgotten to qualify the calibration data with a channel name. Detected channels: $(channels)."))
    end
end
