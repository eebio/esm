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
    filename = joinpath(Base.Filesystem.mktempdir(), "tmp")
    ESM.write_esm(es; name = filename)
    es = ESM.read_esm(filename * ".esm")

    @test_skip issetequal(es.samples.name,
        ["plate_02_a1.FL1", "plate_02_a1.SSC", "plate_02_a1.FSC",
            "plate_02_a2.FL1", "plate_02_a2.SSC", "plate_02_a2.FSC"])
    @test_skip issetequal(es.samples.channel, ["FL1", "SSC", "FSC", "FL1", "SSC", "FSC"])
    @test_skip issetequal(es.samples.type,
        ["population", "population", "population",
            "population", "population", "population"])
    @test_skip issetequal(es.samples.values[3][1:5], [39387138, 58112, 0, 34996226, 61952])
    @test_skip es.samples.name[1] == "plate_02_a2.FL1"
    @test_skip es.samples.meta[1] == Dict("amp_type" => "4.0,1.0", "filter" => nothing,
        "det_type" => nothing, "name" => "FL1", "range" => "1024",
        "ex_pow" => nothing, "det_volt" => "850", "amp_gain" => nothing,
        "ex_wav" => "488,561", "perc_em" => nothing, "name_s" => nothing)
    @test_skip es.samples.meta[6] ==
               Dict("amp_type" => "0,0", "filter" => nothing, "det_type" => nothing,
        "name" => "FSC", "range" => "1024", "ex_pow" => nothing,
        "det_volt" => "10.0", "amp_gain" => nothing,
        "ex_wav" => "488,561", "perc_em" => nothing, "name_s" => nothing)
    for i in 1:6
        @test_skip issetequal(keys(es.samples.meta[i]),
            ["range", "ex_pow", "filter", "det_volt", "amp_type", "ex_wav",
                "amp_gain", "name_s", "name", "det_type", "perc_em"])
    end
    @test_skip issetequal(es.groups.group, ["plate_01"])
    @test_skip issetequal(es.groups.sample_IDs, [["plate_02_a1", "plate_02_a2"]])
    @test_skip issetequal(es.groups.metadata, [Dict("autodefined" => "true")])
    @test_skip es.transformations ==
               Dict("flow_cyt" => Dict("equation" => "process_fcs(\"plate_01\",[\"FSC\",\"SSC\"],[\"FL1\"])"))
    @test_skip es.views == Dict("flow_cy" => Dict("data" => ["flow_cyt"]))
end

@testitem "read spectramax" setup=[environment_path] begin
    data = ESM.read_data("inputs/spectramax.xlsx")
    # TODO should probably separate the channels into 600 and 700?
    # TODO channel is currently 535 for fluorescence but the 485 is also relevant
    @test data[:samples]["plate_01_a1"][:values]["600 700"][[1, 2, end - 1, end]] ==
          [0.1493, 0.1623, 0.3297, 0.3629]
    @test data[:samples]["plate_01_e12"][:values]["600 700"][[1, 2, end - 1, end]] == [
        0.0776, 0.0772, 0.2173, 0.2359]
    wells = [string("plate_01_", row, col) for row in 'a':'e', col in 1:12] # Only A-E have data
    wells = [wells..., "plate_01_time", "plate_01_temperature(�c)"]  # Flatten to a 1D vector
    @test issetequal(keys(data[:samples]), wells)
end

@testitem "read biotek" setup=[environment_path] begin
    data = ESM.read_data("inputs/biotek.xlsx")
    @test data[:samples]["plate_01_a1"][:values]["600"][[1, 2, end - 1, end]] ==
          [0.134, 0.133, 0.131, 0.131]
    @test data[:samples]["plate_01_h12"][:values]["700"][[1, 2, end - 1, end]] == [
        0.114, 0.113, 0.577, 0.578]
    @show keys(data[:samples]["plate_01_a1"][:values])
    @test_broken data[:samples]["plate_01_a2"][:values]["485,530[2]"][[
        1, 2, end - 1, end]] == [
        166, 162, 1030, 1024] # TODO Fix test, it interprets channel 485,530[2] as 485,530
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
