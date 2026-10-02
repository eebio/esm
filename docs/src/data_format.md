# Data Format

The Longwing Data Standards data format (the format used for `.lw` files) is a JSON format, with its highest level storing the keys "samples", "groups", "transformations", "views", and "metadata". The first four keys contain the data structures described below. The `metadata` object contains information about the Longwing version and how the source data was imported.

## Samples

Samples stores key-value pairs, with keys as the sample names. Each samples stores its own variables (in key-value pairs), with:

* a variable called "values" that stores the channel data as key-value pairs (with each channel storing an ordered list),
* a "type" variable that indicates whether the data is a "timeseries" (like plate reader data) or "population" (like flow cytometry data),
* and a "metadata" variable to store any other associated data in key-value pairs, such as amplifier settings for flow cytometers. For flow cytometry data, this includes per-channel instrument parameters. For both flow cytometry and plate reader data, `"metadata"` also contains a `"raw_metadata"` key with the complete raw metadata from the original file (all FCS parameters for flow data, or the file header for plate reader data).

Times are formatted as an integer number of milliseconds. Flow cytometry channel data is converted to RFI.

```json
{
    "samples":{
        "plate_01_time":{
            "values":{
                "OD":[
                    518000,
                    ...
                    67118000
                ],
                "flo":[
                    544714,
                    ...
                    67144719
                ]
            },
            "type":"timeseries",
            "metadata": {
                "raw_metadata": "Plate:\tPlate1\t1.3\t ... FALSE\tRaw\tFALSE\t1\t52\t52\t1\t535\t1\t12\t96\t485\tManual\t6\tHigh\t1\t5\t485\n",
                "template": {
                    "channels": [
                        "535_485",
                        "600",
                        "700"
                    ],
                    "data_location": ".../spectramax-summarise.txt",
                    "plate": 1,
                "plate_brand": "SpectraMax",
                "sample_type": "plate reader",
                "well": ""
                }
            }
        },
        "plate_01_temperature":{
            "values":{
                "OD":[
                37.0,
                ...
                37.0
            ],
            "flo": [
                36.9,
                ...
                37.0
            ]
            },
            "type":"timeseries",
            "metadata": {
                "raw_metadata": "Plate:\tPlate1\t1.3\t ... FALSE\tRaw\tFALSE\t1\t52\t52\t1\t535\t1\t12\t96\t485\tManual\t6\tHigh\t1\t5\t485\n",
                "template": {
                    "channels": [
                        "535_485",
                        "600",
                        "700"
                    ],
                    "data_location": ".../spectramax-summarise.txt",
                    "plate": 1,
                "plate_brand": "SpectraMax",
                "sample_type": "plate reader",
                "well": ""
                }
            }
        },
        "plate_01_a1":{
            "values":{
                "OD":[
                    0.165,
                    ...
                    0.916
                ],
                "flo":[
                    21,
                    ...
                    371
                ]
            },
            "type":"timeseries",
            "metadata": {
                "raw_metadata": "Plate:\tPlate1\t1.3\t ... FALSE\tRaw\tFALSE\t1\t52\t52\t1\t535\t1\t12\t96\t485\tManual\t6\tHigh\t1\t5\t485\n",
                "template": {
                    "channels": [
                        "535_485",
                        "600",
                        "700"
                    ],
                    "data_location": ".../spectramax-summarise.txt",
                    "plate": 1,
                "plate_brand": "SpectraMax",
                "sample_type": "plate reader",
                "well": ""
                }
            }
        },
        ...
        "plate_01_h12":{
            "values":{
                "OD":[
                    0.16,
                    ...
                    0.148
                ],
                "flo":[
                    9,
                    ...
                    7
                ]
            },
            "type":"timeseries",
            "metadata": {
                "raw_metadata": "Plate:\tPlate1\t1.3\t ... FALSE\tRaw\tFALSE\t1\t52\t52\t1\t535\t1\t12\t96\t485\tManual\t6\tHigh\t1\t5\t485\n",
                "template": {
                    "channels": [
                        "535_485",
                        "600",
                        "700"
                    ],
                    "data_location": ".../spectramax-summarise.txt",
                    "plate": 1,
                "plate_brand": "SpectraMax",
                "sample_type": "plate reader",
                "well": ""
                }
            }
        },
        "plate_02_a1":{
            "values":{
                "FL1_H":[
                    9.057978,
                    537.61176,
                    6.152654,
                    259.45526,
                    ...
                ],
                "SSC_H":[
                    280.0,
                    735.0,
                    128.0,
                    1023.0,
                    ...
                ],
                ...
            },
            "type":"population",
            "metadata":{
                "FL1_H":{
                    "range":"1024",
                    "ex_pow":null,
                    "filter":null,
                    "det_volt":null,
                    "amp_type":"0,0",
                    "ex_wav":null,
                    "amp_gain":"4",
                    "name_s":null,
                    "name":"FL1-H",
                    "det_type":null,
                    "perc_em":null
                },
                "SSC_H":{
                    "range":"1024",
                    "ex_pow":null,
                    "filter":null,
                    "det_volt":null,
                    "amp_type":"2,0.01",
                    "ex_wav":null,
                    "amp_gain":null,
                    "name_s":"SSC-H",
                    "name":"SSC-H",
                    "det_type":null,
                    "perc_em":null
                },
                ...
            }
        }
    },
}
```

