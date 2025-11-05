# Calibration

There are a few different methods for calibrating plate reader OD and fluorescence data. Each method uses the `calibrate(data, Method())` function signature. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
```

!!! todo "todo"
    Document which is the default method

## TimeseriesBlank

!!! todo "todo"
    Describe how the subtract timeseriesblank method works. (interpolate if times are different?)

It can be called using `calibrate(data, TimeseriesBlank())`.

## MeanBlank

!!! todo "todo"
    Describe how the mean blank subtraction method works. Uses the mean value of blank measurements across all timepoints.

It can be called using `calibrate(data, MeanBlank())`.

## MinBlank

!!! todo "todo"
    Describe how the minimum blank subtraction method works. Uses the minimum value from blank measurements.

It can be called using `calibrate(data, MinBlank())`.

## MinData

!!! todo "todo"
    Describe how the minimum data subtraction method works. Uses the minimum value from the actual data as background.

It can be called using `calibrate(data, MinData())`.

## StartData

!!! todo "todo"
    Describe how the start data subtraction method works. Uses the initial timepoint value as background for each sample.

It can be called using `calibrate(data, StartData())`.

## Implementation Details

If you want to implement a new calibration method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractCalibrationMethod`
* Define a new method dispatch `calibrate(data, ::NameOfNewMethodType)`
* Document that method in the calibration documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new calibration method and explaining how the method should work.
