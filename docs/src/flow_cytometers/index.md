# [Introduction](@id flow_cytometry)

## Data Formats

ESM currently supports importing data from flow cytometry `.fcs` files. Specifically, it supports FCS versions 3.0 and 3.1.

!!! todo "todo"
    fcs versions compatibility

If you require support for a different FCS version, please [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose), and let us know what version you require.

## Methods

ESM provides a variety of methods for gating flow cytometry data. These are split into two categories: [Automatic Gating](@ref) and [Manual Gating](@ref).

[Automatic Gating](@ref) has a collection of methods that will automatically gate the data, requiring at most specifying the channels to gate on.

[Manual Gating](@ref) is designed to allow you to perform gating in separate software, and then include those gates in ESM.
