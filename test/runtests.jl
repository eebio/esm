using Test
using eebiotools


@testset "Example tests" begin

    @testset "Read tests" begin
        include("read_tests.jl")
    end

    @testset "Write tests" begin
        include("write_tests.jl")
    end

    @testset "Integration tests" begin
        include("integration_tests.jl")
    end
end
