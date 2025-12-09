@testitem "read spectramax" setup=[environment_path] begin
    println("read spectramax")
    data = read_data("inputs/spectramax.xlsx")
    # TODO should probably separate the channels into 600 and 700?
    # TODO channel is currently 535 for fluorescence but the 485 is also relevant
    @test data[:samples]["plate_01_a1"][:values]["abs"][[1, 2, end - 1, end]] ==
          [0.1493, 0.1623, 0.3297, 0.3629]
    @test data[:samples]["plate_01_e12"][:values]["abs"][[1, 2, end - 1, end]] == [
        0.0776, 0.0772, 0.2173, 0.2359]
    wells = [string("plate_01_", row, col) for row in 'a':'e', col in 1:12] # Only A-E have data
    wells = [wells..., "plate_01_time", "plate_01_temperature"]  # Flatten to a 1D vector
    @test issetequal(keys(data[:samples]), wells)

    @test all(keys(read("inputs/spectramax-data.txt", SpectraMax(); channels=["600 700"])) .== ["600 700"])
end

@testitem "read biotek" setup=[environment_path] begin
    println("read biotek")
    data = read_data("inputs/biotek.xlsx")
    @test data[:samples]["plate_01_a1"][:values]["od1"][[1, 2, end - 1, end]] ==
          [0.134, 0.133, 0.131, 0.131]
    @test data[:samples]["plate_01_h12"][:values]["od2"][[1, 2, end - 1, end]] == [
        0.114, 0.113, 0.577, 0.578]
    @test data[:samples]["plate_01_a2"][:values]["485,530[2]"][[1, 2, end - 1, end]] == [
        166, 162, 1030, 1024]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_temperature", "plate_01_time"]  # Flatten to a 1D vector
    @test issetequal(wells, keys(data[:samples]))

    @test all(keys(read(
        "inputs/biotek-data.csv", BioTek(); channels = ["600"])) .==
              ["600"])
end

@testitem "read plate reader directories" setup=[environment_path] begin
    println("read plate reader directories")
    using Dates

    data = read_data("inputs/example.xlsx")
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

    @test all(keys(read(
        "inputs/pr_folder", GenericTabular(); channels = ["OD"])) .==
              ["OD"])
end

@testitem "read pr errors" begin
    @test_throws "Unknown plate reader type: random_string" ESM.read_multipr_file("anyfile/path", "random_string", ["OD"], Dict())
end

# Test doubling_time
@testitem "doubling_time" begin
    println("doubling_time")
    using DataFrames

    od_df = DataFrame(A = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8, 25.6, 51.2])
    time_col = DataFrame(Time = [
        "00:00:00", "00:01:00", "00:02:00", "00:03:00", "00:04:00", "00:05:00", "00:06:00",
        "00:07:00", "00:08:00", "00:09:00", "00:10:00"])

    # TODO: Add some more tests with more awkward data
    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3, method = :Endpoints)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3, method = :LinearOnLog)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3, method = :ExpOnLinear)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, LinearOnLog(start_time = 1, end_time = 5)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, ExpOnLinear(start_time = 1, end_time = 5)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, Endpoints(start_time = 1, end_time = 5)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, FiniteDiff()) ≈ DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, FiniteDiff(type=:onesided)) ≈ DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, Regularization(order=4.0)) ≈
          DataFrame(A = 1.0)

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => [string(Time(0, 0, 0) + Second(10) * i) for i in 0:60])
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(ESM.df2time(time_col) ./ 60)
    rename!(od_df, :Time => :A)

    # Check that the actual doubling time is around 1.95
    @test doubling_time(od_df, time_col, FiniteDiff())[1, "A"]≈1.95 atol=0.1

    # Test the parametric methods
    @test doubling_time(od_df, time_col, Logistic())[1, "A"]≈1.95 atol=0.1
    @test doubling_time(od_df, time_col, Gompertz())[1, "A"]≈1.95 atol=0.1
    @test doubling_time(od_df, time_col, ModifiedGompertz())[1, "A"]≈1.95 atol=0.1
    @test doubling_time(od_df, time_col, Richards())[1, "A"]≈1.95 atol=0.1
end

@testitem "growth_rate" begin
    println("growth_rate")
    using DataFrames
    # TODO add tests with more columns and more awkward data
    od_df = DataFrame(A = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8, 25.6, 51.2])
    time_col = DataFrame(Time = [
        "00:00:00", "00:01:00", "00:02:00", "00:03:00", "00:04:00", "00:05:00", "00:06:00",
        "00:07:00", "00:08:00", "00:09:00", "00:10:00"])

    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3, method = :Endpoints))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3, method = :LinearOnLog))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3, method = :ExpOnLinear))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, LinearOnLog(start_time = 1, end_time = 5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, ExpOnLinear(start_time = 1, end_time = 5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, Endpoints(start_time = 1, end_time = 5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, Regularization())[1, "A"] ≈ log(2)

    # Tests for warnings
    od_df_warn = DataFrame(A = [0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    @test_warn "Not enough time points" growth_rate(od_df_warn, time_col, FiniteDiff())
    @test_warn "Not enough data points" growth_rate(od_df, time_col, LinearOnLog(start_time = 1, end_time = 1.5))
    @test_warn "Not enough data points" growth_rate(od_df, time_col, ExpOnLinear(start_time = 1, end_time = 1.5))
    @test_warn "Not enough time points" growth_rate(od_df_warn, time_col, Regularization())

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" growth_rate(od_df, time_col, FiniteDiff(type=:unknown))

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => [string(Time(0, 0, 0) + Second(10) * i) for i in 0:60])
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(ESM.df2time(time_col)./60)
    rename!(od_df, :Time => :A)

    # Check that the actual growth rate is around 0.35
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"]≈0.35 atol=1e-2

    # Test the parametric methods
    @test growth_rate(od_df, time_col, Logistic())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, Gompertz())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, ModifiedGompertz())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, Richards())[1, "A"]≈0.35 atol=1e-2
