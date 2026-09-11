@testitem "untranslate" begin
    using DataFrames
    using JSON

    data = Dict(
        "samples" => Dict(
            "plate_01_a1" => Dict(
                "type" => "timeseries",
                "values" => Dict("od" => [1.0, 2.0]),
                "metadata" => Dict(
                    "raw_metadata" => "",
                    "template" => Dict(
                        "sample_type" => "plate reader",
                        "data_location" => "data/plate.csv",
                        "plate_brand" => "biotek",
                        "channels" => ["OD_600"],
                        "plate" => 1,
                        "well" => ""
                    )
                )
            ),
            "plate_01_a2" => Dict(
                "type" => "timeseries",
                "values" => Dict("od" => [3.0, 4.0]),
                "metadata" => Dict(
                    "raw_metadata" => "",
                    "template" => Dict(
                        "sample_type" => "plate reader",
                        "data_location" => "data/plate.csv",
                        "plate_brand" => "biotek",
                        "channels" => ["OD_600"],
                        "plate" => 1,
                        "well" => ""
                    )
                )
            ),
            "plate_02_a1" => Dict(
                "type" => "population",
                "values" => Dict("fsc_a" => [1.0, 2.0]),
                "metadata" => Dict(
                    "template" => Dict(
                        "sample_type" => "flow",
                        "data_location" => "data/sample.fcs",
                        "plate_brand" => "",
                        "channels" => ["FSC-A"],
                        "plate" => 2,
                        "well" => "a1"
                    )
                )
            )
        ),
        "groups" => Dict(
            "control" => Dict(
                "type" => "experimental",
                "sample_IDs" => ["plate_01_a1", "plate_01_a2"],
                "metadata" => Dict("condition" => "control")
            ),
            "plate_01" => Dict(
                "type" => "physical",
                "sample_IDs" => ["plate_01_a1", "plate_01_a2"],
                "metadata" => Dict("autodefined" => "true")
            )
        ),
        "transformations" => Dict("od_mean" => Dict("equation" => "mean(control.od)")),
        "views" => Dict("control_view" => Dict("data" => ["control", "od_mean"])),
        "metadata" => Dict(
            "schema_version" => "0.4.0",
            "channel_map" => Dict("OD_600" => "od", "FSC-A" => "fsc_a")
        )
    )

    dir = Base.Filesystem.mktempdir()
    input = joinpath(dir, "input.esm")
    output = joinpath(dir, "output.xlsx")
    JSON.json(input, data; pretty = true)
    ESM.untranslate_esm(input, output)

    samples = DataFrame(ESM.XLSX.readtable(output, "Samples"; stop_in_empty_row = false))
    @test nrow(samples) == 2
    plate_row = findfirst(samples[!, "Type"] .== "plate reader")
    flow_row = findfirst(samples[!, "Type"] .== "flow")
    @test samples[plate_row, "Data Location"] == "data/plate.csv"
    @test samples[plate_row, "Channels"] == "OD_600"
    @test samples[flow_row, "Well"] == "a1"

    channel_map = DataFrame(ESM.XLSX.readtable(output, "Channel Map";
        stop_in_empty_row = false))
    od_row = findfirst(channel_map[!, "Channel"] .== "OD_600")
    @test channel_map[od_row, "New name"] == "od"

    groups = DataFrame(ESM.XLSX.readtable(output, "Groups"; stop_in_empty_row = false))
    @test nrow(groups) == 1
    @test groups[1, "Name"] == "control"
    @test groups[1, "Samples"] == "plate_01_a1, plate_01_a2"
    @test groups[1, "condition"] == "control"
    @test !("autodefined" in names(groups))

    transformations = DataFrame(ESM.XLSX.readtable(output, "Transformations";
        stop_in_empty_row = false))
    @test transformations[1, "Equation"] == "mean(control.od)"
    views = DataFrame(ESM.XLSX.readtable(output, "Views"; stop_in_empty_row = false))
    @test views[1, "View"] == "control, od_mean"
end
