# Smoothing

There are a variety of methods for smoothing plate reader data. Each method uses the `smooth(data, time_col, Method())` function signature. These can be used in the transformations in the Excel template.

```@docs; canonical=false
ESM.smooth
```

## MovingAverage

This method performs a moving average smoothing.

It can be called using `smooth(data, time_col, MovingAverage(window_size))`. `window_size` defines the number of points to be included in the moving average calculation (including the centre point). If an even number is specified, an extra point behind the centre will be included. Near endpoints the number of points averaged over is reduced. You can also specify two arguments for `MovingAverage(window_ahead, window_behind)`, where `MovingAverage(1,1)` is equivalent to `MovingAverage(3)`.

## MovingTimeAverage

This method also performs moving average smoothing, but the `window_size` is specified in minutes rather than number of data points.

## Implementation Details

If you want to implement a new smoothing method to be included in ESM, you need to:

- Open a pull request with the following code changes
- Define a new struct for your method type in `src/plate_readers/smoothing.jl`
- The type of that struct is a subtype of `AbstractSmoothingMethod`
- Define a new method dispatch `smooth(data, time_col, ::NameOfNewMethodType)`
- Document that method in the smoothing documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new smoothing method and explaining how the method should work.
