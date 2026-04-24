# Fluorescence

There are a variety of methods for calculating per cell fluorescence. Each method uses the `fluorescence(data_fl, time_fl, data_od, time_od, Method())` function signature. These can be used in the transformations in the Excel template.

```@docs; canonical=false
ESM.fluorescence
```

## RatioAtTime

This method determines the fluorescence per cell as the ratio of fluorescence to OD at a user specified time.

It can be called using `fluorescence(data_fl, time_fl, data_od, time_od, RatioAtTime(time))`, where the fluorescence and growth rate are calculated at `time` (using a constant interpolation).

## RatioAtMaxGrowth

This method determines the fluorescence per cell as the ratio of fluorescence to OD at the time of maximum growth (as determined by a growth rate method).

It can be called using `fluorescence(data_fl, time_fl, data_od, time_od, RatioAtMaxGrowth(growth_rate_method))`. The available growth rate methods can be found [here](@ref "Growth Rate"). For example, `RatioAtMaxGrowth(FiniteDiff())`.

## Implementation Details

If you want to implement a new fluorescence method to be included in ESM, you need to:

- Open a pull request with the following code changes
- Define a new struct for your method type in `src/methods.jl`
- The type of that struct is a subtype of `AbstractFluorescenceMethod`
- Define a new method dispatch `fluorescence(data_fl, time_fl, data_od, time_od, ::NameOfNewMethodType)`
- Document that method in the fluorescence documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new fluorescence method and explaining how the method should work.
