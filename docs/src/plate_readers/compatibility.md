# Compatibility

## Verification

Different plate reader machines format their outputs in different ways. To ensure compatibility with a plate reader format, we require data from different plate reader types. We then include this data within some of the ESM tests to ensure that the data is correctly parsed, and future changes do not break this functionality.

* SpectraMax was verified using data from a "Molecular Devices SpectraMax iD5 multi-mode microplate reader (Serial: 375703621)"
* BioTek was verfied using data from a "BioTek Synergy neo2 multi-mode reader (Serial: 18071614)"
* Tecan was verified using data from a "Tecan Infinite 200 Pro (Cat#: 30050303 Serial: 1906010638)"

If you find that you are using any of these plate reader brands and your data is not being correctly parsed, please let us know by [opening an issue on GitHub](https://github.com/eebio/esm/issues/new/choose).

## Generic tabular data

!!! note
    If you are considering using the generic tabular data format because your plate reader is not supported, please [open an issue on GitHub](https://github.com/eebio/esm/issues/new/choose). You only need to upload a data file from your plate reader (one that you haven't editted), and tell us the plate reader model and we will cover the rest to ensure it is supported in future. Feel free to open an issue and then use the generic format if you don't want to wait.

If you can't use any of the automated imports above, maybe your plate reader isn't supported (see the note above) or the original files have been editted already and no longer parse correctly, then you can use the generic tabular data format.

This format involves creating a folder for your plate reader data, and storing your data in multiple `.tsv` or `.csv` files (one per channel), with the channel in the filename.

For an example for how the data looks in this format, see the [pr_folder](https://github.com/eebio/esm/tree/7234ddd342eda8dddf607c4cd50502cbebf68964/test/inputs) in our test directory. It has plate reader data for two channels, `OD` and `flu` stored as `.tsv` files.

Each file should have a first row that is a header of column names, including "time" and "temperature", followed by well names. Times should be given in the hh:mm:ss format. Temperature should be given in celcius.
