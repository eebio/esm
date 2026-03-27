# Growth Rate

There are a variety of methods for calculating growth rates (or doubling times). Each method uses the `growth_rate(data, time_col, Method())` function signature (or `doubling_time(data, time_col, Method())`). These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
ESM.growth_rate
ESM.doubling_time
```

## Other functions

Not only are methods available for calculating `growth_rate` and `doubling_time`, but there are also methods for calculating related summary statistics of time and OD at maximum growth, lagtime, and maximum OD. All these use the same function signature and their definitions depend on the specific growth rate method that is being used.

```@docs
max_od
time_to_max_growth
od_at_max_growth
lag_time
```

!!! note "Lagtime"
    Lagtime is always calculated using `growth_rate`, `time_to_max_growth`, and `od_at_max_growth` according to [Zwietering et al. 1990](https://doi.org/10.1128/aem.56.6.1875-1881.1990). This method defines the lagtime as the x intercept of the tangent to the growth curve at maximum growth on a plot of log(OD/OD_0) where OD_0 is the first OD value in the data set. It is calculated as: time_to_max_growth - (1 / growth_rate) * ln(od_at_max_growth / OD_0).
    For the parameteric and regularization methods, OD_0 is determined from the fitted curve.

## Endpoints

The `Endpoints` method is the same as fitting an exponential curve ``y=A\exp(bt)`` to two points (`start_time` and `end_time`) and returning the growth rate ``b``.

```math
b = \frac{\ln (od(t_\text{end})) - \ln (od(t_\text{start}))}{t_\text{end} - t_\text{start}}
```

It can be called using `growth_rate(data, time_col, Endpoints(start_time, end_time))` or `doubling_time(data, time_col, Endpoints(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

- `max_od` - return the maximum OD in the data
- `time_to_max_growth` - return the average of the first time before `start_time` and the first time before `end_time`
- `od_at_max_growth` - returns the geometric mean of the first OD before `start_time` and the first OD before `end_time`

## LinearOnLog

The `LinearOnLog` method log-transforms the data (removing any points ≤ 0), and then fits a straight line on all the data between `start_time` and `end_time`, returning the gradient of the line of best fit.

It can be called using `growth_rate(data, time_col, LinearOnLog(start_time, end_time))` or `doubling_time(data, time_col, LinearOnLog(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

- `max_od` - return the maximum OD in the data
- `time_to_max_growth` - return the average of the first time before `start_time` and the first time before `end_time`
- `od_at_max_growth` - returns the geometric mean of the first OD before `start_time` and the first OD before `end_time`

## MovingWindow

The `MovingWindow` method allows you to use any of the above methods (`Endpoints`, or `LinearOnLog`) without defining the start and end points of the exponential phase. Instead, you can provide a number of timepoints (a.k.a. `window_size`, defaults to 10) and it will calculate the growth rate on all consequetive runs of that length and return the maximum growth rate.

By default, the growth rates on each window are calculated using the `Endpoints` method. This can be changed by supplying a `method` keyword argument to `MovingWindow`. The available options are `:Endpoints` (default), and `:LinearOnLog`.

It can be called using `growth_rate(data, time_col, MovingWindow(window_size, method))` or `doubling_time(data, time_col, MovingWindow(window_size, method))`.

The other functions (`max_od`, `time_to_max_growth`, `od_at_max_growth`) are defined based on the choice of `method` and evaluated across the window which gives the maximum growth rate.

## FiniteDiff

The `FiniteDiff` method log-transforms the data (removing any points ≤ 0) and then calculates the local gradients. It does this by traveling along the timepoints one-by-one, either calculating the central or one-sided finite difference. It then returns the maximum gradient.

```math
\frac{\ln (od(t_{i})) - \ln (od(t_{i-1}))}{t_{i} - t_{i-1}} \quad \text{one-sided} \\
\frac{\ln (od(t_{i+1})) - \ln (od(t_{i-1}))}{t_{i+1} - t_{i-1}} \quad \text{central}
```

It can be called using `growth_rate(data, time_col, FiniteDiff())` (defaults to central) or any of `growth_rate(data, time_col, FiniteDiff(method=:onesided))`, or `growth_rate(data, time_col, FiniteDiff(method=:central))`.
You can also call `doubling_time` with either of the `FiniteDiff` methods.

- `max_od` - return the maximum OD in the data
- `time_to_max_growth` - return the time at the centre of the finite differencing interval when growth is maximised.
- `od_at_max_growth` - return the geometric mean of the OD at either end of the finite differencing interval when growth is maximised.

## Logistic

The `Logistic` method is a parameteric method that fits a logistic curve to the data and returns ``b``.

```math
\frac{L}{1 + \exp(-b (t - t_0))}
```

It can be called using `growth_rate(data, time_col, Logistic())` or `doubling_time(data, time_col, Logistic())`.

- `max_od` - return the upper limit of the logistic growth curve
- `time_to_max_growth` - return the fitted time at maximum growth
- `od_at_max_growth` - return the fitted OD at maximum growth

!!! todo "todo"
    add parametric models here too

## Regularization

!!! todo "tidi"
    maths of regularization

For the `Regularization` method, the data is log scaled (negative points removed) and smoothed using regularization, before being interpolated by a cubic spline. The derivative of the cubic spline is then calculated at all timepoints and the maximum derivative is returned.

It can be called using `growth_rate(data, time_col, Regularization())` or `doubling_time(data, time_col, Regularization())`.

- `max_od` - returns the maximum value of the regularization within the time interval
- `time_to_max_growth` - return the time where the derivative of the regularization is maximised
- `od_at_max_growth` - return the regularized OD at `time_to_max_growth`

## Implementation Details

If you want to implement a new growth rate method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractGrowthRateMethod`
* Define a new method dispatch `growth_rate(data, time_col, ::NameOfNewMethodType)`
* Document that method in the growth rate documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new growth rate method and explaining how the method should work.
