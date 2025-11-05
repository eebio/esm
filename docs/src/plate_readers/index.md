# [Introduction](@id plate_reader)

## Data Formats

ESM currently supports importing data from the following plate readers:

* SpectraMax
* BioTek
* Tecan
* Generic tabular data (format specified in [Compatibility](@ref))

This list is being continualy expanded. If you have a plate reader machine that is not in this list, and are interested in helping us support it within ESM, please [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose), and upload a data file from that machine.

For more details on the plate reader formats we support, how they have been verified, and how new methods can be added, please see the [Compatibility](@ref) page.

## Methods

ESM provides a variety of methods for handling some common summary statistics. These summary statistics are:

* [Growth Rate](@ref) (or doubling time)
* [Per cell fluorescence](@ref Fluorescence)
* [Calibration](@ref)

## Summarise

If you wish to get an overview of some plate reader data, without needing to set up a full `.esm` file, you can use `summarise`.

```julia
using ESM
summarise("path/to/spectramax-data.csv", SpectraMax())
# or if you want plots as well
summarise("path/to/spectramax-data.csv", SpectraMax(); plot=true)
```

```bash
esm summarise --file path/to/spectramax-data.csv --type spectramax
esm summarise --file path/to/spectramax-data.csv --type spectramax --plot
```

If plots are included (either through the flag on the CLI or the keyword arguement through the Julia package), then a PDF file at `path/to/spectramax-data.csv.pdf` will be created with plots of all wells, and temperature, over time, for all channels.
