using NonlinearSolve
using RegularizationTools
using DataInterpolations
using GLM
using Statistics
using ForwardDiff
using NaNMath

abstract type AbstractGrowthRateMethod <: AbstractPlateReaderMethod end

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
function growth_rate(df, time_col, method::AbstractGrowthRateMethod)
    dict_2 = Dict()
    for i in names(df)
        # Strip non-positive values from df and time_col
        mask = df[!, i] .> 0
        filtered_df = df[mask, [i]]
        filtered_time_col = time_col[mask, :]
        dict_2[i] = _growth_rate(filtered_df, filtered_time_col, method)["growth_rate"]
    end
    return DataFrame(dict_2)
end

"""
    max_od(df, time_col, method::AbstractGrowthRateMethod)

Calculates the maximum OD of a given dataframe. This may depend on the growth rate method
used.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.
"""
function max_od(df, time_col, method::AbstractGrowthRateMethod)
    dict_2 = Dict()
    for i in names(df)
        mask = df[!, i] .> 0
        filtered_df = df[mask, [i]]
        filtered_time_col = time_col[mask, :]
        dict_2[i] = _growth_rate(filtered_df, filtered_time_col, method)["maxOD"]
    end
    return DataFrame(dict_2)
end

"""
    time_to_max_growth(df, time_col, method::AbstractGrowthRateMethod)

Calculates the time at which growth is maximised.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.
"""
function time_to_max_growth(df, time_col, method::AbstractGrowthRateMethod)
    dict_2 = Dict()
    for i in names(df)
        mask = df[!, i] .> 0
        filtered_df = df[mask, [i]]
        filtered_time_col = time_col[mask, :]
        dict_2[i] = _growth_rate(filtered_df, filtered_time_col, method)["time_to_max_growth"]
    end
    return DataFrame(dict_2)
end

"""
    od_at_max_growth(df, time_col, method::AbstractGrowthRateMethod)

The OD at which growth is maximised.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.
"""
function od_at_max_growth(df, time_col, method::AbstractGrowthRateMethod)
    dict_2 = Dict()
    for i in names(df)
        mask = df[!, i] .> 0
        filtered_df = df[mask, [i]]
        filtered_time_col = time_col[mask, :]
        dict_2[i] = _growth_rate(filtered_df, filtered_time_col, method)["od_at_max_growth"]
    end
    return DataFrame(dict_2)
end

"""
    lag_time(df, time_col, method::AbstractGrowthRateMethod)

Calculates the lag time of the growth curve. This is given as the t-axis intercept of the
tangent at the point of maximum growth (defined by the growth rate, time to max growth, and
od at max growth).

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`.
"""
function lag_time(df, time_col, method::AbstractGrowthRateMethod)
    dict_2 = Dict()
    for i in names(df)
        mask = df[!, i] .> 0
        filtered_df = df[mask, [i]]
        filtered_time_col = time_col[mask, :]
        dict_2[i] = _growth_rate(filtered_df, filtered_time_col, method)["lag_time"]
    end
    return DataFrame(dict_2)
end

function _growth_rate(df, time_col, method::Endpoints)
    start_od = at_time(df, time_col, method.start_time)[1]
    end_od = at_time(df, time_col, method.end_time)[1]
    start_time = at_time(df2time(time_col), time_col, method.start_time)[1] / 60
    end_time = at_time(df2time(time_col), time_col, method.end_time)[1] / 60
    growth_rate = (NaNMath.log(end_od) - NaNMath.log(start_od)) /
                  ((end_time) - (start_time))
    time_to_max_growth = (start_time + end_time) / 2
    od_at_max_growth = exp((NaNMath.log(start_od) + NaNMath.log(end_od)) / 2)
    lag_time = _lagtime(time_to_max_growth, growth_rate,
        od_at_max_growth, df[1, 1])
    return Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "lag_time" => lag_time,
        "maxOD" => maximum(df[!, 1])
    )
end

function _lagtime(time_at_max, growth_rate, od_at_max, od_at_start)
    lag_time = time_at_max - (1 / growth_rate) * NaNMath.log(od_at_max / od_at_start)
    return lag_time