## Groups

Under groups, we have key-value pairs (the name of the group is the key) with:

* a variable called "type" that defines whether the group is a physical group (plates), or an experimental group (like blanks or controls),
* a variable called "sample_IDs" that defines which samples are included in the group as an ordered list,
* and a variable called "metadata" that may include any additional information about the group, such as whether the group was automatically defined, as is done with the "plate" groups.

```json
{
   "groups":{
        "first_group":{
            "type":"experimental",
            "sample_IDs":[
                "plate_01_A1",
                "plate_01_A5",
                "plate_01_A9"
            ],
            "metadata":{}
        },
        "second_group":{
            "type":"experimental",
            "sample_IDs":[
                "plate_01_A3",
                "plate_01_A8",
                "plate_01_A7"
            ],
            "metadata":{}
        },
        "third_group":{
            "type":"experimental",
            "sample_IDs":[
                "plate_01_A1",
                "plate_01_A2",
                "plate_01_A3"
            ],
            "metadata":{}
        },
        "plate_01":{
            "type":"physical",
            "sample_IDs":[
                "plate_01_time",
                "plate_01_temperature",
                "plate_01_a1",
                ...
                "plate_01_h12"
            ],
            "metadata":{
                "autodefined":"true"
            }
        },
        "plate_02":{
            "type":"physical",
            "sample_IDs":[
                "plate_02_a1"
            ],
            "metadata":{
                "autodefined":"true"
            }
        }
    },
}
```

## Transformations

Under transformations, we have key-value pairs (the name of the transformation is the key) with a variable called "equation" that stores the transformation as a string.

```json
{
    "transformations":{
        "flow_sub":{
            "equation":"hcat(first_group.flo,second_group.flo).-mean(third_group.flo)"
        },
        "od_sub":{
            "equation":"hcat(first_group.OD,second_group.OD).-mean(third_group.OD)"
        }
    },
}
```

## Views

Under views, we have key-value pairs (name of the view is the key) with a variable called "data" that represents an ordered list of groups, transformations, wells, etc. to be included in the view.

```json
{
    "views":{
        "group1":{
            "data":[
            "first_group"
        ]
        },
        "group2":{
            "data":[
            "second_group"
        ]
        },
        "group3":{
            "data":[
            "third_group"
        ]
        },
        "sample":{
            "data":[
            "plate_01_time.flo"
        ]
        },
        "flowsub":{
            "data":[
            "flow_sub"
        ]
        },
        "odsub":{
            "data":[
            "od_sub"
        ]
        },
        "mega":{
            "data":[
            "first_group",
            "second_group"
        ]
        }
    }
}
```

## Metadata

In addition to metadata about your samples and groups, Longwing also stores a range of metadata about the `.lw` file itself. This is to help aid in reproducibility of the analysis.
This metadata is generated when the `.lw` file is created. It may be changed when the `.lw` file is edited with `lw interactive`, in which case it will be overridden and the old metadata will be stored in the description. The idea behind including this metadata is so that the versions of the software used to do the analysis (the Longwing version and its dependencies), which is likely to be the same as the version used to generate the `.lw` file, is recorded as part of the `.lw` file, which can help to track down changes either in the functionality of Longwing or its dependencies.

```json
"metadata": {
    "Manifest.toml": "...",
    "Project.toml": "...",
    "channel_map": {
      "535_485": "535_485",
      "600": "abs600",
      "700": "abs700",
      "FSC_H": "FSC_H"
    },
    "date_created": "",
    "date_modified": "",
    "description": "",
    "longwing_version": "0.4.0",
    "longwing_data_standard_version": "0.4.0",
    "versioninfo": "..."
}
```
