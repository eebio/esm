@testitem "Aqua" begin
    println("Aqua")
    using Aqua
    Aqua.test_all(Longwing; persistent_tasks=false)
    # Covers for slow precomp for alpha builds of Julia
    #Aqua.test_persistent_tasks(Longwing; tmax = 60)
end
