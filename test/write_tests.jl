@testitem "read data" setup=[environment_path] begin
    println("read data")
    lw = read_data("inputs/example.xlsx")
    @test es["samples"]["plate_02_a1"]["values"]["FSC_H"] == [628, 1023, 373, 1023]
    @test es["samples"]["plate_02_a1"]["values"]["FL4_H"] ≈
        [28.133175, 310.590027, 3.819718, 2414.418213]
    @test es["samples"]["plate_02_a1"]["type"] == "population"
    @test es["samples"]["plate_02_a1"]["metadata"]["FL1_H"]["range"] == "1024"
    @test es["samples"]["plate_02_a1"]["metadata"]["FL1_H"]["amp_type"] == "0,0"
    @test es["groups"]["first_group"]["sample_IDs"] ==
        ["plate_01_A1", "plate_01_A5", "plate_01_A9"]
    @test es["groups"]["second_group"]["sample_IDs"] ==
        ["plate_01_A3", "plate_01_A8", "plate_01_A7"]
    @test es["groups"]["third_group"]["sample_IDs"] ==
        ["plate_01_A1", "plate_01_A2", "plate_01_A3"]
end

@testitem "write lw" setup=[environment_path] begin
    println("write lw")
    # write lw from example.xlsx and read it back
    lw = read_data("inputs/example.xlsx")
    filename = joinpath(Base.Filesystem.mktempdir(), "tmp.longwing")
    write_longwing(lw, filename)
    es_written = read_longwing(filename)
    names = []
    for (i, j) in es["samples"]
        for k in keys(j["values"])
            push!(names, "$(i).$(k)")
        end
    end
    @test issetequal(names,
        es_written.samples.name)
    @test issetequal(
        unique(es_written.samples.channel), [
        "OD", "flo", "FL1_H", "SSC_H", "FL3_H", "FL1_A", "FL4_H", "FSC_H"])
    @test es_written.samples.type[.!occursin.(r"(OD|flo)", es_written.samples.name)] ==
        [
        "population", "population", "population", "population", "population", "population"]
    @test es["samples"]["plate_01_b3"]["values"]["flo"] ==
        es_written.samples.values[findfirst(es_written.samples.name .==
        "plate_01_b3.flo")]
    for i in findall(.!occursin.(r"(OD|flo)", es_written.samples.name))
        @test issetequal(keys(es_written.sampllw.metadata[i]),
            ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav",
                "amp_gain", "name_s", "name", "det_type", "perc_em", "longwing_well", "raw_metadata", "template"])
    end
    @test issetequal(es_written.groups.group,
        ["plate_01", "plate_02", "first_group", "second_group", "third_group"])
    @test es_written.groups.sample_IDs[es_written.groups.group .== "plate_02"] ==
        [["plate_02_a1"]]
    @test es_written.groups.metadata[es_written.groups.group .== "plate_02"] ==
        [Dict("autodefined" => "true")]
    @test issetequal(keys(es_written.transformations), ["flow_sub", "od_sub"])
    @test es_written.transformations["flow_sub"] ==
        Dict{String,Any}("equation" => "hcat(first_group.flo,second_group.flo).-mean(eachcol(third_group.flo))")
    @test issetequal(keys(es_written.views),
        ["flowsub", "mega", "group2", "sample", "odsub", "group1", "group3"])
    @test es_written.views["mega"] ==
        Dict{String,Any}("data" => Any["first_group", "second_group"])
end