end

@kwdef struct MovingWindow <: AbstractGrowthRateMethod
    window_size::Int = 10
    method::Symbol = :Endpoints
end

function _growth_rate(df, time_col, method::MovingWindow)
    window_size = method.window_size
    max_rate = -Inf
    time_to_max_growth = NaN
    od_at_max_growth = NaN
    for j in 1:(nrow(df) - window_size)
        start_time = df2time(time_col)[j, 1] / 60
        end_time = df2time(time_col)[j + window_size - 1, 1] / 60
        if method.method == :Endpoints
            rate = growth_rate(df, time_col, Endpoints(start_time, end_time))
        elseif method.method == :LinearOnLog
            rate = growth_rate(df, time_col, LinearOnLog(start_time, end_time))
        else
            error("Unknown moving window method: $(method.method).")
        end
        if rate[1, 1] > max_rate && !isinf(rate[1, 1])
            max_rate = rate[1, 1]
            time_to_max_growth = (start_time + end_time) / 2
            od_at_max_growth = exp((NaNMath.log(at_time(df, time_col, start_time)[1]) +
                                    NaNMath.log(at_time(df, time_col, end_time)[1])) / 2)
        end
    end
    lag_time = _lagtime(time_to_max_growth, max_rate,
        od_at_max_growth, df[1, 1])
    return Dict(
        "growth_rate" => max_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "lag_time" => lag_time,
        "maxOD" => maximum(df[!, 1])
    )
end

@kwdef struct LinearOnLog <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function _growth_rate(df, time_col, method::LinearOnLog)
    start_time = method.start_time
    end_time = method.end_time
    time_col = df2time(time_col)

    n = length(time_col[!, 1])
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "lag_time" => NaN,
            "maxOD" => NaN
        )
    end

    # Get the indexes for the time range
    indexes = index_between_vals(
        time_col; minv = start_time * 60, maxv = end_time * 60)[names(time_col)[1]]

    if isnothing(indexes[1]) || isnothing(indexes[2])
        @warn "No data points found between start_time=$(start_time) and \
        end_time=$(end_time). This may be due to negative OD values being removed."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "lag_time" => NaN,
            "maxOD" => NaN)
    end
    indexes = indexes[1]:indexes[2]

    lm_df = DataFrame(
        time = time_col[indexes, 1] ./ 60, log_od = NaNMath.log.(df[indexes, 1]))
    lm_model = lm(@formula(log_od~time), lm_df)
    growth_rate = coef(lm_model)[2]
    time_to_max_growth = (start_time + end_time) / 2
    od_at_max_growth = exp((NaNMath.log(at_time(df, time_col, start_time)[1]) +
                            NaNMath.log(at_time(df, time_col, end_time)[1])) / 2)
    lag_time = _lagtime(time_to_max_growth, growth_rate,
        od_at_max_growth, df[1, 1])
    return Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "lag_time" => lag_time,
        "maxOD" => maximum(df[!, 1])
    )
end

struct ParametricGrowthRate <: AbstractGrowthRateMethod
    func::Function
    initial_params::Vector{Float64}
end

# TODO these equations need fixing to ensure they make sense biologically
function Logistic()
    return ParametricGrowthRate(
        (t, p) -> p[2] ./ (1 .+ exp.(4 * p[1] / p[2] .* (p[3] .- t) .+ 2)),
        [1.0, 4.0, 5.0])
end

function Gompertz()
    return ParametricGrowthRate(
        (t, p) -> p[2] .* exp.(-exp.(p[1] .* exp(1) ./ p[2] .* (p[3] .- t) .+ 1)),
        [1.0, 4.0, 5.0])
end

function ModifiedGompertz()
    return ParametricGrowthRate(
        (t, p) -> p[2] .* exp.(-exp.((p[1] .* exp(1) ./ p[2]) .* (p[3] .- t) .+ 1)) .+
                  p[2] .* exp.(p[4] * (t .- p[5])),
        [1.0, 4.0, 5.0, 1.0, 4.0])
