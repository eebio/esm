using NonlinearSolve
using RegularizationTools
using DataInterpolations
using GLM
using Statistics
using StatsBase
using ForwardDiff
using NaNMath
using Plots

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

function perform_recalibration(df, time_col, recalibrate, offset)
    if (recalibrate == :negative && any(df[:, 1] .<= 0)) || recalibrate == true
        recalibrant = minimum(df[:, 1]) - offset
        df = calibrate(df, time_col, MinData(); offset = offset)
    elseif recalibrate == false
        mask = df[!, 1] .> 0
        df = df[mask, [1]]
        time_col = time_col[mask, :]
        recalibrant = 0.0
    else
        recalibrant = 0.0
    end
    return df, time_col, recalibrant
end

"""
    growth_rate(df, time_col, method::AbstractGrowthRateMethod)

Calculates the growth rate of a given dataframe. Returns in min^-1 using base e.

Arguments:
- `df::DataFrame`: DataFrame containing the data.
- `time_col::DataFrame`: DataFrame containing the times.
- `method::AbstractGrowthRateMethod`: Method to use for calculating growth rate.

Keywords:
- `recalibrate`: Whether to recalibrate the data using `calibrate` before calculating growth rate. Default is :negative (only if negative values are present in the well). Available options are `:negative`, true, and false.
- `offset`: If data is recalibrated, this is the offset applied after calibration. Default is 0.001.
- `plot_directory`: If provided, this is the directory to save plots of the growth curves with the fitted growth rate. Default is nothing (no plots saved). If :temp, plots will be saved to a temporary directory.
"""
function growth_rate(df, time_col, method::AbstractGrowthRateMethod; recalibrate = :negative, offset = 0.001, plot_directory = nothing)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Saving growth curve plots to temporary directory: $plot_directory"
    end
    dict_2 = Dict()
    for i in names(df)
        od, times, _ = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory = plot_directory)["growth_rate"]
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
function max_od(df, time_col, method::AbstractGrowthRateMethod; recalibrate = :negative, offset = 0.001, plot_directory = nothing)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Saving growth curve plots to temporary directory: $plot_directory"
    end
    dict_2 = Dict()
    for i in names(df)
        od, times, recalibrant = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory = plot_directory)["maxOD"] + recalibrant
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
function time_to_max_growth(df, time_col, method::AbstractGrowthRateMethod; recalibrate = :negative, offset = 0.001, plot_directory = nothing)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Saving growth curve plots to temporary directory: $plot_directory"
    end
    dict_2 = Dict()
    for i in names(df)
        od, times, _ = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory = plot_directory)["time_to_max_growth"]
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
function od_at_max_growth(df, time_col, method::AbstractGrowthRateMethod; recalibrate = :negative, offset = 0.001, plot_directory = nothing)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Saving growth curve plots to temporary directory: $plot_directory"
    end
    dict_2 = Dict()
    for i in names(df)
        od, times, recalibrant = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        dict_2[i] = _growth_rate(od, times, method; plot_directory = plot_directory)["od_at_max_growth"] + recalibrant
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
function lag_time(df, time_col, method::AbstractGrowthRateMethod; recalibrate = :negative, offset = 0.001, plot_directory = nothing)
    if plot_directory == :temp
        plot_directory = mktempdir()
        @info "Saving growth curve plots to temporary directory: $plot_directory"
    end
    dict_2 = Dict()
    for i in names(df)
        od, times, recalibrant = perform_recalibration(df[:, [i]], time_col, recalibrate, offset)
        if nrow(od) == 0
            @warn "No positive values found for column $i after filtering. Returning NaN."
            dict_2[i] = NaN
            continue
        end
        tmp = _growth_rate(od, times, method; plot_directory = plot_directory)
        dict_2[i] = _lagtime(tmp["time_to_max_growth"], tmp["growth_rate"],
            tmp["od_at_max_growth"] + recalibrant, od[1, 1] + recalibrant)
    end
    return DataFrame(dict_2)
end

function _lagtime(time_at_max, growth_rate, od_at_max, od_at_start)
    lag_time = time_at_max - (1 / growth_rate) * NaNMath.log(od_at_max / od_at_start)
    return lag_time
end

