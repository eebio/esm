# Formats and types of data expected
This document describes the data types and experiments that are expected for the tools. 

## Plate reader

- Uses multi-well plates as a method for input of samples.
- Plates can be 96, 384 or 1536 wells in size.
- Experiments can be a single time point, time series or a spectra.
- Data collected is absorbance, fluorescence intensity, time resolved fluorescence, luminescence, polarization and light scattering.
- Data is generally reported in rows and columns associated with a particular. 
- Labelling is generally per well. 
- Data can be collected over many plates.

### Experiment types:

- Spectra
- Time point
- Time series

### File Types:

- CSV
- TSV
- Excel

### File Organization:

- Rows/Columns - index is the data type
- Matrix

### Standard Data Manipulations:

- Normalise OD by media.
- Normalise the fluorescence by OD.
- Conversion to RPU/other calibrant.

---------------------------------------
## Flow cytometry

- Time point
- Series of time points

### Experiment types:
- Any florescent or scattering data.

### File Types: 

- FCS format

### File Organization:

- 1 FCS file per well

### Standard Data Manipulations:

- Gating
- Calibration beads
- Analysis of histograms

-----------------------------------
## qPCR 

- Time point
- Series of time points

### Experiment types:

### File Types: 

### File Organization:

### Standard Data Manipulations:

----------------------------------------
