# Transforms

Flow cytometry data typically varies across multiple orders of magnitude and includes both positive and negative values. As such, you may want to apply any of a long list of different transformations. We have a selection of them implementated in ESM. They can be accessed through the `transform(data, Transform())` and `untransform(data, Transform())` functions.

```@docs; canonical=false
transform
untransform
```

## Methods

The different methods that can be used with the `transform` and `untransform` functions are outlined below.

```@docs; canonical=false
Log
Log10
Log2
Log1p
Arcsinh
Linear
Bound
Hyperlog
Logicle
```

## Implementation Details

If you want to implement a new transform method to be included in ESM, you need to:

!!! todo
    This isn't right for how the transform method works, theres only one transform type

* Open a pull request with the following code changes
* Define a new function which returns a `Transform` object in `src/flow/transform.jl`
* Document that method in the transformation documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new transformation and explaining how the transform should work.
