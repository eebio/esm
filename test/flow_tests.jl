@testmodule MockFlow begin
    println("MockFlow")
    using DataFrames
    data = DataFrame(
        "FSC_A" => [1.0, 2.0, 3.0, 4.0, 5.0],
        "FSC_A.min" => fill(0.0, 5),
        "FSC_A.max" => fill(1e5, 5),
        "SSC_A" => [100.0, 200.0, 300.0, 400.0, 500.0],
        "SSC_A.min" => fill(0.0, 5),
        "SSC_A.max" => fill(1e5, 5),
        "FL1_A" => [510.0, 520.0, 530.0, 540.0, 550.0],
        "FL1_A.min" => fill(0.0, 5),
        "FL1_A.max" => fill(1e5, 5),
        "FL2_A" => [51.0, 52.0, 53.0, 54.0, 55.0],
        "FL2_A.min" => fill(0.0, 5),
        "FL2_A.max" => fill(1e5, 5),
        "id" => [1, 2, 3, 4, 5]
    )
end

@testitem "manual gating" setup = [MockFlow] begin
    println("manual gating")
    # TODO check IDs are handled correctly
    datacopy = deepcopy(MockFlow.data)
    @test gate(MockFlow.data, HighLowGate(channel="FL1_A", min=515.0)).FL1_A == [520.0, 530.0, 540.0, 550.0]
    @test gate(MockFlow.data, HighLowGate(channel="SSC_A", max=301.0)).SSC_A == [100.0, 200.0, 300.0]
    @test gate(MockFlow.data, HighLowGate(channel="FSC_A", min=2.0, max=4.0)).FL1_A == [520.0, 530.0] # upper bounds are exclusive, lower bounds inclusive
    @test gate(MockFlow.data, HighLowGate(channel="FSC_A")).FL2_A == [51.0, 52.0, 53.0, 54.0, 55.0]
    @test gate(MockFlow.data, RectangleGate(channel_x="FSC_A", channel_y="SSC_A", x_min=2.0, x_max=4.5, y_min=50.0, y_max=301.0)).FSC_A == [2.0, 3.0]
    @test gate(MockFlow.data, RectangleGate(channel_x="FL1_A", channel_y="FL2_A", x_min=0.0, x_max=545.0, y_min=52.0, y_max=54.0)).SSC_A == [200.0, 300.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1_A", channel_y="FL2_A", x_cutoff=535.0, y_cutoff=54.5, quadrant=1)).FL1_A == [550.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1_A", channel_y="FL2_A", x_cutoff=535.0, y_cutoff=54.5, quadrant=2)).FL1_A == [540.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1_A", channel_y="FL2_A", x_cutoff=535.0, y_cutoff=54.5, quadrant=3)).SSC_A == [100.0, 200.0, 300.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1_A", channel_y="FL2_A", x_cutoff=535.0, y_cutoff=54.5, quadrant=4)).FL1_A == []
    polygon = [(1.5, 150.0), (3.0, 100.0), (4.5, 150.0), (4.0, 450.0), (2.0, 400.0)]
    @test gate(MockFlow.data, PolygonGate(channel_x="FSC_A", channel_y="SSC_A", points=polygon)).FSC_A == [2.0, 3.0, 4.0]
    # Test with point exactly on polygon edge
    edge_poly = [(2.0, 200.0), (5.0, 200.0), (5.0, 600.0), (3.5, 500.0), (3.2, 250.0)]
    @test gate(MockFlow.data, PolygonGate(channel_x="FSC_A", channel_y="SSC_A", points=edge_poly)).FSC_A == [2.0, 4.0, 5.0]
    # Ellipse bounds cannot be tested exactly due to numerical precision issues
    @test gate(MockFlow.data, EllipseGate(channel_x="FSC_A", channel_y="SSC_A", center=(3.0,300.0), points=[(1.9, 200.0), (4.0, 450.0), (3.0, 500.0)])).FSC_A == [2.0, 3.0, 4.0]
    @test gate(MockFlow.data, EllipseGate(channel_x="FSC_A", channel_y="SSC_A", points=[(1.9, 200.0), (4.0, 450.0), (3.0, 500.0), (2.5, 400.0), (2.5, 100.0)])).SSC_A == [200.0, 300.0]
    @test MockFlow.data == datacopy  # ensure original data is not modified

    # Test errors
    @test_throws "Quadrant must be between" gate(MockFlow.data, QuadrantGate(channel_x="FL1_A", channel_y="FL2_A", x_cutoff=535.0, y_cutoff=54.5, quadrant=5))
