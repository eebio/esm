# Manual Gating

There are a variety of types of gates that can be applied to flow cytometry data. Each method uses the `gate(data, Method())` function signature which will return the subset of events in `data` that satisfy that gate. These can be used either in the Julia ESM package diectly, or in the transformations in the Excel template.

!!! tip "Flow cytometry samples and groups"
    When using ESM transformations, samples and groups are automatically converted to relative fluoresence intensity. This allows you to use `gate` on any flow sample or group of flow samples.

```@docs; canonical=false
gate
```

## HighLowGate

The `HighLowGate` removes any events that are below `lb` in `channel` or above `ub` in channel. If one of the bounds is not specified, it will not be used to remove any data.

It can be called using `gate(data, HighLowGate(channel, lb, ub))`.

!!! note "Upper and Lower Bounds"
    Lower bounds are always inclusive (`lb`≤`data[channel]`) while upper bounds are always exclusive (`data[channel]`<`ub`).

## RectangleGate

The `RectangleGate` is equivalent to applying two `HighLowGate`s. It returns all data where:

```math
lb1 ≤ data[channel1] < ub1 \\
\text{and} \\
lb2 ≤ data[channel2] < ub2 \\
```

As with the `HighLowGate`, any of the upper and lower bounds can be left out to avoid gating on that bound.

It can be called using `gate(data, RectangleGate(channel1, channel2, lb1, ub1, lb2, ub2))`.

## QuadrantGate

The `QuadrantGate` is defined by a single point, a pair of values and channels. The values split all events into 4 quadrants, (high channel 1 and high channel 2, high channel 1 and low channel 2, low channel 1 and low channel 2, low channel 1 and high channel 2). You then need to specify a quadrant you want to return, numbered 1 through 4 in that order.

!!! tip "Remembering the quadrant order"
    If you were to plot the data with `channel1` on the x-axis and `channel2` on the y-axis, then quadrant 1 is in the top right corner, and the remaining quadrants are given by travelling clockwise.

It can be called using `gate(data, QuadrantGate(channel1, channel2, channel1value, channel2value, quadrant))`.

## PolygonGate

The `PolygonGate` can be used to create arbitrary polygons, gating to remove any data that doesn't fit inside the polygon. A `PolygonGate` can be created from a series of x-y coordinates describing the vertices of the polygon.

It can be called using `gate(data, PolygonGate(channel1, channel2, points))`.

## EllipseGate

The `EllipseGate` can be used to remove data that falls outside of a predefined ellipse. An `EllipseGate` can be created from 5 points that fall on the ellipse, or 3-5 points that fall on the ellipse and the ellipse's center.

It can be called using `gate(data, EllipseGate(channel1, channel2, points))` or `gate(data, EllipseGate(channel1, channel2, center, points))`.

## Logical Operations on Gates

You can also perform logical operations on gates. The logical operations are `and`, `or`, and `not`. They can be used either through operators (`HighLowGate(channel="FL1_A", lb=500.0, ub=2000.0) & QuadrantGate(channel1="SSC_A", ...)`) or through the `and` function (`and(HighLowGate(channel="FL1_A", lb=500.0, ub=2000.0), QuadrantGate(channel1="SSC_A", ...))`). This will return an `AndGate` (`|` and `or` returns an `OrGate`, and `!` and `not` return a `NotGate`) which can then be gated on (`gate(data, HighLowGate(...) & QuadrantGate(...))`).

## Implementation Details

If you want to implement a new manual gate to be included in ESM, you need to:

* Open a pull request with the following code changes
* Define a new struct for your method type in `src/methods.jl`
* The type of that struct is a subtype of `AbstractManualGate`
* Define a new method dispatch `gate(data, ::NameOfNewMethodType)`
* Document that method in the manual gating documentation (this page)

!!! note
    Gates can only return a single group that "passes" the gate. For example, it is not possible to have a single `QuadrantGate` that separates the data into all four quadrants. This is so that it plays nicely with the ESM transformations. If you need to gate into all four quadrants, you should define four `QuadrantGate`s, each with different values of the `quadrant` parameter.

If you are unsure how to do any of these steps, feel free to [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose) asking for a new manual gate and explaining how the gate should work.
