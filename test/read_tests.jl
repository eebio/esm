# Test read_esm function
@testmodule MockESM begin
    using eebiotools
    mock_data = """
{
    "samples": {
        "plate_01_a1": {
            "values": {
                "FL1": [
                    169472,
                    -117439489,
                    24444930,
                    202496,
                    1946157137
                ],
                "SSC": [
                    251658858,
                    63373312,
                    0,
                    1090519744,
                    41025536
                ],
                "FSC": [
                    22020098,
                    255488,
                    -83885057,
                    21954562,
                    169472
                ]
            },
            "type": "population",
            "meta": {
                "FL1": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": "850",
                    "amp_type": "4.0,1.0",
                    "ex_wav": "488,561",
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FL1",
                    "det_type": null,
                    "perc_em": null
                },
                "SSC": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": "460",
                    "amp_type": "0,0",
                    "ex_wav": "488,561",
                    "amp_gain": null,
                    "name_s": null,
                    "name": "SSC",
                    "det_type": null,
                    "perc_em": null
                },
                "FSC": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": "10.0",
                    "amp_type": "0,0",
                    "ex_wav": "488,561",
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FSC",
                    "det_type": null,
                    "perc_em": null
                }
            }
        },
        "plate_01_a2": {
            "values": {
                "FL1": [
                    10240,
                    0,
                    38600706,
                    61440,
                    0
                ],
                "SSC": [
                    -822083441,
                    7536640,
                    0,
                    -1073741504,
                    15269888
                ],
                "FSC": [
                    39387138,
                    58112,
                    0,
                    34996226,
                    61952
                ]
            },
            "type": "population",
            "meta": {
                "FL1": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": "850",
                    "amp_type": "4.0,1.0",
                    "ex_wav": "488,561",
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FL1",
                    "det_type": null,
                    "perc_em": null
                },
                "SSC": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": "600",
                    "amp_type": "4.0,1.0",
                    "ex_wav": "488,561",
                    "amp_gain": null,
                    "name_s": null,
                    "name": "SSC",
                    "det_type": null,
                    "perc_em": null
                },
                    "ex_pow": null,
                "FSC": {
                    "range": "1024",
                    "filter": null,
                    "det_volt": "10.0",
                    "amp_type": "4.0,1.0",
                    "ex_wav": "488,561",
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FSC",
                    "det_type": null,
                    "perc_em": null
                }
            }
        }
    },
    "groups": {
        "plate_01": {
            "type": "physical",
            "sample_IDs": [
                "plate_01_a1",
                "plate_01_a2"
            ],
            "metadata": {
                "autodefined": "true"
            }
        }
    },
    "transformations": {
        "flow_cyt": {
            "equation": "process_fcs(\\\"plate_01\\\",[\\\"FSC\\\",\\\"SSC\\\"],[\\\"FL1\\\"])"
        }
    },
    "views": {
        "flow_cy": {
            "data": [
                "flow_cyt"
            ]
        }
    }
}

"""

    # Write mock data to a temporary file
    temp_file = Base.Filesystem.mktempdir()*"/temp_mock_data.esm"
    open(temp_file, "w") do f
        write(f, mock_data)
    end
end

