abstract type AbstractSmoothingMethod <: AbstractPlateReaderMethod end

"""
    smooth(data, time_col, method::AbstractSmoothingMethod)

Smooth that data using the specified method.

# Arguments
- `data`: A DataFrame of measurements.
- `time_col`: The column of time data corresponding to the measurements in `data`.
- `method`: The method to use for smoothing.
"""
function smoothing end

struct MovingAverage <: AbstractSmoothingMethod
    window_ahead::Int
    window_behind::Int
end

function MovingAverage(; window_size::Int)
    return MovingAverage(ceil(Int, window_size / 2) - 1, floor(Int, window_size / 2))
end

function MovingAverage(window_size::Int)
    return MovingAverage(window_size = window_size)
end

function smooth(data, _, method::MovingAverage)
    data = deepcopy(data)
    for name in names(data)
        col = data[!, name]
        smoothed_col = similar(col)
        for i in eachindex(col)
            start_idx = max(1, i - method.window_behind)
            end_idx = min(length(col), i + method.window_ahead)
            smoothed_col[i] = mean(col[start_idx:end_idx])
        end
        data[!, name] = smoothed_col
    end
    return data
end

@kwdef struct MovingTimeAverage <: AbstractSmoothingMethod
    window_ahead::Float64
    window_behind::Float64
end

function MovingTimeAverage(; window_size::Int)
    return MovingTimeAverage(window_size / 2, window_size / 2)
end

function MovingTimeAverage(window_size::Int)
    return MovingTimeAverage(window_size = window_size)
end

function smooth(data, time_col, method::MovingTimeAverage)
    data = deepcopy(data)
    for name in names(data)
        col = data[!, name]
        smoothed_col = similar(col)
        for i in eachindex(col)
            tmp = between_times(data[!, [name]], time_col; mint = time_col[i, 1]/60000 - method.window_behind, maxt = time_col[i, 1]/60000 + method.window_ahead)
            smoothed_col[i] = mean(skipmissing(tmp[!, 1]))
        end
        data[!, name] = smoothed_col
    end
    return data
end
