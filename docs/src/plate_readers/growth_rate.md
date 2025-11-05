# Growth Rate

There are a variety of methods for calculating growth rates (or doubling times). Each method uses the `growth_rate(data, Method())` function signature (or `doubling_time(data, Method())`). These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
ESM.growth_rate
ESM.doubling_time
```

!!! todo "todo"
    Document which is the default method

## MovingWindow

!!! todo "todo"
    Describe how the moving window method works

It can be called using `growth_rate(data, MovingWindow())` or `doubling_time(data, MovingWindow())`.

## LinearOnLog

!!! todo "todo"
    Describe how the linear on log method works

It can be called using `growth_rate(data, LinearOnLog(start_time, end_time))` or `doubling_time(data, LinearOnLog(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

## ExpOnLinear

!!! todo "todo"
    Describe how the exp on linear method works

It can be called using `growth_rate(data, ExpOnLinear(start_time, end_time))` or `doubling_time(data, ExpOnLinear(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

## Endpoints

!!! todo "todo"
    Describe how the endpoints method works

It can be called using `growth_rate(data, Endpoints(start_time, end_time))` or `doubling_time(data, Endpoints(start_time, end_time))`. `start_time` and `end_time` are the start and end times of the exponential phase.

## Spline

!!! todo "todo"
    Describe how the spline method works

It can be called using `growth_rate(data, Spline())` or `doubling_time(data, Spline())`.

## Logistic

!!! todo "todo"
    Describe how the logistic method works

It can be called using `growth_rate(data, Logistic())` or `doubling_time(data, Logistic())`.

!!! todo "todo"
    add parametric models here too

## Implementation Details

If you want to implement a new growth rate method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractGrowthRateMethod`
* Define a new method dispatch `growth_rate(data, ::NameOfNewMethodType)`
* Document that method in the growth rate documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new growth rate method and explaining how the method should work.
