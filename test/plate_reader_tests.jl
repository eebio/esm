@testitem "read spectramax" setup=[environment_path] begin
    println("read spectramax")
    data = read_data("inputs/spectramax.xlsx")
    @test data[:samples]["plate_01_a1"][:values]["abs700"][[1, 2, end - 1, end]] ==
          [0.1493, 0.1623, 0.3297, 0.3629]
    @test data[:samples]["plate_01_e12"][:values]["abs600"][[1, 2, end - 1, end]] == [
        0.0764, 0.1030, 0.4580, 0.5212]
    wells1 = [string("plate_01_", row, col) for row in 'a':'e', col in 1:12] # Only A-E have data
    wells2 = [string("plate_02_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells1..., wells2..., "plate_01_time", "plate_01_temperature", "plate_02_time", "plate_02_temperature"]  # Flatten to a 1D vector
    @test issetequal(keys(data[:samples]), wells)

    @test issetequal(keys(read("inputs/spectramax-data.txt", SpectraMax(); channels=["600", "700"])), ["600", "700"])
    @test issetequal(
        keys(read("inputs/spectramax-data2.txt", SpectraMax(); channels = ["530_485_1", "530_485_2", "530_485_3"])),
        ["530_485_1", "530_485_2", "530_485_3"])
end

@testitem "read biotek" setup=[environment_path] begin
    println("read biotek")
    data = read_data("inputs/biotek.xlsx")
    @test data[:samples]["plate_01_a1"][:values]["od1"][[1, 2, end - 1, end]] ==
          [0.134, 0.133, 0.131, 0.131]
    @test data[:samples]["plate_01_h12"][:values]["od2"][[1, 2, end - 1, end]] == [
        0.114, 0.113, 0.577, 0.578]
    @test data[:samples]["plate_01_a2"][:values]["flu2"][[1, 2, end - 1, end]] == [
        166, 162, 1030, 1024]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_temperature", "plate_01_time"]  # Flatten to a 1D vector
    @test issetequal(wells, keys(data[:samples]))

    @test issetequal(keys(read(
        "inputs/biotek-data.csv", BioTek(); channels = ["OD_600"])), ["OD_600"])
end

@testitem "read tecan" setup=[environment_path] begin
    println("read tecan")
    data = read_data("inputs/tecan.xlsx")
    @test issetequal(keys(data[:samples]["plate_01_a1"][:values]), ["OD_600", "OD_700", "GFP"])
    @test data[:samples]["plate_01_a1"][:values]["OD_600"][[1, 2, end - 1, end]] ==
          convert.(Float32, [0.1378, 0.1437, 0.1451, 0.1453])
    @test data[:samples]["plate_01_h12"][:values]["GFP"][[1, 2, end - 1, end]] == [
        68, 70, 84, 84]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_temperature", "plate_01_time"]
    @test issetequal(keys(data[:samples]), wells)

    @test data[:samples]["plate_01_time"][:values]["OD_600"][[1, 2, end-1, end]] ==
          [0, 765900, 56622900, 57388100]

    @test issetequal(keys(read(
        "inputs/tecan-data.xlsx", Tecan(); channels = ["OD_600", "GFP"])), ["OD_600", "GFP"])
end

@testitem "read plate reader directories" setup=[environment_path] begin
    println("read plate reader directories")
    using Dates

    data = read_data("inputs/example.xlsx")
    @test data[:samples]["plate_01_time"][:values]["OD"][1:2] ==
          [518000, 1118000]
    @test data[:samples]["plate_01_time"][:values]["OD"][end] == 67118000
    @test data[:samples]["plate_01_a1"][:values]["OD"][1:3] == [0.165, 0.167, 0.169]
    @test data[:samples]["plate_01_h12"][:values]["OD"][end] == 0.148

    @test data[:samples]["plate_01_time"][:values]["flo"][1:2] == [544714, 1144314]
    @test data[:samples]["plate_01_time"][:values]["flo"][end] == 67144719
    @test data[:samples]["plate_01_a1"][:values]["flo"][1:3] == [21, 22, 20]
    @test data[:samples]["plate_01_h12"][:values]["flo"][end] == 7

    @test issetequal(keys(read(
        "inputs/pr_folder", GenericTabular(); channels = ["OD"])), ["OD"])
end

@testitem "read pr errors" begin
    @test_throws "Unknown plate reader type: random_string" ESM.read_multipr_file("anyfile/path", "random_string", ["OD"], Dict())
end

# Test doubling_time
@testitem "doubling_time" begin
    println("doubling_time")
    using DataFrames

    od_df = DataFrame(A = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8, 25.6, 51.2])
    time_col = DataFrame(Time = 0:60000:600000)

    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3, method = :Endpoints)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, MovingWindow(window_size = 3, method = :LinearOnLog)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, LinearOnLog(start_time = 1, end_time = 5)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, Endpoints(start_time = 1, end_time = 5)) ≈
          DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, FiniteDiff()) ≈ DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, FiniteDiff(type=:onesided)) ≈ DataFrame(A = 1.0)
    @test doubling_time(od_df, time_col, Regularization(order=4.0)) ≈
          DataFrame(A = 1.0)

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => 0:10000:600000)
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(time_col ./ 60000)
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
    time_col = DataFrame(Time = 0:60000:600000)

    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3, method = :Endpoints))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size = 3, method = :LinearOnLog))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, LinearOnLog(start_time = 1, end_time = 5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, Endpoints(start_time = 1, end_time = 5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, Regularization())[1, "A"] ≈ log(2)

    # Tests for warnings
    od_df_warn = DataFrame(A = [0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    @test_warn "Not enough data points" growth_rate(od_df_warn, time_col, FiniteDiff())
    @test_warn "Not enough data points" growth_rate(od_df_warn, time_col, LinearOnLog(start_time = 1.1, end_time = 1.2))
    @test_warn "Not enough data points" growth_rate(od_df_warn, time_col, Regularization())
    @test_warn "Not enough data points" growth_rate(od_df_warn, time_col, Logistic())
    @test_warn "No data points found between start_time" growth_rate(od_df, time_col, LinearOnLog(start_time = -2, end_time = -1))

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" growth_rate(od_df, time_col, FiniteDiff(type=:unknown))
    @test_throws "Unknown moving window method: unknown." growth_rate(od_df, time_col, MovingWindow(method=:unknown))

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => 0:10000:600000)
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(time_col ./ 60000)
    rename!(od_df, :Time => :A)

    # Check that the actual growth rate is around 0.35
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"]≈0.35 atol=1e-2

    # Test the parametric methods
    @test growth_rate(od_df, time_col, Logistic())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, Gompertz())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, ModifiedGompertz())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, Richards())[1, "A"]≈0.35 atol=1e-2
