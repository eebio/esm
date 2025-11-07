# Test read_esm function
@testmodule MockESM begin
    using ESM
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
            "equation": "1"
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
    temp_file = joinpath(Base.Filesystem.mktempdir(), "temp_mock_data.esm")
    open(temp_file, "w") do f
        write(f, mock_data)
    end
end

@testitem "read_esm tests" setup=[MockESM] begin
    es = ESM.read_esm(MockESM.temp_file)
    @test issetequal(es.samples.name,
        ["plate_01_a1.FL1", "plate_01_a1.SSC", "plate_01_a1.FSC",
            "plate_01_a2.FL1", "plate_01_a2.SSC", "plate_01_a2.FSC"])
    @test issetequal(es.samples.channel, ["FL1", "SSC", "FSC", "FL1", "SSC", "FSC"])
    @test issetequal(es.samples.type,
        ["population", "population", "population",
            "population", "population", "population"])
    @test issetequal(es.samples.values,
        [[169472, -117439489, 24444930, 202496, 1946157137],
            [251658858, 63373312, 0, 1090519744, 41025536],
            [22020098, 255488, -83885057, 21954562, 169472],
            [10240, 0, 38600706, 61440, 0],
            [-822083441, 7536640, 0, -1073741504, 15269888],
            [39387138, 58112, 0, 34996226, 61952]])
    # Why this order?
    @test es.samples.name[1] == "plate_01_a2.FL1"
    @test es.samples.name[5] == "plate_01_a1.SSC"
    @test es.samples.meta[1] == Dict("amp_type" => "4.0,1.0", "filter" => nothing,
        "det_type" => nothing, "name" => "FL1", "range" => "1024",
        "ex_pow" => nothing, "det_volt" => "850", "amp_gain" => nothing,
        "ex_wav" => "488,561", "perc_em" => nothing, "name_s" => nothing)
    @test es.samples.meta[6] ==
          Dict("amp_type" => "0,0", "filter" => nothing, "det_type" => nothing,
        "name" => "FSC", "range" => "1024", "ex_pow" => nothing,
        "det_volt" => "10.0", "amp_gain" => nothing,
        "ex_wav" => "488,561", "perc_em" => nothing, "name_s" => nothing)
    for i in 1:6
        @test issetequal(keys(es.samples.meta[i]),
            ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav",
                "amp_gain", "name_s", "name", "det_type", "perc_em"]) broken=(i == 3)
    end
    @test issetequal(es.groups.group, ["plate_01"])
    @test issetequal(es.groups.sample_IDs, [["plate_01_a1", "plate_01_a2"]])
    @test issetequal(es.groups.metadata, [Dict("autodefined" => "true")])
    @test es.transformations ==
          Dict("flow_cyt" => Dict("equation" => "1"))
    @test es.views == Dict("flow_cy" => Dict("data" => ["flow_cyt"]))
end

# Test index_between_vals
@testitem "index_between_vals" begin
    using DataFrames

    # Sample data for testing
    df = DataFrame(A = 1:10, B = 11:20)

    result = ESM.index_between_vals(df; minv = 3, maxv = 8)
    @test result["A"] == (3, 8)
    @test result["B"] == (nothing, nothing)

    result = ESM.index_between_vals(df; minv = 5, maxv = 10)
    @test result["A"] == (5, 10)
    @test result["B"] == (nothing, nothing)

    result = ESM.index_between_vals(df; minv = 0, maxv = 15)
    @test result["A"] == (1, 10)
    @test result["B"] == (1, 5)

    result = ESM.index_between_vals(df; minv = 2.5, maxv = 13.5)
    @test result["A"] == (3, 10)
    @test result["B"] == (1, 3)

    result = ESM.index_between_vals(df)
    @test result["A"] == (1, 10)
    @test result["B"] == (1, 10)
end

# Test between_times
@testitem "between_times" begin
    using DataFrames

    # Sample data for testing
    df = DataFrame(A = 1:10, B = 11:20)
    time_col = DataFrame(Time = [
        "00:08:38", "00:18:38", "00:28:38", "00:38:38", "00:48:38",
        "00:58:38", "01:08:38", "01:18:38", "01:28:38", "01:30:00"])

    result = ESM.between_times(df, time_col; mint = 0, maxt = 0)
    @test result == DataFrame(A = [], B = [])

    result = ESM.between_times(df, time_col; mint = 1e-11, maxt = 3e-11)
    @test result == DataFrame(A = [], B = [])

    result = ESM.between_times(df, time_col; mint = 9, maxt = 15)
    @test result == DataFrame(A = [], B = [])

    result = ESM.between_times(df, time_col; mint = 0, maxt = 50)
    @test result == DataFrame(A = 1:5, B = 11:15)

    result = ESM.between_times(df, time_col; mint = 90, maxt = 90)
    @test result == DataFrame(A = 10, B = 20)