end

@testitem "event counting" setup = [MockFlow] begin
    println("event counting")
    @test event_count(MockFlow.data) == 5
    gated_data = gate(MockFlow.data, HighLowGate(channel="FL1_A", min=530.0))
    @test event_count(gated_data) == 3
    gated_data2 = gate(MockFlow.data, RectangleGate(channel_x="FSC_A", channel_y="SSC_A", x_min=2.0, x_max=4.5, y_min=50.0, y_max=301.0))
    @test event_count(gated_data2) == 2
end

@testitem "gated proportions" setup = [MockFlow] begin
    println("gated proportions")
    datacopy = deepcopy(MockFlow.data)
    gated_data = gate(MockFlow.data, HighLowGate(channel="FL1_A", min=530.0))
    @test gated_proportion(MockFlow.data, gated_data) == 3 / 5
    @test gated_proportion(MockFlow.data, HighLowGate(channel = "FL1_A", min = 530.0)) == 3 / 5
    gated_data2 = gate(MockFlow.data, RectangleGate(channel_x="FSC_A", channel_y="SSC_A", x_min=2.0, x_max=4.5, y_min=50.0, y_max=301.0))
    @test gated_proportion(MockFlow.data, gated_data2) == 2 / 5
    @test gated_proportion(MockFlow.data, RectangleGate(channel_x="FSC_A", channel_y="SSC_A", x_min=2.0, x_max=4.5, y_min=50.0, y_max=301.0)) == 2 / 5
    @test MockFlow.data == datacopy  # ensure original data is not modified
end

@testitem "autogating" setup = [MockFlow] begin
    println("autogating")
    datacopy = deepcopy(MockFlow.data)
    @test gate(MockFlow.data, KDE(channels = ["FSC_A", "SSC_A"])) ==
    gate(MockFlow.data, HighLowGate(channel="FSC_A", min=1.5, max=5.5))
    @test MockFlow.data == datacopy  # ensure original data is not modified
end

@testitem "logical gates" setup = [MockFlow] begin
    println("logical gates")
    datacopy = deepcopy(MockFlow.data)
    @test gate(MockFlow.data, HighLowGate(channel="FL1_A", min=525.0) & HighLowGate(channel="SSC_A", max=450.0)).id == [3, 4]
    @test gate(MockFlow.data, HighLowGate(channel="FL1_A", min=525.0, max=545.0) | HighLowGate(channel="SSC_A", max=150.0)).id == [1, 3, 4]
    @test gate(MockFlow.data, !HighLowGate(channel="FL1_A", min=525.0)).id == [1, 2]
    @test gate(MockFlow.data, and(HighLowGate(channel="FL1_A", min=525.0), HighLowGate(channel="SSC_A", max=450.0))).FL1_A == [530.0, 540.0]
    @test gate(MockFlow.data, or(HighLowGate(channel="FL1_A", min=525.0, max=545.0), HighLowGate(channel="SSC_A", max=150.0))).id == [1, 3, 4]
    @test gate(MockFlow.data, not(HighLowGate(channel="FL1_A", min=525.0))).id == [1, 2]
    @test gate(MockFlow.data, KDE(channels = ["FSC_A", "SSC_A"]) & HighLowGate(channel="FSC_A", max=3.5)).FL1_A == [520.0, 530.0]
    @test MockFlow.data == datacopy  # ensure original data is not modified
end

