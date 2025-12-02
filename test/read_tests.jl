# Test read_esm function
@testmodule MockESM begin
    println("MockESM")
    using ESM
    mock_data = """
{
    "samples": {
        "plate_01_a1": {
            "values": {
                "FL1_A": [
                    54.0,
                    143.0,
                    25.0,
                    71.0
                ],
                "SSC_H": [
                    534.0,
                    645.0,
                    346.0,
                    1254.0
                ],
                "FSC_H": [
                    634.0,
                    965.0,
                    643.0,
                    1015.0
                ]
            },
            "type": "population",
            "meta": {
                "FL1_A": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FL1-A",
                    "det_type": null,
                    "perc_em": null
                },
                "SSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "2,0.01",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "SSC-H",
                    "name": "SSC-H",
                    "det_type": null,
                    "perc_em": null
                },
                "FSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "FSC-H",
                    "name": "FSC-H",
                    "det_type": null,
                    "perc_em": null
                }
            }
        },
        "plate_01_a2": {
            "values": {
                "FL1_A": [
                    0.0,
                    143.0,
                    0.0,
                    61.0
                ],
                "SSC_H": [
                    280.0,
                    735.0,
                    128.0,
                    1023.0
                ],
                "FSC_H": [
                    628.0,
                    1023.0,
                    373.0,
                    1023.0
                ]
            },
            "type": "population",
            "meta": {
                "FL1_A": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": null,
                    "name": "FL1-A",
                    "det_type": null,
                    "perc_em": null
                },
                "SSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "2,0.01",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "SSC-H",
                    "name": "SSC-H",
                    "det_type": null,
                    "perc_em": null
                },
                "FSC_H": {
                    "range": "1024",
                    "ex_pow": null,
                    "filter": null,
                    "det_volt": null,
                    "amp_type": "0,0",
                    "ex_wav": null,
                    "amp_gain": null,
                    "name_s": "FSC-H",
                    "name": "FSC-H",
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
    println("read_esm tests")
    es = read_esm(MockESM.temp_file)
    @test issetequal(es.samples.name,
        ["plate_01_a1.FL1_A", "plate_01_a1.SSC_H", "plate_01_a1.FSC_H",
            "plate_01_a2.FL1_A", "plate_01_a2.SSC_H", "plate_01_a2.FSC_H"])
    @test issetequal(es.samples.channel, ["FL1_A", "SSC_H", "FSC_H", "FL1_A", "SSC_H", "FSC_H"])
    @test issetequal(es.samples.type,
        ["population", "population", "population",
            "population", "population", "population"])
    @test issetequal(es.samples.values,
        [
            [54.0, 143.0, 25.0, 71.0],
            [534.0, 645.0, 346.0, 1254.0],
            [634.0, 965.0, 643.0, 1015.0],
            [0.0, 143.0, 0.0, 61.0],
            [280.0, 735.0, 128.0, 1023.0],
            [628.0, 1023.0, 373.0, 1023.0]
        ])
    # Why this order?
    @test es.samples.name[1] == "plate_01_a2.FL1_A"
    @test es.samples.name[5] == "plate_01_a1.SSC_H"
    @test es.samples.meta[1] == Dict{String, Any}(
        "amp_type" => "0,0", "filter" => nothing, "det_type" => nothing,
        "name" => "FL1-A", "range" => "1024", "det_volt" => nothing,
        "amp_gain" => nothing, "name_s" => nothing,
        "perc_em" => nothing, "ex_wav" => nothing, "ex_pow" => nothing)
    @test es.samples.meta[6] == Dict{String, Any}(
        "amp_type" => "0,0", "filter" => nothing, "det_type" => nothing,
        "name" => "FSC-H", "range" => "1024", "det_volt" => nothing,
        "amp_gain" => nothing, "name_s" => "FSC-H",
        "perc_em" => nothing, "ex_wav" => nothing, "ex_pow" => nothing)
    for i in 1:6
        @test issetequal(keys(es.samples.meta[i]),
            ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav",
                "amp_gain", "name_s", "name", "det_type", "perc_em"])
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
    println("index_between_vals")
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
    println("between_times")
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
    println("at_time")
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

# df2time
@testitem "df2time" begin
    println("df2time")
    using DataFrames

    # Sample data for testing
    time_col = DataFrame(Time = [
        "00:08:38", "00:18:38", "00:28:38", "00:38:38", "00:48:38",
        "00:58:38", "01:08:38", "01:18:38", "01:28:38", "01:38:38"])

    result = ESM.df2time(time_col)
    @test result == DataFrame(Time = [
        8+38/60, 18+38/60, 28+38/60, 38+38/60, 48+38/60, 58+38/60,
        68+38/60, 78+38/60, 88+38/60, 98+38/60] .* 60)
    result2 = ESM.df2time(result)
    @test result2 == result
end

# Test at_od
@testitem "at_od" begin
    println("at_od")
    using DataFrames
    #TODO unclear how function inputs should be handled here
    # Sample data for at_od
    od_df = DataFrame(A = [0.1, 0.2, 0.3, 0.4, 0.5], B = [0.2, 0.3, 0.4, 0.5, 0.6])
    target_df = DataFrame(A = [10, 20, 30, 40, 50], B = [20, 30, 40, 50, 60])

    @test ESM.at_od(od_df, target_df, 0.3) == DataFrame(A = 30, B = 30)
    @test ESM.at_od(od_df, target_df, 0.1) == DataFrame(A = 10, B = nothing)
    @test ESM.at_od(od_df, target_df, 0.5) == DataFrame(A = 50, B = 50)
end

@testitem "expression" setup=[MockESM] begin
    println("expression")
    using DataFrames
    es = read_esm(MockESM.temp_file)
    es.transformations["extra_transform"] = Dict{String, Any}("equation" => "sum([1,2,3,4])")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))

    #Test numbers
    @test ESM.sexp_to_nested_list(5, es, trans_meta_map) == 5
    # Test strings
    @test ESM.sexp_to_nested_list(:("hello"), es, trans_meta_map) == "hello"
    # Test functions
    @test eval(ESM.sexp_to_nested_list(:(sum([1, 2, 3])), es, trans_meta_map)) == 6
    # Test accessing transformations
    @test eval(ESM.sexp_to_nested_list(:extra_transform, es, trans_meta_map)) == 10
    # Test accessing views
    @test ESM.sexp_to_nested_list(:flow_cyt, es, trans_meta_map) == 1
    # Test accessing groups
    @test ESM.sexp_to_nested_list(:plate_01, es, trans_meta_map) == Dict{Any, Any}(
        "FL1_A" => Dict(
            :data => [54.0, 143.0, 25.0, 71.0, 0.0, 143.0, 0.0, 61.0],
            :id => collect(1:8), :max => 1024.0, :min => 1.0),
        "SSC_H" => Dict(
            :data => [0.11039991779173976, 0.18187190885323648,
                0.04740031742312117, 2.8133175148587766, 0.03522694651473101,
                0.272613196449465, 0.01778279410038923, 0.9955128609158501],
            :id => collect(1:8), :max => 1.0, :min => 0.010045073642544625),
        "FSC_H" => Dict(
            :data => [634.0, 965.0, 643.0, 1015.0, 628.0, 1023.0, 373.0, 1023.0],
            :id => collect(1:8), :max => 1024.0, :min => 1.0)
        )
    # Test other symbols - should just be returned
    @test ESM.sexp_to_nested_list(:not_defined, es, trans_meta_map) == :not_defined
    @test ESM.sexp_to_nested_list(:(form_df(es.samples)), es, trans_meta_map) ==
          :(form_df(es.samples))
    # Test samples
    @test ESM.sexp_to_nested_list(:plate_01_a1, es, trans_meta_map) == Dict{Any, Any}(
        "FL1_A" => Dict{Symbol, Any}(
            :max => 1024.0, :id => 1:4, :data => [54.0, 143.0, 25.0, 71.0], :min => 1.0),
        "SSC_H" => Dict{Symbol, Any}(:max => 1.0,
            :id => 1:4,
            :data => [0.11039991779173976, 0.18187190885323648,
                0.04740031742312117, 2.8133175148587766],
            :min => 0.010045073642544625),
        "FSC_H" => Dict{Symbol, Any}(
            :max => 1024.0, :id => 1:4, :data => [634.0, 965.0, 643.0, 1015.0], :min => 1.0))
    # Test channels
    @test ESM.sexp_to_nested_list(:(plate_01_a1.FL1_A), es, trans_meta_map) ==
          Dict{String, Dict{Symbol, Any}}("FL1_A" => Dict(
        :max => 1024.0, :id => 1:4, :data => [54.0, 143.0, 25.0, 71.0], :min => 1.0))
    @test ESM.sexp_to_nested_list(:(plate_01.SSC_H), es, trans_meta_map) ==
          Dict{String, Dict{Symbol, Any}}("SSC_H" => Dict(:max => 1.0,
        :id => [1, 2, 3, 4, 5, 6, 7, 8],
        :data => [0.11039991779173976, 0.18187190885323648,
            0.04740031742312117, 2.8133175148587766, 0.03522694651473101,
            0.272613196449465, 0.01778279410038923, 0.9955128609158501],
        :min => 0.010045073642544625))
    # Test groups
    @test ESM.sexp_to_nested_list(:(plate_01.FL1_A), es, trans_meta_map) ==
          Dict{String, Dict{Symbol, Any}}("FL1_A" => Dict(
        :max => 1024.0, :id => [1, 2, 3, 4, 5, 6, 7, 8],
        :data => [54.0, 143.0, 25.0, 71.0, 0.0, 143.0, 0.0, 61.0], :min => 1.0))
end

@testitem "produce_views" begin
    println("produce_views")
    es = read_esm("inputs/example.esm")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))
    a = ESM.produce_views(es, trans_meta_map)
    # Test groups
    @test issetequal(
        keys(a), ["group1", "group2", "group3", "flowsub", "odsub", "sample", "mega"])
    @test issetequal(names(a["group1"]),
        ["plate_01_a5.OD", "plate_01_a5.flo", "plate_01_a1.OD",
            "plate_01_a1.flo", "plate_01_a9.OD", "plate_01_a9.flo"])
    @test issetequal(names(a["group2"]),
        ["plate_01_a8.OD", "plate_01_a8.flo", "plate_01_a3.OD",
            "plate_01_a3.flo", "plate_01_a7.OD", "plate_01_a7.flo"])
    @test issetequal(names(a["group3"]),
        ["plate_01_a2.OD", "plate_01_a2.flo", "plate_01_a1.OD",
            "plate_01_a1.flo", "plate_01_a3.OD", "plate_01_a3.flo"])
    @test a["group1"][1:3, "plate_01_a5.OD"] == Any[0.169, 0.173, 0.177]
    @test a["group2"][2:4, "plate_01_a8.OD"] == Any[0.152, 0.154, 0.157]
    @test a["group3"][(end - 2):end, "plate_01_a3.flo"] == Any[211, 201, 209]
    # Test mega group
    @test issetequal(names(a["mega"]),
        ["plate_01_a5.OD", "plate_01_a5.flo", "plate_01_a1.OD",
            "plate_01_a1.flo", "plate_01_a9.OD", "plate_01_a9.flo",
            "plate_01_a8.OD", "plate_01_a8.flo", "plate_01_a3.OD", "plate_01_a3.flo",
            "plate_01_a7.OD", "plate_01_a7.flo"])
    @test a["mega"][1:3, "plate_01_a5.OD"] == Any[0.169, 0.173, 0.177]
    @test a["mega"][2:4, "plate_01_a8.OD"] == Any[0.152, 0.154, 0.157]
    @test a["mega"][(end - 2):end, "plate_01_a3.flo"] == Any[211, 201, 209]
    # Test sample
    @test names(a["sample"]) == ["plate_01_time.flo"]
    @test a["sample"][[1, 2, end - 1, end], "plate_01_time.flo"] ==
          Any["00:09:04", "00:19:04", "18:29:04", "18:39:04"]
    # Test expressions
    @test issetequal(names(a["flowsub"]),
        ["plate_01_a5", "plate_01_a1", "plate_01_a9",
            "plate_01_a8", "plate_01_a3", "plate_01_a7"])
    @test issetequal(names(a["odsub"]),
        ["plate_01_a5", "plate_01_a1", "plate_01_a9",
            "plate_01_a8", "plate_01_a3", "plate_01_a7"])
    @test a["flowsub"][[1, 2, end - 1, end], "plate_01_a9"] ≈ [
        0.33333333333333215, -2.666666666666668, -160.66666666666669, -162.33333333333331]
    @test a["odsub"][[1, 2, end - 1, end], "plate_01_a3"] ≈
          [0.0026666666666666783, 0.0026666666666666783,
        -0.10200000000000009, -0.10133333333333328]

    # Test non-DataFrame handling
    # Numbers
    using DataFrames
    es.views["number_view"] = Dict{String, Any}("data" => ["extra_transform"])
    es.views["numbers_view2"] = Dict{String, Any}("data" => ["extra_transform", "extra_transform2"])
    es.transformations["extra_transform"] = Dict{String, Any}("equation" => "42")
    es.transformations["extra_transform2"] = Dict{String, Any}("equation" => "7")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))
    out = ESM.produce_views(es, trans_meta_map; to_out = ["number_view"])
    @test all(out["number_view"] .== Tables.table([42;;]))
    out = ESM.produce_views(es, trans_meta_map; to_out = ["numbers_view2"])
    @test all(out["numbers_view2"] .== Tables.table([42 7]))
    # Matrices
    es.views["matrix_view"] = Dict{String, Any}("data" => ["extra_transform3", "extra_transform4"])
    es.transformations["extra_transform3"] = Dict{String, Any}("equation" => "[1 2 3; 4 5 6]")
    es.transformations["extra_transform4"] = Dict{String, Any}("equation" => "[7 8; 10 11]")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))
    out = ESM.produce_views(es, trans_meta_map; to_out = ["matrix_view"])
    @test all(out["matrix_view"] .== Tables.table([1 2 3 7 8; 4 5 6 10 11]))

    # Test errors
    es.views["bad_view"] = Dict{String, Any}("data" => ["nonexistent_group"])
    msg = "View bad_view = nonexistent_group is not a sample, group or transformation"
    @test_throws msg ESM.produce_views(es, trans_meta_map; to_out = ["bad_view"])
end

@testitem "to_rfi" begin
    println("to_rfi")
    es = read_esm("inputs/example.esm")
    out = ESM.to_rfi(es, "plate_02_a1")
    # Linear test with no gain
    @test out["FSC_H"][:data] == [628.0, 1023.0, 373.0, 1023.0]
    @test out["FSC_H"][:max] == 1024.0
    @test out["FSC_H"][:min] == 1.0
    # Scaling factor gain test
    @test out["FL1_H"][:data] ≈ [2.26449442, 134.40293884, 1.53816354, 64.86381531]
    # Log scaling test
    @test out["SSC_H"][:data] ≈ [0.03522695, 0.2726132, 0.01778279, 0.99551286]
end

@testitem "summary" begin
    println("summary")
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
    @test_throws "Please provide" summarise()
    @test_throws "File type" summarise(file = "biotek-summarise.csv")
    @test_throws "Unsupported" summarise(file = "inputs/unknown.txt", type = "unknown")
end

@testitem "issue 34" begin
    # Importing from excel with single channel reads a Int, not a String
    # which can then fail at regex
    read_data("inputs/issue34.xlsx")
end