@kwdef struct Endpoints <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function _growth_rate(df, time_col, method::Endpoints; plot_directory = nothing)
    start_od = at_time(df, time_col, method.start_time)
    end_od = at_time(df, time_col, method.end_time)
    if isempty(start_od) || isempty(end_od)
        @warn "When processing column $(names(df)[1]), no data points found before start_time=$(method.start_time). First timepoint is at $(first(time_col[:, 1]) / 60000) minutes. Returning NaN."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN
        )
    end
    start_od = start_od[1]
    end_od = end_od[1]
    start_time = at_time(time_col, time_col, method.start_time)[1] / 60000
    end_time = at_time(time_col, time_col, method.end_time)[1] / 60000
    growth_rate = (NaNMath.log(end_od) - NaNMath.log(start_od)) /
                  ((end_time) - (start_time))
    time_to_max_growth = (start_time + end_time) / 2
    od_at_max_growth = exp((NaNMath.log(start_od) + NaNMath.log(end_od)) / 2)
    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1])
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        vline!(p, [start_time, end_time], label = "Fitting Window", color = :blue, linestyle = :dot)
        savefig(p,joinpath(plot_directory, "growth_curve_$(typeof(method))_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct MovingWindow <: AbstractGrowthRateMethod
    window_size::Int = 10
    method::Symbol = :Endpoints
end

function _growth_rate(df, time_col, method::MovingWindow; plot_directory = nothing)
    window_size = method.window_size
    max_rate = -Inf
    time_to_max_growth = NaN
    od_at_max_growth = NaN
    best_window = nothing
    for j in 1:(nrow(df) - window_size)
        start_time = time_col[j, 1] / 60000
        end_time = time_col[j + window_size - 1, 1] / 60000
        if method.method == :Endpoints
            rate = _growth_rate(df, time_col, Endpoints(start_time, end_time))
        elseif method.method == :LinearOnLog
            rate = _growth_rate(df, time_col, LinearOnLog(start_time, end_time))
        else
            error("Unknown moving window method: $(method.method).")
        end
        if rate["growth_rate"] > max_rate && !isinf(rate["growth_rate"])
            best_window = [start_time, end_time]
            max_rate = rate["growth_rate"]
            time_to_max_growth = (start_time + end_time) / 2
            od_at_max_growth = exp((NaNMath.log(at_time(df, time_col, start_time)[1]) +
                                    NaNMath.log(at_time(df, time_col, end_time)[1])) / 2)
        end
    end
    summaries = Dict(
        "growth_rate" => max_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1])
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        if !isnothing(best_window)
            vline!(p, best_window, label = "Fitting Window", color = :blue, linestyle = :dot)
        end
        savefig(p,joinpath(plot_directory, "growth_curve_$(typeof(method))_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct LinearOnLog <: AbstractGrowthRateMethod
    start_time::Float64
    end_time::Float64
end

function _growth_rate(df, time_col, method::LinearOnLog; plot_directory = nothing)
    start_time = method.start_time
    end_time = method.end_time

    n = length(time_col[!, 1])
    if n < 2
        @warn "Not enough data points ($n) after log scaling and removing ≤ 0 values."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN
        )
    end

    # Get the indexes for the time range
    indexes = index_between_vals(
        time_col; minv = start_time * 60000, maxv = end_time * 60000)[names(time_col)[1]]

    if isnothing(indexes[1]) || isnothing(indexes[2])
        @warn "No data points found between start_time=$(start_time) and \
        end_time=$(end_time). This may be due to negative OD values being removed."
        return Dict(
            "growth_rate" => NaN,
            "time_to_max_growth" => NaN,
            "od_at_max_growth" => NaN,
            "maxOD" => NaN)
    end
    indexes = indexes[1]:indexes[2]

    lm_df = DataFrame(
        time = time_col[indexes, 1] ./ 60000, log_od = NaNMath.log.(df[indexes, 1] ./ first(df[:, 1])))
    lm_model = lm(@formula(log_od~time), lm_df)
    growth_rate = coef(lm_model)[2]
    time_to_max_growth = (start_time + end_time) / 2
    od_at_max_growth = geomean(between_times(df, time_col; mint = start_time, maxt = end_time)[:,1])

    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1])
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col ./ 60000, summaries)
        vline!(p, [start_time, end_time], label = "Fitting Window", color = :blue, linestyle = :dot)
        savefig(p,joinpath(plot_directory, "growth_curve_$(typeof(method))_$(names(df)[1]).png"))
    end
    return summaries
