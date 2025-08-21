@testitem "read data" setup=[environment_path] begin
    es = ESM.read_data("inputs/example.xlsx")
    @test es[:samples]["plate_02_a1"][:values]["FSC-H"] == [628, 1023, 373, 1023]
    @test es[:samples]["plate_02_a1"][:values]["FL4-H"] ≈
          [28.133175, 310.590027, 3.819718, 2414.418213]
    @test es[:samples]["plate_02_a1"][:type] == "population"
    @test es[:samples]["plate_02_a1"][:meta]["FL1-H"][:range] == "1024"
    @test es[:samples]["plate_02_a1"][:meta]["FL1-H"][:amp_type] == "0,0"
end

@testitem "write esm" setup=[environment_path] begin
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
    @test issetequal(keys(es_written.transformations), ["flow_cyt", "flow_sub", "od_sub"])
    @test es_written.transformations["flow_cyt"] ==
          Dict{String, Any}("equation" => "process_fcs(\"plate_02\",[\"FSC-H\",\"SSC-H\"],[\"FL1-H\"])")
    @test issetequal(keys(es_written.views), ["flowsub", "mega", "group2", "flow_cy", "sample", "odsub", "group1", "group3"])
    @test es_written.views["mega"] ==
          Dict{String, Any}("data" => Any["first_group", "second_group"])
end

@testitem "read spectramax" setup=[environment_path] begin
    data = ESM.read_data("inputs/spectramax.xlsx")
    # TODO should probably separate the channels into 600 and 700?
    # TODO channel is currently 535 for fluorescence but the 485 is also relevant
    @test data[:samples]["plate_01_a1"][:values]["abs"][[1, 2, end - 1, end]] ==
          [0.1493, 0.1623, 0.3297, 0.3629]
    @test data[:samples]["plate_01_e12"][:values]["abs"][[1, 2, end - 1, end]] == [
        0.0776, 0.0772, 0.2173, 0.2359]
    wells = [string("plate_01_", row, col) for row in 'a':'e', col in 1:12] # Only A-E have data
    wells = [wells..., "plate_01_time", "plate_01_temperature(�c)"]  # Flatten to a 1D vector
    @test issetequal(keys(data[:samples]), wells)
end

@testitem "read biotek" setup=[environment_path] begin
    data = ESM.read_data("inputs/biotek.xlsx")
    @test data[:samples]["plate_01_a1"][:values]["od1"][[1, 2, end - 1, end]] ==
          [0.134, 0.133, 0.131, 0.131]
    @test data[:samples]["plate_01_h12"][:values]["od2"][[1, 2, end - 1, end]] == [
        0.114, 0.113, 0.577, 0.578]
    @test data[:samples]["plate_01_a2"][:values]["485,530[2]"][[1, 2, end - 1, end]] == [
        166, 162, 1030, 1024]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_time"]  # Flatten to a 1D vector
    @test issubset(wells, keys(data[:samples])) # TODO should be issetequal, but there is some weirdness around how the temperature is stored in the data - there is a temperature column per channel which includes the channel name
end

@testitem "read plate reader directories" setup=[environment_path] begin
    using Dates

    data = ESM.read_data("inputs/example.xlsx")
    @test data[:samples]["plate_01_time"][:values]["OD"][1:2] ==
          Dates.Time[Dates.Time(0, 8, 38), Dates.Time(0, 18, 38)]
    @test data[:samples]["plate_01_time"][:values]["OD"][end] == Dates.Time(18, 38, 38)
    @test data[:samples]["plate_01_a1"][:values]["OD"][1:3] == [0.165, 0.167, 0.169]
    @test data[:samples]["plate_01_h12"][:values]["OD"][end] == 0.148

    @test data[:samples]["plate_01_time"][:values]["flo"][1:2] ==
          Dates.Time[Dates.Time(0, 9, 04), Dates.Time(0, 19, 04)]
    @test data[:samples]["plate_01_time"][:values]["flo"][end] == Dates.Time(18, 39, 04)
    @test data[:samples]["plate_01_a1"][:values]["flo"][1:3] == [21, 22, 20]
    @test data[:samples]["plate_01_h12"][:values]["flo"][end] == 7
end

@testitem "expand_group" begin
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
