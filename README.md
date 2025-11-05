# Experimental Simple Model (ESM)

![Tests](https://github.com/eebio/esm/actions/workflows/test.yml/badge.svg)
[![codecov](https://codecov.io/gh/eebio/esm/graph/badge.svg?token=AL85Z9I06H)](https://codecov.io/gh/eebio/esm)
[![docs](https://img.shields.io/badge/docs-ESM-blue)](https://eebio.github.io/esm/)

## What is ESM?

ESM is a data format and supporting tools to enable accessible and reproducible data processing for engineering biology.

It allows standardised and reproducible processing of plate reader, flow cytometry, and qPCR data.

## How does it work?

The ESM data format is composed of a structured JSON file (named the `.esm` file) containing the raw data (in a standardised format) and the post-processing commands that are run on the data. This means that uploading a `.esm` file a supplementary data for an article allows anyone to view the raw data and see (and reproduce) exactly how it was processed to derive the results seen in the article.

Since we have all the data in a standardised format, we can (and do) provide a set of methods for processing the data. This includes calibration methods, flow cytometry gating, and calculating summary statistics such as growth rate or per cell fluorescence. While we provide many possible methods for each of these, we also offer sensible, robust, benchmark-verified defaults that should work in the majority of cases.

ESM can be used either as a Julia package, or more typically, through its command line interface. If you want to learn how to use ESM, check out the [documentation](https://eebio.github.io/esm/).

## Contributing

There are a couple of ways you can contribute towards ESM.

* If you have a method that you would like to see included in ESM, please [open a new issue](https://github.com/eebio/esm/issues/new),
* If you have a plate reader machine that isn't currently supported (see [the docs](https://eebio.github.io/esm/plate_readers/compatibility/) for current compatability), please [open a new issue](https://github.com/eebio/esm/issues/new),
* If you find a bug or mistake in the documentation, please [open a new issue](https://github.com/eebio/esm/issues/new).