end

@testitem "calibrate" begin
    println("calibrate")
    using DataFrames

    data = DataFrame(A = [0.5, 0.65, 0.79, 0.83, 0.95], B = [1.11, 1.05, 1.23, 1.36, 1.44])
    time_col = DataFrame(Time = [
        "00:00:00", "00:10:00", "00:20:00", "00:30:00", "00:40:00"])
    datacopy = deepcopy(data)
    blanks = DataFrame(C = [0.1, 0.15, 0.2, 0.17, 0.08], D = [0.21, 0.26, 0.22, 0.23, 0.2])

    @test calibrate(data, time_col, TimeseriesBlank(blanks = blanks)) ≈
          DataFrame(A = [0.5 - 0.155, 0.65 - 0.205, 0.79 - 0.21, 0.83 - 0.2, 0.95 - 0.14],
        B = [1.11 - 0.155, 1.05 - 0.205, 1.23 - 0.21, 1.36 - 0.2, 1.44 - 0.14])
    @test data == datacopy # Check mutation free
    new_blanks = DataFrame(C = [0.12, 0.14, 0.19], D = [0.22, 0.25, 0.21])
    new_blanks_copy = deepcopy(new_blanks)
    blank_time_col = DataFrame(Time = [
        "00:05:00", "00:25:00", "00:35:00"])
    @test calibrate(data, time_col,
        TimeseriesBlank(blanks = new_blanks, time_col = blank_time_col)) ≈
          DataFrame(A = [0.5 - 0.17, 0.65 - (0.75*0.17+0.25*0.195), 0.79 - (0.25*0.17+0.75*0.195), 0.83 - (0.5*0.195+0.5*0.20), 0.95 - 0.20],
        B = [1.11 - 0.17, 1.05 - (0.75*0.17+0.25*0.195), 1.23 - (0.25*0.17+0.75*0.195), 1.36 - (0.5*0.195+0.5*0.20), 1.44 - 0.20])
    @test data == datacopy
    @test new_blanks == new_blanks_copy

    tmp = calibrate(data, time_col, SmoothedTimeseriesBlank(blanks = blanks))
    @test all(all.(eachcol(tmp .< data)))
    diffs = diff.(eachcol(tmp.-data))
    @test all(all.([d .≈ diffs[1][1] for d in diffs]))
    @test data == datacopy

    tmp = calibrate(data, time_col, SmoothedTimeseriesBlank(blanks = new_blanks, time_col = blank_time_col))
    @test all(all.(eachcol(tmp .< data)))
    diffs = diff.(eachcol(tmp .- data))
    @test all(all.([d .≈ diffs[1][1] for d in diffs]))
    @test data == datacopy
    @test new_blanks == new_blanks_copy

    @test calibrate(data, time_col, MeanBlank(blanks = blanks)) ==
          DataFrame(
        A = [0.5 - 0.182, 0.65 - 0.182, 0.79 - 0.182, 0.83 - 0.182, 0.95 - 0.182],
        B = [1.11 - 0.182, 1.05 - 0.182, 1.23 - 0.182, 1.36 - 0.182, 1.44 - 0.182])
    @test data == datacopy
    @test calibrate(data, time_col, MinBlank(blanks = blanks)) ==
          DataFrame(A = [0.5 - 0.08, 0.65 - 0.08, 0.79 - 0.08, 0.83 - 0.08, 0.95 - 0.08],
        B = [1.11 - 0.08, 1.05 - 0.08, 1.23 - 0.08, 1.36 - 0.08, 1.44 - 0.08])
    @test data == datacopy
    @test calibrate(data, time_col, MinData()) ==
          DataFrame(A = [0.5 - 0.5, 0.65 - 0.5, 0.79 - 0.5, 0.83 - 0.5, 0.95 - 0.5],
        B = [1.11 - 1.05, 1.05 - 1.05, 1.23 - 1.05, 1.36 - 1.05, 1.44 - 1.05])
    @test data == datacopy
    @test calibrate(data, time_col, StartZero()) ==
          DataFrame(A = [0.5 - 0.5, 0.65 - 0.5, 0.79 - 0.5, 0.83 - 0.5, 0.95 - 0.5],
        B = [1.11 - 1.11, 1.05 - 1.11, 1.23 - 1.11, 1.36 - 1.11, 1.44 - 1.11])
    @test data == datacopy
end
