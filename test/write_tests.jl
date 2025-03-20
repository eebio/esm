@testitem "read data" begin
    es = ESM.read_data("inputs/example.xlsx")
    @test es[:samples]["plate_01_a1"][:values]["FSC-H"] == [628, 1023, 373, 1023]
    @test es[:samples]["plate_01_a1"][:values]["FL4-H"] ≈
          [28.133175, 310.590027, 3.819718, 2414.418213]
    @test es[:samples]["plate_01_a1"][:type] == "population"
    @test es[:samples]["plate_01_a1"][:meta]["FL1-H"][:range] == "1024"
    @test es[:samples]["plate_01_a1"][:meta]["FL1-H"][:amp_type] == "0,0"
end

@testitem "write esm" begin
    # write esm from example.xlsx and read it back
    es = ESM.read_data("inputs/example.xlsx")
    filename = Base.Filesystem.mktempdir() * "/tmp"
    ESM.write_esm(es; name = filename)
    es = ESM.read_esm(filename * ".esm")

    @test_skip issetequal(es.samples.name,
        ["plate_01_a1.FL1", "plate_01_a1.SSC", "plate_01_a1.FSC",
            "plate_01_a2.FL1", "plate_01_a2.SSC", "plate_01_a2.FSC"])
    @test_skip issetequal(es.samples.channel, ["FL1", "SSC", "FSC", "FL1", "SSC", "FSC"])
    @test_skip issetequal(es.samples.type,
        ["population", "population", "population",
            "population", "population", "population"])
    @test_skip issetequal(es.samples.values[3][1:5], [39387138, 58112, 0, 34996226, 61952])
    @test_skip es.samples.name[1] == "plate_01_a2.FL1"
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
    @test_skip issetequal(es.groups.sample_IDs, [["plate_01_a1", "plate_01_a2"]])
    @test_skip issetequal(es.groups.metadata, [Dict("autodefined" => "true")])
    @test_skip es.transformations ==
               Dict("flow_cyt" => Dict("equation" => "process_fcs(\"plate_01\",[\"FSC\",\"SSC\"],[\"FL1\"])"))
    @test es.views == Dict("flow_cy" => Dict("data" => ["flow_cyt"]))
end

@testitem "read tecan" begin end
