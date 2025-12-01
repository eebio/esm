# Growth Rate

There are a variety of methods for calculating growth rates (or doubling times). Each method uses the `growth_rate(data, time_col, Method())` function signature (or `doubling_time(data, time_col, Method())`). These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
ESM.growth_rate
ESM.doubling_time
```

## Endpoints

The `Endpoints` method is the same as fitting an exponential curve ``y=A\exp(bt)`` to two points (`start_time` and `end_time`) and returning the growth rate ``b``.

```math
b = \frac{\ln (od(t_\text{end})) - \ln (od(t_\text{start}))}{t_\text{end} - t_\text{start}}
```

It can be called using `growth_rate(data, time_col, Endpoints(start_time, end_time))` or `doubling_time(data, time_col, Endpoints(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

## LinearOnLog

The `LinearOnLog` method log-transforms the data (removing any points ≤ 0), and then fits a straight line on all the data between `start_time` and `end_time`, returning the gradient of the line of best fit.

It can be called using `growth_rate(data, time_col, LinearOnLog(start_time, end_time))` or `doubling_time(data, time_col, LinearOnLog(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

## ExpOnLinear

The `ExpOnLinear` method is similar to the `LinearOnLog` method. It fits the line ``y=A\exp(bt)`` through all the data between `start_time` and `end_time`. This means negative points aren't removed, and the residuals (during the curve fitting) are not log-transformed.

It can be called using `growth_rate(data, time_col, ExpOnLinear(start_time, end_time))` or `doubling_time(data, time_col, ExpOnLinear(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

## MovingWindow

The `MovingWindow` method allows you to use any of the above methods (`Endpoints`, `LinearOnLog`, or `ExpOnLinear`) without defining the start and end points of the exponential phase. Instead, you can provide a number of timepoints (a.k.a. `window_size`, defaults to 10) and it will calculate the growth rate on all consequetive runs of that length and return the maximum growth rate.

By default, the growth rates on each window are calculated using the `Endpoints` method. This can be changed by supplying a `method` keyword argument to `MovingWindow`. The available options are `:Endpoints` (default), `:LinearOnLog`, and `:ExpOnLinear`.

It can be called using `growth_rate(data, time_col, MovingWindow(window_size, method))` or `doubling_time(data, time_col, MovingWindow(window_size, method))`.

## FiniteDiff

The `FiniteDiff` method log-transforms the data (removing any points ≤ 0) and then calculates the local gradients. It does this by traveling along the timepoints one-by-one, either calculating the central or one-sided finite difference. It then returns the maximum gradient.

```math
\frac{\ln (od(t_{i})) - \ln (od(t_{i-1}))}{t_{i} - t_{i-1}} \quad \text{one-sided} \\
\frac{\ln (od(t_{i+1})) - \ln (od(t_{i-1}))}{t_{i+1} - t_{i-1}} \quad \text{central}
```

It can be called using `growth_rate(data, time_col, FiniteDiff())` (defaults to central) or any of `growth_rate(data, time_col, FiniteDiff(method=:onesided))`, or `growth_rate(data, time_col, FiniteDiff(method=:central))`.
You can also call `doubling_time` with either of the `FiniteDiff` methods.

## Logistic

The `Logistic` method is a parameteric method that fits a logistic curve to the data and returns ``b``.

```math
\frac{L}{1 + \exp(-b (t - t_0))}
```

It can be called using `growth_rate(data, time_col, Logistic())` or `doubling_time(data, time_col, Logistic())`.

!!! todo "todo"
    add parametric models here too

## Regularization

For the `Regularization` method, the data is log scaled (negative points removed) and smoothed using regularization, before being interpolated by a cubic spline. The derivative of the cubic spline is then calculated at all timepoints and the maximum derivative is returned.

It can be called using `growth_rate(data, time_col, Regularization())` or `doubling_time(data, time_col, Regularization())`.

## Implementation Details

If you want to implement a new growth rate method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractGrowthRateMethod`
* Define a new method dispatch `growth_rate(data, time_col, ::NameOfNewMethodType)`
* Document that method in the growth rate documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new growth rate method and explaining how the method should work.