@testitem "expand_group" begin
    println("expand_group")
    @test Longwing.expand_group("plate_01_a[1:3]") ==
        ["plate_01_a1", "plate_01_a2", "plate_01_a3"]
    @test Longwing.expand_group("plate_01_a[2:4]") ==
        ["plate_01_a2", "plate_01_a3", "plate_01_a4"]
    @test Longwing.expand_group("plate_01_[a:d]1") ==
        ["plate_01_a1", "plate_01_b1", "plate_01_c1", "plate_01_d1"]
    @test Longwing.expand_group("plate_01_[a:c]1[2:3]") ==
        ["plate_01_a12", "plate_01_b12", "plate_01_c12",
        "plate_01_a13", "plate_01_b13", "plate_01_c13"]
    @test Longwing.expand_group("plate_01_[a:2:e]1") ==
        ["plate_01_a1", "plate_01_c1", "plate_01_e1"]
    @test Longwing.expand_group("plate_01_a[1:3:10]") ==
        ["plate_01_a1", "plate_01_a4", "plate_01_a7", "plate_01_a10"]

    # expand_groups
    @test Longwing.expand_groups("plate_01_a[1:3],plate_01_b[2:4], plate_02_c5,plate_01_d[1,2]") ==
        ["plate_01_a1", "plate_01_a2", "plate_01_a3",
        "plate_01_b2", "plate_01_b3", "plate_01_b4",
        "plate_02_c5", "plate_01_d1", "plate_01_d2"]
    # Test without commas
    @test Longwing.expand_groups("plate_01_a[1:3]") ==
        ["plate_01_a1", "plate_01_a2", "plate_01_a3"]
end

@testitem "flow cytometry data" setup=[environment_path] begin
    println("flow cytometry data")

    using DataFrames
    lw = read_data("inputs/small.xlsx")
    filename = joinpath(Base.Filesystem.mktempdir(), "tmp.longwing")
    write_longwing(lw, filename)
    es_written = read_longwing(filename)

    @test issetequal(es_written.samples.name,
        ["plate_01_a1.FL1_H", "plate_01_a1.SSC_H",
            "plate_01_a1.forward", "plate_01_a1.newtime"])

    # Run transformations on small.longwing
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es_written.transformations[i]["equation"])
                          for i in keys(es_written.transformations))
    @test eval(Longwing.sexp_to_nested_list(:(f), es_written, trans_meta_map)) ==
        DataFrame(:longwing_well => ["A1", "A1", "A1", "A1"], :forward => [628.0, 1023.0, 373.0, 1023.0],
        Symbol("forward.max") => fill(1024.0, 4),
        Symbol("forward.min") => fill(1.0, 4), :id =>
        [1, 2, 3, 4])
    @test isapprox(eval(Longwing.sexp_to_nested_list(:(ssc), es_written, trans_meta_map))[!, Not(:longwing_well)],
        DataFrame(:SSC_H => [0.0352269, 0.272613, 0.0177828, 0.995513],
            Symbol("SSC_H.max") => fill(1.0, 4),
            Symbol("SSC_H.min") => fill(0.0100451, 4), :id => [1, 2, 3, 4]); atol=0.0001)
    @test eval(Longwing.sexp_to_nested_list(:(ssc), es_written, trans_meta_map))[!, :longwing_well] ==
        ["A1", "A1", "A1", "A1"]
    @test isapprox(
        eval(Longwing.sexp_to_nested_list(:(plate_01_a1.FL1_H), es_written, trans_meta_map))[!, Not(:longwing_well)],
        DataFrame(:FL1_H => [2.26449, 134.403, 1.53816, 64.8638],
            Symbol("FL1_H.max") => fill(256.0, 4),
            Symbol("FL1_H.min") => fill(0.25, 4), :id => [1, 2, 3, 4]); atol=0.0001)
    @test eval(Longwing.sexp_to_nested_list(:(plate_01_a1.FL1_H), es_written, trans_meta_map))[!, :longwing_well] ==
        ["A1", "A1", "A1", "A1"]
    @test issetequal(
        names(eval(Longwing.sexp_to_nested_list(:(plate_01), es_written, trans_meta_map))),
        ["FL1_H", "FL1_H.max", "FL1_H.min", "SSC_H", "SSC_H.max",
            "SSC_H.min", "forward", "forward.max", "forward.min", "newtime",
            "newtime.max", "newtime.min", "newtime.max", "newtime.min", "id", "longwing_well"])
end
