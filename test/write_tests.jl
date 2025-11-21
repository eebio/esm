@testitem "read data" setup=[environment_path] begin
    println("read data")
    es = ESM.read_data("inputs/example.xlsx")
    @test es[:samples]["plate_02_a1"][:values]["FSC-H"] == [628, 1023, 373, 1023]
    @test es[:samples]["plate_02_a1"][:values]["FL4-H"] ≈
          [28.133175, 310.590027, 3.819718, 2414.418213]
    @test es[:samples]["plate_02_a1"][:type] == "population"
    @test es[:samples]["plate_02_a1"][:meta]["FL1-H"][:range] == "1024"
    @test es[:samples]["plate_02_a1"][:meta]["FL1-H"][:amp_type] == "0,0"
    @test es[:groups]["first_group"]["sample_IDs"] == ["plate_01_A1", "plate_01_A5", "plate_01_A9"]
    @test es[:groups]["second_group"]["sample_IDs"] == ["plate_01_A3", "plate_01_A8", "plate_01_A7"]
    @test es[:groups]["third_group"]["sample_IDs"] == ["plate_01_A1", "plate_01_A2", "plate_01_A3"]

    # Test errors
    @test_throws "Unknown instrument type: gibberish" ESM.read_data("inputs/bad_inst_type.xlsx")
end

@testitem "write esm" setup=[environment_path] begin
    println("write esm")
    # write esm from example.xlsx and read it back
    es = ESM.read_data("inputs/example.xlsx")
    filename = joinpath(Base.Filesystem.mktempdir(), "tmp.esm")
    ESM.write_esm(es, filename)
    es_written = ESM.read_esm(filename)
    names = [
        ["plate_01_$(letter)$(number).$(channel)"
         for letter in 'a':'h', number in 1:12, channel in ["OD", "flo"]]...,
        ["plate_02_a1.$(channel)"
         for channel in ["FSC-H", "SSC-H", "FL1-H", "FL1-H", "FL3-H", "FL1-A", "FL4-H"]]...,
        "plate_01_t° read 1:700.OD", "plate_01_time.OD", "plate_01_time.flo"] # TODO tidy up some of the name reading
    names = []
    for (i,j) in es[:samples]
        for k in keys(j[:values])
            push!(names, "$(i).$(k)")
        end
    end
    @test issetequal(names,
        es_written.samples.name)
    @test issetequal(
        unique(es_written.samples.channel), ["OD", "flo", "FL1-H", "SSC-H", "FL3-H", "FL1-A", "FL4-H", "FSC-H"])
    @test es_written.samples.type[end-5:end] ==
          ["population", "population", "population", "population", "population", "population"]
    @test es[:samples]["plate_01_b3"][:values]["flo"] ==
          es_written.samples.values[findfirst(es_written.samples.name .==
                                              "plate_01_b3.flo")]
    for i in length(es_written.samples.meta)-5:length(es_written.samples.meta)
        @test issetequal(keys(es_written.samples.meta[i]),
            ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav",
                "amp_gain", "name_s", "name", "det_type", "perc_em"])
    end
    @test issetequal(es_written.groups.group, ["plate_01", "plate_02", "first_group", "second_group", "third_group"])
    @test es_written.groups.sample_IDs[es_written.groups.group .== "plate_02"] == [["plate_02_a1"]]
    @test es_written.groups.metadata[es_written.groups.group .== "plate_02"] ==
        [Dict("autodefined" => "true")]
    @test issetequal(keys(es_written.transformations), ["flow_sub", "od_sub"])
    @test es_written.transformations["flow_sub"] ==
          Dict{String, Any}("equation" => "hcat(first_group.flo,second_group.flo).-colmean(third_group.flo)")
    @test issetequal(keys(es_written.views), ["flowsub", "mega", "group2", "sample", "odsub", "group1", "group3"])
    @test es_written.views["mega"] ==
          Dict{String, Any}("data" => Any["first_group", "second_group"])
end

@testitem "expand_group" begin
    println("expand_group")
    @test ESM.expand_group("plate_01_a[1:3]") == ["plate_01_a1", "plate_01_a2", "plate_01_a3"]
    @test ESM.expand_group("plate_01_a[2:4]") == ["plate_01_a2", "plate_01_a3", "plate_01_a4"]
    @test ESM.expand_group("plate_01_[a:d]1") == ["plate_01_a1", "plate_01_b1", "plate_01_c1", "plate_01_d1"]
    @test ESM.expand_group("plate_01_[a:c]1[2:3]") == ["plate_01_a12", "plate_01_b12", "plate_01_c12", "plate_01_a13", "plate_01_b13", "plate_01_c13"]
    @test ESM.expand_group("plate_01_[a:2:e]1") == ["plate_01_a1", "plate_01_c1", "plate_01_e1"]
    @test ESM.expand_group("plate_01_a[1:3:10]") == ["plate_01_a1", "plate_01_a4", "plate_01_a7", "plate_01_a10"]

    # expand_groups
    @test ESM.expand_groups("plate_01_a[1:3],plate_01_b[2:4], plate_02_c5,plate_01_d[1,2]") ==
          ["plate_01_a1", "plate_01_a2", "plate_01_a3", "plate_01_b2", "plate_01_b3", "plate_01_b4",
           "plate_02_c5", "plate_01_d1", "plate_01_d2"]
end