end

# Test at_time
@testitem "at_time" begin
    using DataFrames

    # Sample data for testing
    df = DataFrame(A = 1:10, B = 11:20)
    time_col = DataFrame(Time = [
        "00:08:38", "00:18:38", "00:28:38", "00:38:38", "00:48:38",
        "00:58:38", "01:08:38", "01:18:38", "01:28:38", "01:38:38"])

    # Recasts into DataFrame again as this removes the Row indexes (which are used as part of DataFrame equality comparison)
    @test DataFrame(ESM.at_time(df, time_col, 30)) == DataFrame(A = 3, B = 13)

    @test DataFrame(ESM.at_time(df, time_col, 0)) == DataFrame(A = [], B = [])

    @test DataFrame(ESM.at_time(df, time_col, 1000)) == DataFrame(A = 10, B = 20)
end

# Test at_od
@testitem "at_od" begin
    using DataFrames
    #TODO unclear how function inputs should be handled here
    # Sample data for at_od
    od_df = DataFrame(A = [0.1, 0.2, 0.3, 0.4, 0.5], B = [0.2, 0.3, 0.4, 0.5, 0.6])
    target_df = DataFrame(A = [10, 20, 30, 40, 50], B = [20, 30, 40, 50, 60])

    @test ESM.at_od(od_df, target_df, 0.3) == DataFrame(A = 30, B = 30)
    @test ESM.at_od(od_df, target_df, 0.1) == DataFrame(A = 10, B = nothing)
    @test ESM.at_od(od_df, target_df, 0.5) == DataFrame(A = 50, B = 50)
end

# Test doubling_time
@testitem "doubling_time" begin
    using DataFrames

    od_df = DataFrame(A = [0.05, 0.1, 0.2, 0.4, 0.8])
    time_col = DataFrame(Time = [
        "00:00:00", "00:01:00", "00:02:00", "00:03:00", "00:04:00"])

    @test ESM.doubling_time(od_df, time_col, MaxOD()) ≈ DataFrame(A = 1.0)
    @test ESM.doubling_time(od_df, time_col, MaxOD(); max_od = 0.5) ≈ DataFrame(A = 1.0)
    @test ESM.doubling_time(od_df, time_col, MaxOD(); max_od = 0.3) ≈ DataFrame(A = 1.0)
    # TODO: Add some more tests with more awkward data
end

@testitem "growth_rate" begin
    using DataFrames

    od_df = DataFrame(A = [0.05, 0.1, 0.2, 0.4, 0.8])
    time_col = DataFrame(Time = [
        "00:00:00", "00:01:00", "00:02:00", "00:03:00", "00:04:00"])

    @test ESM.growth_rate(od_df, time_col, MaxOD())[1, "A"] ≈ log(2)

    @test_skip ESM.growth_rate(
        od_df, time_col; window_size = 0.5) # test_throws
end

@testitem "expression" setup=[MockESM] begin
    global ESM.es = ESM.read_esm(MockESM.temp_file)
    ESM.es.transformations["extra_transform"] = Dict{String, Any}("equation" => "sum([1,2,3,4])")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(ESM.es.transformations[i]["equation"])
    for i in keys(ESM.es.transformations))

    #Test numbers
    @test ESM.sexp_to_nested_list(5, ESM.es, trans_meta_map) == 5
    # Test strings
    @test ESM.sexp_to_nested_list(:("hello"), ESM.es, trans_meta_map) == "hello"
    # Test functions
    @test eval(ESM.sexp_to_nested_list(:(sum([1, 2, 3])), ESM.es, trans_meta_map)) == 6
    # Test accessing transformations
    @test eval(ESM.sexp_to_nested_list(:extra_transform, ESM.es, trans_meta_map)) == 10
    # Test accessing views
    @test_broken ESM.sexp_to_nested_list(:flow_cyt, ESM.es, trans_meta_map) ==
                 [1]
    # Test accessing groups
    @test ESM.sexp_to_nested_list(:plate_01, ESM.es, trans_meta_map) ==
          ESM.form_df(ESM.es.samples)
    # Test other symbols - should just be returned
    @test ESM.sexp_to_nested_list(:not_defined, ESM.es, trans_meta_map) == :not_defined
    @test_broken ESM.sexp_to_nested_list(:(form_df(ESM.es.samples)),ESM.es,trans_meta_map)

end

