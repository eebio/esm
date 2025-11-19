@testmodule MockFlow begin
    println("MockFlow")
    # Example output from to_rfi
    data = Dict(
        "FSC-A" => Dict(:max => 1e5, :min => 0.0, :data => [1.0, 2.0, 3.0, 4.0, 5.0]),
        "SSC-A" => Dict(:max => 1e5, :min => 0.0, :data => [100.0, 200.0, 300.0, 400.0, 500.0]),
        "FL1-A" => Dict(:max => 1e5, :min => 0.0, :data => [510.0, 520.0, 530.0, 540.0, 550.0]),
        "FL2-A" => Dict(:max => 1e5, :min => 0.0, :data => [51.0, 52.0, 53.0, 54.0, 55.0]),
    )
end

@testitem "manual gating" setup = [MockFlow] begin
    # TODO add tests for other gating constructors
    datacopy = deepcopy(MockFlow.data)
    @test gate(MockFlow.data, HighLowGate(channel="FL1-A", min=515.0))["FL1-A"][:data] == [520.0, 530.0, 540.0, 550.0]
    @test gate(MockFlow.data, HighLowGate(channel="SSC-A", max=301.0))["SSC-A"][:data] == [100.0, 200.0, 300.0]
    @test gate(MockFlow.data, HighLowGate(channel="FSC-A", min=2.0, max=4.0))["FL1-A"][:data] == [520.0, 530.0] # upper bounds are exclusive, lower bounds inclusive
    @test gate(MockFlow.data, HighLowGate(channel="FSC-A"))["FL2-A"][:data] == [51.0, 52.0, 53.0, 54.0, 55.0]
    @test gate(MockFlow.data, RectangleGate(channel_x="FSC-A", channel_y="SSC-A", x_min=2.0, x_max=4.5, y_min=50.0, y_max=301.0))["FSC-A"][:data] == [2.0, 3.0]
    @test gate(MockFlow.data, RectangleGate(channel_x="FL1-A", channel_y="FL2-A", x_min=0.0, x_max=545.0, y_min=52.0, y_max=54.0))["SSC-A"][:data] == [200.0, 300.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1-A", channel_y="FL2-A", x_cutoff=535.0, y_cutoff=54.5, quadrant=1))["FL1-A"][:data] == [550.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1-A", channel_y="FL2-A", x_cutoff=535.0, y_cutoff=54.5, quadrant=2))["FL1-A"][:data] == [540.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1-A", channel_y="FL2-A", x_cutoff=535.0, y_cutoff=54.5, quadrant=3))["SSC-A"][:data] == [100.0, 200.0, 300.0]
    @test gate(MockFlow.data, QuadrantGate(channel_x="FL1-A", channel_y="FL2-A", x_cutoff=535.0, y_cutoff=54.5, quadrant=4))["FL1-A"][:data] == []
    @test MockFlow.data == datacopy  # ensure original data is not modified
end

@testitem "event counting" setup = [MockFlow] begin
    @test event_count(MockFlow.data) == 5
    gated_data = gate(MockFlow.data, HighLowGate(channel="FL1-A", min=530.0))
    @test event_count(gated_data) == 3
    gated_data2 = gate(MockFlow.data, RectangleGate(channel_x="FSC-A", channel_y="SSC-A", x_min=2.0, x_max=4.5, y_min=50.0, y_max=301.0))
    @test event_count(gated_data2) == 2
    MockFlow.data["FL1-A"][:data] = [1.0, 2.0]
    @test_throws ErrorException event_count(MockFlow.data)
    MockFlow.data["FL1-A"][:data] = [510.0, 520.0, 530.0, 540.0, 550.0]
    MockFlow.data["FSC-A"][:data] = [100.0, 200.0, 300.0]
    @test_throws ErrorException event_count(MockFlow.data)
    MockFlow.data["FSC-A"][:data] = [1.0, 2.0, 3.0, 4.0, 5.0]
    @test event_count(MockFlow.data) == 5
end

@testitem "autogating" setup = [MockFlow] begin
    datacopy = deepcopy(MockFlow.data)
    @test gate(MockFlow.data, KDE(channels = ["FSC-A", "SSC-A"])) ==
    gate(MockFlow.data, HighLowGate(channel="FSC-A", min=1.5, max=4.5))
    @test MockFlow.data == datacopy  # ensure original data is not modified
end
