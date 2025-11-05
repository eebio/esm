# Fluorescence

There are a variety of methods for calculating per cell fluorescence. Each method uses the `fluorescence(data, Method())` function signature. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
```

!!! todo "todo"
    Document which is the default method

## RatioAtMaxGrowth

!!! todo "todo"
    Describe how the ratio at max growth method works.

It can be called using `fluorescence(data, RatioAtMaxGrowth())`.

## Implementation Details

If you want to implement a new fluorescence method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractFluorescenceMethod`
* Define a new method dispatch `fluorescence(data, ::NameOfNewMethodType)`
* Document that method in the fluorescence documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new fluorescence method and explaining how the method should work.
