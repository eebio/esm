# [Introduction](@id flow_cytometry)

## Data Formats

ESM currently supports importing data from flow cytometry `.fcs` files. Specifically, it supports FCS versions XXXX.

If you require support for a different FCS version, please [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose), and let us know what version you require.

## to_rfi

The `to_rfi` function is used to rescale the data according to amplifier settings and covert the data from the form described in ESM (a DataFrame), to the form used for gating and processing.

```@docs; canonical=false
to_rfi
```

## Methods

ESM provides a variety of methods for gating flow cytometry data. These are split into two categories: [Automatic Gating](@ref) and [Manual Gating](@ref).

[Automatic Gating](@ref) has a collection of methods that will automatically gate the data, requiring at most specifying the channels to gate on.

[Manual Gating](@ref) is designed to allow you to perform gating in separate software, and then include those gates in ESM.

## Summarise

If you wish to get an overview of some flow cytometry data, without needing to set up a full `.esm` file, you can use `summarise`.

```julia
using ESM
summarise("path/to/data.fcs")
# or if you want plots as well
summarise("path/to/data.fcs"; plot=true)
```

```bash
esm summarise --file path/to/data.fcs
# or if you want plots as well
esm summarise --file path/to/data.fcs --plot
```

If plots are included (either through the flag on the CLI or the keyword arguement through the Julia package), then a PDF file at `path/to/data.fcs.pdf` will be created with histograms of each channel, and 2d heatmaps of all pairs of channels.