@testitem "read_esm tests" setup=[MockESM] begin
    es = eebiotools.read_esm(MockESM.temp_file)
    @test issetequal(es.samples.name, ["plate_01_a1.FL1", "plate_01_a1.SSC", "plate_01_a1.FSC", "plate_01_a2.FL1", "plate_01_a2.SSC", "plate_01_a2.FSC"])
    @test issetequal(es.samples.channel, ["FL1", "SSC", "FSC", "FL1", "SSC", "FSC"])
    @test issetequal(es.samples.type, ["population", "population", "population", "population", "population", "population"])
    @test issetequal(es.samples.values, [[169472, -117439489, 24444930, 202496, 1946157137], [251658858, 63373312, 0, 1090519744, 41025536], [22020098, 255488, -83885057, 21954562, 169472], [10240, 0, 38600706, 61440, 0], [-822083441, 7536640, 0, -1073741504, 15269888], [39387138, 58112, 0, 34996226, 61952]])
    @test es.samples.name[1] == "plate_01_a2.FL1" # why this order?
    @test es.samples.name[5] == "plate_01_a1.SSC"
    @test es.samples.meta[1] == Dict("amp_type" => "4.0,1.0", "filter" => nothing, "det_type" => nothing, "name" => "FL1", "range" => "1024", "ex_pow" => nothing, "det_volt" => "850", "amp_gain" => nothing, "ex_wav" => "488,561", "perc_em" => nothing, "name_s" => nothing)
    @test es.samples.meta[6] == Dict("amp_type" => "0,0", "filter" => nothing, "det_type" => nothing, "name" => "FSC", "range" => "1024", "ex_pow" => nothing, "det_volt" => "10.0", "amp_gain" => nothing, "ex_wav" => "488,561", "perc_em" => nothing, "name_s" => nothing)
    for i in 1:6
        @test issetequal(keys(es.samples.meta[i]), ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav", "amp_gain", "name_s", "name", "det_type", "perc_em"]) broken=(i==3)
    end
    @test issetequal(es.groups.group, ["plate_01"])
    @test issetequal(es.groups.sample_IDs, [["plate_01_a1", "plate_01_a2"]])
    @test issetequal(es.groups.metadata, [Dict("autodefined" => "true")])
    @test es.transformations == Dict("flow_cyt" => Dict("equation" => "process_fcs(\"plate_01\",[\"FSC\",\"SSC\"],[\"FL1\"])"))
    @test es.views == Dict("flow_cy" => Dict("data" => ["flow_cyt"]))
end

# Test index_between_vals
@testitem "index_between_vals" begin
    using DataFrames

    # Sample data for testing
    df = DataFrame(A = 1:10, B = 11:20)

    result = eebiotools.index_between_vals(df; minv=3, maxv=8)
    @test result["A"] == (3, 8)
    @test result["B"] == (nothing, nothing)
    
    result = eebiotools.index_between_vals(df; minv=5, maxv=10)
    @test result["A"] == (5, 10)
    @test result["B"] == (nothing, nothing)
    
    result = eebiotools.index_between_vals(df; minv=0, maxv=15)
    @test result["A"] == (1, 10)
    @test result["B"] == (1, 5)

    result = eebiotools.index_between_vals(df; minv=2.5, maxv=13.5)
    @test result["A"] == (3, 10)
    @test result["B"] == (1, 3)

    result = eebiotools.index_between_vals(df)
    @test result["A"] == (1,10)
    @test result["B"] == (1,10)
end

# Test between_times
@testitem "between_times" begin
    using DataFrames

    # Sample data for testing
    df = DataFrame(A = 1:10, B = 11:20)
    time_col = DataFrame(Time = ["00:08:38", "00:18:38", "00:28:38", "00:38:38", "00:48:38", "00:58:38", "01:08:38", "01:18:38", "01:28:38", "01:30:00"])

    result = eebiotools.between_times(df, time_col; mint=0, maxt=0)
    @test result == DataFrame(A = [], B = [])
    
    result = eebiotools.between_times(df, time_col; mint=1e-11, maxt=3e-11)
    @test result == DataFrame(A = [], B = [])
    
    result = eebiotools.between_times(df, time_col; mint=9, maxt=15)
    @test result == DataFrame(A = [], B = [])

    result = eebiotools.between_times(df, time_col; mint=0, maxt=50)
    @test result == DataFrame(A = 1:5, B = 11:15)

    result = eebiotools.between_times(df, time_col; mint=90, maxt=90)
    @test result == DataFrame(A = 10, B = 20)
end

# Test at_time
@testitem "at_time" begin
    using DataFrames

    # Sample data for testing
    df = DataFrame(A = 1:10, B = 11:20)
    time_col = DataFrame(Time = ["00:08:38", "00:18:38", "00:28:38", "00:38:38", "00:48:38", "00:58:38", "01:08:38", "01:18:38", "01:28:38", "01:38:38"])

    # Recasts into DataFrame again as this removes the Row indexes (which are used as part of DataFrame equality comparison)
    @test DataFrame(eebiotools.at_time(df, time_col, 30)) == DataFrame(A = 3, B = 13)
    
    @test DataFrame(eebiotools.at_time(df, time_col, 0)) == DataFrame(A = [], B = [])
    
    @test DataFrame(eebiotools.at_time(df, time_col, 1000)) == DataFrame(A = 10, B = 20)
end

# Test at_od
@testitem "at_od" begin
    using DataFrames
    #TODO unclear how function inputs should be handled here
    # Sample data for at_od
    od_df = DataFrame(A = [0.1, 0.2, 0.3, 0.4, 0.5], B = [0.2, 0.3, 0.4, 0.5, 0.6])
    target_df = DataFrame(A = [10, 20, 30, 40, 50], B = [20, 30, 40, 50, 60])

    @test eebiotools.at_od(od_df, target_df, 0.3) == DataFrame(A = 30, B = 30)
    @test eebiotools.at_od(od_df, target_df, 0.1) == DataFrame(A = 10, B = nothing)
    @test eebiotools.at_od(od_df, target_df, 0.5) == DataFrame(A = 50, B = 50)
end

# Test doubling_time
@testitem "doubling_time" begin
    using DataFrames

    od_df = DataFrame(A = [0.05, 0.1, 0.2, 0.4, 0.8])
    time_col = DataFrame(Time = ["00:00:00", "00:01:00", "00:02:00", "00:03:00", "00:04:00"])

    @test eebiotools.doubling_time(od_df, time_col) ≈ DataFrame(A = 1.0)
    @test eebiotools.doubling_time(od_df, time_col; max_od=0.5) ≈ DataFrame(A = 1.0)
    @test eebiotools.doubling_time(od_df, time_col; max_od=0.3) ≈ DataFrame(A = 1.0)
    # TODO: Add some more tests with more awkward data
end

@testitem "expression" setup = [MockESM] begin
    es = eebiotools.read_esm(MockESM.temp_file)
    es.transformations["extra_transform"] = Dict{String, Any}("equation" => "sum([1,2,3,4])")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
    
    @test eebiotools.sexp_to_nested_list(5,es,trans_meta_map) == 5 #Test numbers
    @test eebiotools.sexp_to_nested_list(:("hello"),es,trans_meta_map) == "hello" # Test strings
    @test eval(eebiotools.sexp_to_nested_list(:(sum([1,2,3])),es,trans_meta_map)) == 6 # Test functions
    @test eval(eebiotools.sexp_to_nested_list(:extra_transform,es,trans_meta_map)) == 10 # Test accessing transformations
    @test_broken eebiotools.sexp_to_nested_list(:flow_cyt,es,trans_meta_map) == ["process_fcs", "plate_01", ["FSC", "SSC"], ["FL1"]] # Test accessing views
end
