# Data Format

The ESM data format (the format used for `.esm` files) is a JSON format, with its highest level storing 4 key-value pairs. The keys are "samples", "groups", "transformations", and "views", with their values defined as outlined below.

## Samples

Samples stores key-value pairs, with keys as the sample names. Each samples stores its own variables (in key-value pairs), with:

* a variable called "values" that stores the channel data as key-value pairs (with each channel storing an ordered list),
* a "type" variable that indicates whether the data is a "timeseries" (like plate reader data) or "population" (like flow cytometry data),
* and a "meta" variable to store any other associated data in key-value pairs, such as amplifier settings.

!!! todo
    Rename meta to metadata

```json
{
    "samples":{
        "plate_01_time":{
            "values":{
                "OD":[
                    "00:08:38",
                    "18:38:38"
                ],
                "flo":[
                    "00:09:04",
                    "18:39:04"
                ]
            },
            "type":"timeseries",
            "meta":{}
        },
        "plate_01_temperature":{
            "values":{
                "OD":[
                37.0,
                37.0
            ]
            },
            "type":"timeseries",
            "meta":{}
        },
        "plate_01_a1":{
            "values":{
                "OD":[
                    0.165,
                    0.916
                ],
                "flo":[
                    21,
                    371
                ]
            },
            "type":"timeseries",
            "meta":{}
        },
        "plate_01_h12":{
            "values":{
                "OD":[
                    0.16,
                    0.148
                ],
                "flo":[
                    9,
                    7
                ]
            },
            "type":"timeseries",
            "meta":{}
        },
        "plate_02_a1":{
            "values":{
                "FL1_H":[
                    9.057978,
                    537.61176,
                    6.152654,
                    259.45526
                ],
                "SSC_H":[
                    280.0,
                    735.0,
                    128.0,
                    1023.0
                ]
            },
            "type":"population",
            "meta":{
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
                }
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
                "plate_01_t° read 1:700",
                "plate_01_a1",
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
        "flow_cyt":{
            "equation":"process_fcs(\"plate_02\",[\"FSC_H\",\"SSC_H\"],[\"FL1_H\"])"
        },
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
        "flow_cy":{
            "data":[
            "flow_cyt"
        ]
        },
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
