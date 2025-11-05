# Automatic Gating

There are a couple of methods for automatically gating flow cytometry data. Each method uses the `autogate(data, Method())` function signature which will return XXX. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
```

!!! todo "todo"
    Document which is the default method

## KDE

!!! todo "todo"
    Describe how the KDE gate works.

It can be called using `autogate(data, KDE())`.

## TDA

!!! todo "todo"
    Describe how the TDA gate works.

It can be called using `autogate(data, TDA())`.

## Implementation Details

If you want to implement a new automatic gating method to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractAutoGate`
* Define a new method dispatch `autogate(data, ::NameOfNewMethodType)`
* Document that method in the automatic gating documentation (this page)

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new automatic gating method and explaining how the gate should work.
