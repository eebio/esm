@testitem "Aqua" begin
    println("Aqua")
    using Aqua
    Aqua.test_all(ESM; persistent_tasks = false)
    # Covers for slow precomp for alpha builds of Julia
    Aqua.test_persistent_tasks(ESM; tmax = 60)
end
