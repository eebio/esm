# Automatic Gating

There are a couple of methods for automatically gating flow cytometry data. Each method uses the `gate(data, Method())` function signature which will return all the data that passes the automatic gating algorithm. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs; canonical=false
gate
```

## KDE

The `KDE` method (Kernal Density Estimation) is an automatic gating method based on [FlowCal](https://github.com/taborlab/FlowCal). It generates an 2-dimensional histogram in the provided channels. It then smoothes out the densities of this histogram using `KernalDensity.jl` to remove isolated bins of high density (noise). It then returns some fraction of the data (`gate_frac` which defaults to 0.65) which is highest in density.

!!! todo "Animation"
    This is an awkward method to explain, best to create an animation for it.

It can be called using `gate(data, KDE(channels=["FSC-A", "SSC-A", ...], gate_frac=0.65, nbins=1024))` where `gate_frac` and `nbins` are optional.

## Implementation Details

If you want to implement a new automatic gating method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractAutoGate`
* Define a new method dispatch `gate(data, ::NameOfNewMethodType)`
* Document that method in the automatic gating documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new automatic gating method and explaining how the gate should work.