end

@testitem "time to max growth" begin
    println("time to max growth")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796, -0.4244814803886498, -0.18088313464643485, -0.5045323424725897, -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424, 1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343, 0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681, -0.15644528491336934, 0.22969924085412563, -1.7463816740617624, -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678, -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734, -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392, -0.11071786613263836, -0.022308315590345632, -2.023482208299797, -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A = od)
    using Dates
    time_col = DataFrame(Time = t*60000)

    @test 7 < time_to_max_growth(od_df, time_col, MovingWindow(window_size=5))[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, LinearOnLog(start_time=6, end_time=9))[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Endpoints(start_time=6, end_time=9))[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, FiniteDiff())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Regularization())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Logistic())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Gompertz())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, ModifiedGompertz())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Richards())[1, "A"] < 10

    # Tests for warnings
    od_df_warn = DataFrame(A = [
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_warn "Not enough data points" time_to_max_growth(od_df_warn, time_col_warn, FiniteDiff())
    @test_warn "Not enough data points" time_to_max_growth(
        od_df_warn, time_col_warn, LinearOnLog(start_time = 1, end_time = 1.5))
    @test_warn "Not enough data points" time_to_max_growth(od_df_warn, time_col_warn, Regularization())

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" time_to_max_growth(
        od_df, time_col, FiniteDiff(type = :unknown))
end

@testitem "lag time" begin
    println("lag time")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796, -0.4244814803886498, -0.18088313464643485, -0.5045323424725897, -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424, 1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343, 0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681, -0.15644528491336934, 0.22969924085412563, -1.7463816740617624, -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678, -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734, -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392, -0.11071786613263836, -0.022308315590345632, -2.023482208299797, -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A = od)
    using Dates
    time_col = DataFrame(Time = t*60000)

    @test 5 < lag_time(od_df, time_col, MovingWindow(window_size=5))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, LinearOnLog(start_time=7, end_time=10))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Endpoints(start_time=7, end_time=10))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, FiniteDiff())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Regularization())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Logistic())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Gompertz())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, ModifiedGompertz())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Richards())[1, "A"] < 8

    # Tests for warnings
    od_df_warn = DataFrame(A = [
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_warn "Not enough data points" lag_time(od_df_warn, time_col_warn, FiniteDiff())
    @test_warn "Not enough data points" lag_time(
        od_df_warn, time_col_warn, LinearOnLog(start_time = 1, end_time = 1.5))
    @test_warn "Not enough data points" lag_time(od_df_warn, time_col_warn, Regularization())

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" lag_time(
        od_df, time_col, FiniteDiff(type = :unknown))
end

@testitem "od at max growth" begin
    println("od at max growth")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796, -0.4244814803886498, -0.18088313464643485, -0.5045323424725897, -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424, 1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343, 0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681, -0.15644528491336934, 0.22969924085412563, -1.7463816740617624, -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678, -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734, -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392, -0.11071786613263836, -0.022308315590345632, -2.023482208299797, -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A = od)
    using Dates
    time_col = DataFrame(Time = t*60000)

    @test 0 < od_at_max_growth(od_df, time_col, MovingWindow(window_size=5))[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, LinearOnLog(start_time=7, end_time=10))[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Endpoints(start_time=7, end_time=10))[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, FiniteDiff())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Regularization())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Logistic())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Gompertz())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, ModifiedGompertz())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Richards())[1, "A"] < f(10)

    # Tests for warnings
    od_df_warn = DataFrame(A = [
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_warn "Not enough data points" od_at_max_growth(od_df_warn, time_col_warn, FiniteDiff())
    @test_warn "Not enough data points" od_at_max_growth(
        od_df_warn, time_col_warn, LinearOnLog(start_time = 1, end_time = 1.5))
    @test_warn "Not enough data points" od_at_max_growth(od_df_warn, time_col_warn, Regularization())

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" od_at_max_growth(
        od_df, time_col, FiniteDiff(type = :unknown))
end

@testitem "max od" begin
    println("max od")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796, -0.4244814803886498, -0.18088313464643485, -0.5045323424725897, -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424, 1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343, 0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681, -0.15644528491336934, 0.22969924085412563, -1.7463816740617624, -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678, -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734, -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392, -0.11071786613263836, -0.022308315590345632, -2.023482208299797, -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A = od)
    using Dates
    time_col = DataFrame(Time = t*60000)

    @test 0.95 < max_od(od_df, time_col, MovingWindow(window_size=5))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, LinearOnLog(start_time=7, end_time=10))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Endpoints(start_time=7, end_time=10))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, FiniteDiff())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Regularization())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Logistic())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Gompertz())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, ModifiedGompertz())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Richards())[1, "A"] < 1.05

    # Tests for warnings
    od_df_warn = DataFrame(A = [
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_warn "Not enough data points" max_od(od_df_warn, time_col_warn, FiniteDiff())
    @test_warn "Not enough data points" max_od(
        od_df_warn, time_col_warn, LinearOnLog(start_time = 1, end_time = 1.5))
    @test_warn "Not enough data points" max_od(od_df_warn, time_col_warn, Regularization())

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" max_od(
        od_df, time_col, FiniteDiff(type = :unknown))
end

@testitem "calibrate" begin
    println("calibrate")
    using DataFrames

    data = DataFrame(A = [0.5, 0.65, 0.79, 0.83, 0.95], B = [1.11, 1.05, 1.23, 1.36, 1.44])
    time_col = DataFrame(Time = 0:60000:600000)
    datacopy = deepcopy(data)
    blanks = DataFrame(C = [0.1, 0.15, 0.2, 0.17, 0.08], D = [0.21, 0.26, 0.22, 0.23, 0.2])

    @test calibrate(data, time_col, TimeseriesBlank(blanks = blanks)) ≈
          DataFrame(A = [0.5 - 0.155, 0.65 - 0.205, 0.79 - 0.21, 0.83 - 0.2, 0.95 - 0.14],
        B = [1.11 - 0.155, 1.05 - 0.205, 1.23 - 0.21, 1.36 - 0.2, 1.44 - 0.14])
    @test data == datacopy # Check mutation free
    new_blanks = DataFrame(C = [0.12, 0.14, 0.19], D = [0.22, 0.25, 0.21])
    new_blanks_copy = deepcopy(new_blanks)
    blank_time_col = DataFrame(Time = [
        30000, 150000, 210000])
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

@testitem "fluorescence per cell" setup=[environment_path] begin
    println("fluorescence per cell")
    es = read_data("inputs/biotek.xlsx")
    filename = joinpath(Base.Filesystem.mktempdir(), "tmp.esm")
    write_esm(es, filename)
    es = read_esm(filename)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))

    # Single sample with no calibration
    od = eval(ESM.sexp_to_nested_list(:(plate_01_a2.od1), es, trans_meta_map))
    fl = eval(ESM.sexp_to_nested_list(:(plate_01_a2.flu1), es, trans_meta_map))
    time_od = eval(ESM.sexp_to_nested_list(:(plate_01_time.od1), es, trans_meta_map))
    time_fl = eval(ESM.sexp_to_nested_list(:(plate_01_time.flu1), es, trans_meta_map))

    # Doesn't include any calibration (od or flu) so numbers are kind of meaningless
    @test floor(fluorescence(fl, time_fl, od, time_od, RatioAtTime(4*60))[1,1]) == 5455
    @test floor(fluorescence(fl, time_fl, od, time_od, RatioAtMaxGrowth(method=FiniteDiff(type=:central)))[1,1]) == 4069

    # Including calibration and groups
    od = eval(ESM.sexp_to_nested_list(:(plate1.od1), es, trans_meta_map))
    fl = eval(ESM.sexp_to_nested_list(:(plate1.flu1), es, trans_meta_map))
    time_od = eval(ESM.sexp_to_nested_list(:(plate_01_time.od1), es, trans_meta_map))
    time_fl = eval(ESM.sexp_to_nested_list(:(plate_01_time.flu1), es, trans_meta_map))
    od = calibrate(od, time_od, StartZero())
    fl = calibrate(fl, time_fl, StartZero())
    @test floor(fluorescence(fl, time_fl, od, time_od, RatioAtTime(4*60))[1, "plate_01_b6"]) == 102
    @test floor(fluorescence(fl, time_fl, od, time_od, RatioAtMaxGrowth(method=FiniteDiff()))[1, "plate_01_a10"]) == -584
end