@testitem "produce_views" begin
    global ESM.es = ESM.read_esm("inputs/example.esm")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(ESM.es.transformations[i]["equation"])
    for i in keys(ESM.es.transformations))
    a = ESM.produce_views(ESM.es, trans_meta_map)
    # Test groups
    @test issetequal(keys(a), ["group1", "group2", "group3", "flowsub", "odsub", "sample", "mega"])
    @test issetequal(names(a["group1"]), ["plate_01_a5.OD", "plate_01_a5.flo", "plate_01_a1.OD", "plate_01_a1.flo", "plate_01_a9.OD", "plate_01_a9.flo"])
    @test issetequal(names(a["group2"]), ["plate_01_a8.OD", "plate_01_a8.flo", "plate_01_a3.OD", "plate_01_a3.flo", "plate_01_a7.OD", "plate_01_a7.flo"])
    @test issetequal(names(a["group3"]), ["plate_01_a2.OD", "plate_01_a2.flo", "plate_01_a1.OD", "plate_01_a1.flo", "plate_01_a3.OD", "plate_01_a3.flo"])
    @test a["group1"][1:3, "plate_01_a5.OD"] == Any[0.169, 0.173, 0.177]
    @test a["group2"][2:4, "plate_01_a8.OD"] == Any[0.152, 0.154, 0.157]
    @test a["group3"][(end - 2):end, "plate_01_a3.flo"] == Any[211, 201, 209]
    # Test mega group
    @test issetequal(names(a["mega"]),
    ["plate_01_a5.OD", "plate_01_a5.flo", "plate_01_a1.OD", "plate_01_a1.flo", "plate_01_a9.OD", "plate_01_a9.flo",
    "plate_01_a8.OD", "plate_01_a8.flo", "plate_01_a3.OD", "plate_01_a3.flo", "plate_01_a7.OD", "plate_01_a7.flo"])
    @test a["mega"][1:3, "plate_01_a5.OD"] == Any[0.169, 0.173, 0.177]
    @test a["mega"][2:4, "plate_01_a8.OD"] == Any[0.152, 0.154, 0.157]
    @test a["mega"][(end - 2):end, "plate_01_a3.flo"] == Any[211, 201, 209]
    # Test sample
    @test names(a["sample"]) == ["plate_01_time.flo"]
    @test a["sample"][[1, 2, end - 1, end], "plate_01_time.flo"] == Any["00:09:04", "00:19:04", "18:29:04", "18:39:04"]
    # Test expressions
    @test issetequal(names(a["flowsub"]), ["plate_01_a5", "plate_01_a1", "plate_01_a9", "plate_01_a8", "plate_01_a3", "plate_01_a7"])
    @test issetequal(names(a["odsub"]), ["plate_01_a5", "plate_01_a1", "plate_01_a9", "plate_01_a8", "plate_01_a3", "plate_01_a7"])
    @test a["flowsub"][[1, 2, end - 1, end], "plate_01_a9"] ≈ [0.33333333333333215, -2.666666666666668, -160.66666666666669, -162.33333333333331]
    @test a["odsub"][[1, 2, end - 1, end], "plate_01_a3"] ≈ [0.0026666666666666783, 0.0026666666666666783, -0.10200000000000009, -0.10133333333333328]
end

@testitem "to_rfi" begin
    global ESM.es = ESM.read_esm("inputs/example.esm")
    out = ESM.to_rfi("plate_02_a1")
    # Linear test with no gain
    @test out["FSC-H"][:data] == [628.0, 1023.0, 373.0, 1023.0]
    @test out["FSC-H"][:max] == 1024.0
    @test out["FSC-H"][:min] == 1.0
    # Scaling factor gain test
    @test out["FL1-H"][:data] ≈ [2.26449442, 134.40293884, 1.53816354, 64.86381531]
    # Log scaling test
    @test out["SSC-H"][:data] ≈ [0.03522695, 0.2726132, 0.01778279, 0.99551286]
end

@testitem "summary" begin
    summary("inputs/summarise.esm", ESMData(); plot = true)
    @test isfile("inputs/summarise.esm.pdf")
    rm("inputs/summarise.esm.pdf")
    summary("inputs/small.fcs", FlowCytometryData(); plot = true)
    @test isfile("inputs/small.fcs.pdf")
    rm("inputs/small.fcs.pdf")
    summary("inputs/spectramax-summarise.txt", SpectraMax(); plot = true)
    @test isfile("inputs/spectramax-summarise.txt.pdf")
    rm("inputs/spectramax-summarise.txt.pdf")
    summary("inputs/biotek-summarise.csv", BioTek(); plot = true)
    @test isfile("inputs/biotek-summarise.csv.pdf")
    rm("inputs/biotek-summarise.csv.pdf")
    summary("inputs/pr_folder", GenericTabular(); plot = true)
    @test isfile("inputs/pr_folder.pdf")
    rm("inputs/pr_folder.pdf")

    # Error checking
    @test_throws "Please provide" ESM.summarise()
    @test_throws "File type" ESM.summarise(file="biotek-summarise.csv")
    @test_throws "Unsupported" ESM.summarise(file="inputs/unknown.txt", type="unknown")
end