end

function Richards()
    return ParametricGrowthRate(
        (t, p) -> p[2] ./ ((1 .+
                    exp(p[4]) .* exp(1 + exp(p[4])) .*
                    exp.(p[1] / p[2] .* (1 + exp(p[4]))^(1 + 1 / exp(p[4])) .*
                         (p[3] .- t))) .^ (1 ./ exp(p[4]))),
        [1.0, 4.0, 5.0, 0.0]) # Shape parameter is log transformed to ensure it's positive
end

function _growth_rate(df, time_col, method::ParametricGrowthRate)
    time_col = df2time(time_col) ./ 60
    t = time_col[!, 1]
    y = df[!, 1]

    t = t[y .> 0]
    y = y[y .> 0]
    ly = log.(y ./ first(y))

    n = length(t)
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "lag_time" => NaN,
            "maxOD" => NaN
        )
    end

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
    growth_rate = psol[1]
    lag_time = psol[3]
    dOD = ForwardDiff.derivative.(ti -> method.func(ti, psol), t)
    time_to_max_growth = t[findmin(abs.(dOD .- growth_rate))[2]]
    od_at_max_growth = exp(method.func(time_to_max_growth, psol)) * first(y)
    maxOD = exp(psol[2]) * first(y)
    return Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "lag_time" => lag_time,
        "max_od" => maxOD
    )
end

@kwdef struct FiniteDiff <: AbstractGrowthRateMethod
    type = :central
end

function _growth_rate(df, time_col, method::FiniteDiff)
    type = method.type
    time_col = df2time(time_col) ./ 60
    t = time_col[!, 1]
    y = df[!, 1]
    t = t[y .> 0]
    y = y[y .> 0]
    ly = log.(y)

    n = length(t)
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "lag_time" => NaN,
            "maxOD" => NaN
        )
    end

    growth_rate = 0.0
    time_to_max_growth = NaN
    od_at_max_growth = NaN

    if type == :central
        # first and last use one-sided differences
        for k in 2:(n - 1)
            deriv = (ly[k + 1] - ly[k - 1]) / (t[k + 1] - t[k - 1])
            if deriv > growth_rate
                growth_rate = deriv
                time_to_max_growth = t[k]
                od_at_max_growth = y[k]
            end
        end
    elseif type == :onesided
        for k in 1:(n - 1)
            deriv = (ly[k + 1] - ly[k]) / (t[k + 1] - t[k])
            if deriv > growth_rate
                growth_rate = deriv
                time_to_max_growth = (t[k] + t[k + 1]) / 2
                od_at_max_growth = exp((ly[k] + ly[k + 1]) / 2)
            end
        end
    else
        error("Unknown finite difference type: $type")
    end

    lag_time = _lagtime(time_to_max_growth, growth_rate,
        od_at_max_growth, df[1, 1])
    return Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "lag_time" => lag_time,
        "maxOD" => maximum(df[!, 1])
    )
end

@kwdef struct Regularization <: AbstractGrowthRateMethod
    order::Int = 4
end

function _growth_rate(df, time_col, method::Regularization)
    d = method.order
    time_col = df2time(time_col) ./ 60
    t = time_col[!, 1]
    y = df[!, 1]

    t = t[y .> 0]
    y = y[y .> 0]
    ly = log.(y)

    n = length(t)
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "lag_time" => NaN,
            "maxOD" => NaN
        )
    end

    A = RegularizationSmooth(ly, t, d; alg = :gcv_svd)
    deriv = [DataInterpolations.derivative(A, ti) for ti in t] # TODO do we only want the derivative at the measurement times?
    # maximum derivative (growth rate)
    growth_rate, i = findmax(deriv)
    time_to_max_growth = t[i]
    od_at_max_growth = df[i, 1]
    lag_time = _lagtime(time_to_max_growth, growth_rate,
        od_at_max_growth, df[1, 1])
    return Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "lag_time" => lag_time,
        "maxOD" => maximum(df[!, 1])
    )
end
