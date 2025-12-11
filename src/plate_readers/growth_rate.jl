using NonlinearSolve
using RegularizationTools
using DataInterpolations
using GLM
using Statistics

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

function growth_rate(df, time_col, method::ParametricGrowthRate)
    dict = Dict()
    time_col = df2time(time_col) ./ 60
    for i in names(df)
        t = time_col[!, 1]
        y = df[!, i]

        t = t[y .> 0]
        y = y[y .> 0]
        ly = log.(y ./ first(y))
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
