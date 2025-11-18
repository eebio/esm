# Manual Gating

There are a variety of types of gates that can be applied to flow cytometry data. Each method uses the `gate(data, Method())` function signature which will return the subset of events in `data` that satisfy that gate. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

```@docs
```

!!! todo "todo"
    logical operations on gates

## HighLow

!!! todo "todo"
    Describe how the high low gate works. lb and ub are optional, but atleast one should be specified

It can be called using `gate(data, HighLow(channel, lb, ub))`.

## Rectangle

!!! todo "todo"
    Describe how the gate works.

It can be called using `gate(data, Rectangle(channel1, channel2, lb1, ub1, lb2, ub2))`.

## Quadrant

!!! todo "todo"
    Describe how the gate works

It can be called using `gate(data, Quadrant(channel1, channel2, channel1value, channel2value, quadrant))`.

## Implementation Details

If you want to implement a new manual gate to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractManualGate`
* Define a new method dispatch `gate(data, ::NameOfNewMethodType)`
* Document that method in the manual gating documentation (this page)

!!! note
    Gates can only return a single group that "passes" the gate. For example, it is not possible to have a single `Quadrant` gate that separates the data into all four quadrants. This is so that it plays nicely with the ESM transformations. If you need to gate into all four quadrants, you should define four `Quadrant` gates, each with different values of the `quadrant` parameter.

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new manual gate and explaining how the gate should work.
