# Calibration

There are a few different methods for calibrating plate reader OD and fluorescence data. Each method uses the `calibrate(data, time_col, Method())` function signature. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
calibrate
```

## TimeseriesBlank

The `TimeseriesBlank` method averages across the blank wells, to get a single blank timeseries (assuming all the blanks were measured at the same timepoints). It then subtracts this from the data, timepoint by timepoint. So the first timepoint is calibrated by the average of all the blank wells at the first timepoint, the second is calibrated at the second timepoint and so on.

It can be called using `calibrate(data, time_col, TimeseriesBlank(blanks, blank_time_col))`.

## SmoothedTimeseriesBlank

The `SmoothedTimeseriesBlank` method averages across the blank wells, and then fits a straight line through the blank data (equivalent to fitting through all the blank wells without averaging). It then subtracts this line of best fit from each well in the data.

It can be called using `calibrate(data, time_col, SmoothedTimeseriesBlank(blanks, blank_time_col))`.

## MeanBlank

The `MeanBlank` method averages both over wells and over time. This gives a single value to calibrate the data against which is subtracted from the `data`.

It can be called using `calibrate(data, time_col, MeanBlank(blanks))`.

## MinBlank

The `MinBlank` method calculates a single calibration value as the minimum of all wells across all timepoints. It then subtracts this value form the `data`.

It can be called using `calibrate(data, time_col, MinBlank(blanks))`.

## MinData

The `MinData` method doesn't require blanks. It calculates a single calibration value for each well, as the minimum of each well. It then subtracts these values from each well, so that the data for each well contains one zero (where the minimum was previously), and no negative points.

It can be called using `calibrate(data, time_col, MinData())`.

## StartData

The `StartData` method doesn't require blanks. It calculates a single calibration value for each well, as the initial value of each well. It then subtracts these values from each well, so that the data begins at zero for all wells.

It can be called using `calibrate(data, time_col, StartData())`.

## Implementation Details

If you want to implement a new calibration method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractCalibrationMethod`
* Define a new method dispatch `calibrate(data, time_col, ::NameOfNewMethodType)`
* Document that method in the calibration documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new calibration method and explaining how the method should work.