@testitem "MEF calibration" begin
    println("MEF calibration")
    using FCSFiles, FileIO, DataFrames
    data = load("inputs/beads.fcs")
    df = DataFrame("BL1-H" => data["BL1-H"], "BL1-A" => data["BL1-A"], "FSC-A" => data["FSC-A"], "SSC-A" => data["SSC-A"])
    df[!, "BL1-H.min"] .= 0.0
    df[!, "BL1-H.max"] .= 1e6
    df[!, "BL1-A.min"] .= 0.0
    df[!, "BL1-A.max"] .= 1e6
    df[!, "FSC-A.min"] .= 0.0
    df[!, "FSC-A.max"] .= 1e6
    df[!, "SSC-A.min"] .= 0.0
    df[!, "SSC-A.max"] .= 1e6
    df[!, "id"] .= 1:nrow(df)

    copy = deepcopy(df)

    # Density gate
    f = x -> log10.(1 .+ max.(0.0, x))
    gated = gate(df, KDE(channels = ["FSC-A", "SSC-A"], gate_frac = 0.4, transform_x = f, transform_y = f))
    gated = gate(gated, KDE(channels = ["BL1-H", "BL1-A"], gate_frac = 0.9, transform_x = f, transform_y = f))

    # MEF calibration
    method = MEF(beads = gated, channel="BL1-H", mef=[nothing, 789, 1896, 4872, 15619, 47116, 143912, 333068], nRepeats=1)
    dir = mktempdir()
    calibrated_df = calibrate(df, method; plot_directory = dir)
    @test all(calibrated_df[!, "BL1-H.min"] .== 0.0)
    @test all(calibrated_df[!, "BL1-H.max"] .> 0.0)
    @test all(calibrated_df[!, "BL1-H"] .>= 0.0)

    # Check plots are created
    @test isfile(joinpath(dir, "mef_calibration_fluorescence_data.png"))
    @test isfile(joinpath(dir, "mef_calibration_clusters.png"))
    @test isfile(joinpath(dir, "mef_calibration_standard_curve.png"))

    # Test that original data is not modified
    @test df == copy

    # Test that other columns are not modified
    @test df[!, "FSC-A"] == copy[!, "FSC-A"]
    @test df[!, "SSC-A"] == copy[!, "SSC-A"]
    @test df[!, "id"] == copy[!, "id"]
    @test df[!, "FSC-A.min"] == copy[!, "FSC-A.min"]
    @test df[!, "SSC-A.min"] == copy[!, "SSC-A.min"]
    @test df[!, "FSC-A.max"] == copy[!, "FSC-A.max"]
    @test df[!, "SSC-A.max"] == copy[!, "SSC-A.max"]

    # Test with temporary plot directory
    using Logging
    io = IOBuffer()
    logger = SimpleLogger(io)
    with_logger(logger) do
        calibrate(df, method; plot_directory = :temp)
    end
    str = String(take!(io))
    str = replace(str, "┌ Info: Plot directory for MEF calibration set to temporary directory: " => "")
    str = split(str, "\n")[1]
    @test isdir(str)
    @test isfile(joinpath(str, "mef_calibration_fluorescence_data.png"))
    @test isfile(joinpath(str, "mef_calibration_clusters.png"))
    @test isfile(joinpath(str, "mef_calibration_standard_curve.png"))

    # Check the calibration makes sense in the linear case - and skipping populations
    beads = DataFrame("BL1-H" => [8.0, 9.0, 10.0, 11.0, 12.0, 100.0, 105.0, 110.0, 115.0, 120.0, 1000.0, 1050.0, 1100.0, 1125.0, 1250.0, 100000.0, 100100.0, 100200.0, 100500.0])
    beads[!, "BL1-H.min"] .= 0.0
    beads[!, "BL1-H.max"] .= 1e6
    beads[!, "id"] .= 1:nrow(beads)

    method = MEF(beads = beads, channel="BL1-H", mef=[10.0, 110.0, 1100.0, nothing], nRepeats=1)
    calibrated_beads = calibrate(beads, method)
    @test calibrated_beads[!, "BL1-H"] ≈ beads[!, "BL1-H"] atol=0.1
    @test all(calibrated_beads[!, "BL1-H"] .>= 0.0)
    @test all(calibrated_beads[!, "BL1-H.min"] .== 0.0)
    @test all(calibrated_beads[!, "BL1-H.max"] .> 0.0)

    # Check calibration without clustering
    method = MEF(beads = beads, channel="BL1-H", mef=[10.0, 110.0, 1100.0], nInit=1, nIter=1, nRepeats=1)
    calibrated_beads = calibrate(beads, [10.0, 110.0, 1100.0], method)
    @test calibrated_beads[!, "BL1-H"] ≈ beads[!, "BL1-H"] atol=0.1
    @test all(calibrated_beads[!, "BL1-H"] .>= 0.0)
    @test all(calibrated_beads[!, "BL1-H.min"] .== 0.0)
    @test all(calibrated_beads[!, "BL1-H.max"] .> 0.0)
end