end

struct ParametricGrowthRate <: AbstractGrowthRateMethod
    func::Function
    initial_params::Vector{Float64}
end

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

function _growth_rate(df, time_col, method::ParametricGrowthRate; plot_directory = nothing)
    time_col = time_col ./ 60000
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
    t_refined = range(first(t), last(t), length = 100 * n)
    dOD = ForwardDiff.derivative.(ti -> method.func(ti, psol), t_refined)
    time_to_max_growth = t_refined[findmin(abs.(dOD .- growth_rate))[2]]
    od_at_max_growth = exp(method.func(time_to_max_growth, psol)) * first(y)
    maxOD = exp(psol[2]) * first(y)
    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maxOD
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col, summaries)
        plot!(p, t_refined, ti -> method.func(ti, psol), label = "Parametric Fit", color = :blue, linestyle = :dot)
        savefig(p,joinpath(plot_directory, "growth_curve_$(typeof(method))_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct FiniteDiff <: AbstractGrowthRateMethod
    type = :central
end

function _growth_rate(df, time_col, method::FiniteDiff; plot_directory = nothing)
    type = method.type
    time_col = time_col ./ 60000
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
                od_at_max_growth = exp((ly[k] + ly[k + 1]) / 2) * first(y)
            end
        end
    else
        error("Unknown finite difference type: $type")
    end

    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum(df[!, 1])
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col, summaries)
        savefig(p, joinpath(plot_directory, "growth_curve_$(typeof(method))_$(names(df)[1]).png"))
    end
    return summaries
end

@kwdef struct Regularization <: AbstractGrowthRateMethod
    order::Int = 4
end

function _growth_rate(df, time_col, method::Regularization; plot_directory = nothing)
    d = method.order
    time_col = time_col ./ 60000
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
            "maxOD" => NaN
        )
    end
    t_refined = range(first(t), last(t), length = 100 * n)
    A = RegularizationSmooth(ly, t, d; alg = :gcv_svd)
    deriv = [DataInterpolations.derivative(A, ti) for ti in t_refined]
    # maximum derivative (growth rate)
    growth_rate, i = findmax(deriv)
    time_to_max_growth = t_refined[i]
    od_at_max_growth = exp(A(time_to_max_growth)) * first(y)
    summaries = Dict(
        "growth_rate" => growth_rate,
        "time_to_max_growth" => time_to_max_growth,
        "od_at_max_growth" => od_at_max_growth,
        "maxOD" => maximum([exp(A(ti)) * first(y) for ti in t_refined])
    )
    if !isnothing(plot_directory)
        p = growth_plot(df, time_col, summaries)
        plot!(p, t_refined, A.(t_refined), label = "Regularized Fit", color = :blue, linestyle = :dot)
        savefig(p, joinpath(plot_directory, "growth_curve_$(typeof(method))_$(names(df)[1]).png"))
    end
    return summaries
end

function growth_plot(df, times, datapoints)
    p = plot(times[!, 1], log.(df[!, 1] ./ first(df[!, 1])), label = "Data", xlabel = "Time (min)", ylabel = "log(OD/OD₀)", title = "Growth curve: $(names(df)[1])", color = :black)
    lagtime = _lagtime(datapoints["time_to_max_growth"], datapoints["growth_rate"], datapoints["od_at_max_growth"], first(df[!, 1]))
    dydx = log(datapoints["od_at_max_growth"] ./ first(df[!, 1])) / (datapoints["time_to_max_growth"] - lagtime)
    x_low = lagtime
    x_high = log(datapoints["maxOD"] ./ first(df[!, 1]))/dydx + lagtime
    y_low = 0.0
    y_high = log(datapoints["maxOD"] ./ first(df[!, 1]))
    plot!(p, [x_low, x_high], [y_low, y_high], label = "Max Growth Rate", color = :mediumorchid)
    hline!(p, [log(datapoints["maxOD"] ./ first(df[!, 1]))], label = "Max OD", color = :red, linestyle = :dash)
    vline!(p, [lagtime], label = "Lag Time", color = :green, linestyle = :dash)
    scatter!(p, [datapoints["time_to_max_growth"]], [log(datapoints["od_at_max_growth"] ./ first(df[!, 1]))], label = "Max Growth Point", color = :red, marker = :x)
    plot!(p, legend = :best)
    return p
end
