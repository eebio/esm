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
    gate(MockFlow.data, HighLowGate(channel="FSC_A", min=1.5, max=4.5))
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
