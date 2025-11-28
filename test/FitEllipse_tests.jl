"""
MIT License

Copyright (c) 2022 George Datseris <datseris.george@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

@testitem "FitEllipse.jl" begin
    function test_fit_ellipse(;
            θ = π / 3, a = 3, b = 1.5, x_0 = 3, y_0 = -1,
            N = 10000, ε = 1e-1, ξ = 0.001
    )
        @assert a > b
        x, y = ESM.ellipse_from_parametric(a, b, θ, x_0, y_0, N)
        # add noise
        xξ = x .+ randn(N) * ξ
        yξ = y .+ randn(N) * ξ

        af, bf, _, x_0f, y_0f, _ = ESM.fit_ellipse(xξ, yξ)

        if bf > af
            af, bf = bf, af
        end

        @test isapprox(af, a; atol = ε, rtol = ε)
        @test isapprox(bf, b; atol = ε, rtol = ε)
        @test isapprox(x_0f, x_0; atol = ε, rtol = ε)
        @test isapprox(y_0f, y_0; atol = ε, rtol = ε)
    end

    test_fit_ellipse()
    test_fit_ellipse(; a = 2.0)
    test_fit_ellipse(; θ = 0)
    test_fit_ellipse(; θ = π / 2, ξ = 0.1, ε = 0.1)
    test_fit_ellipse(; θ = 5π / 6)
end
