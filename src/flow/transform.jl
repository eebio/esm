using StatsBase
using NonlinearSolve
using NaNMath
using SciMLBase
import DataFrames: transform

abstract type AbstractTransformMethod <: AbstractESMMethod end

"""
    transform(data::DataFrame, method::AbstractTransformMethod)

Apply the specified transformation to `data`.

Arguments:
- `data::DataFrame`: A DataFrame of Flow cytometry data.
- `method::AbstractTransformMethod`: The method and settings to use for transformation.
"""
function transform(data::DataFrame, method::AbstractTransformMethod)
    data = deepcopy(data)
    for name in names(data)
        data[!, name] = method.forward.(data[!, name])
    end
    return data
end

"""
    untransform(data::DataFrame, method::AbstractTransformMethod)

Reverse a previously applied transformation on `data`.

Arguments:
- `data::DataFrame`: A DataFrame of Flow cytometry data.
- `method::AbstractTransformMethod`: The method and settings to use for transformation.
"""
function untransform(data::DataFrame, method::AbstractTransformMethod)
    data = deepcopy(data)
    for name in names(data)
        data[!, name] = method.backward.(data[!, name])
    end
    return data
end

struct Transform <: AbstractTransformMethod
    forward::Function
    backward::Function
end

"""
    Log10()

    Transforms data to base 10 logarithm scale.
"""
function Log10()
    return Transform(NaNMath.log10, x -> 10.0^x)
end

"""
    Log()

    Transforms data to natural (base e) logarithm scale.
"""
function Log()
    return Transform(NaNMath.log, x -> exp(x))
end

"""
    Log2()

    Transforms data to base 2 logarithm scale.
"""
function Log2()
    return Transform(NaNMath.log2, x -> 2.0^x)
end

"""
    Log1p()

    Transforms data to natural logarithm of (1 + x).
"""
function Log1p()
    return Transform(NaNMath.log1p, x -> exp(x) - 1)
end

"""
    Arcsinh()

    Transforms data to inverse hyperbolic sine scale.
"""
function Arcsinh()
    return Transform(asinh, sinh)
end

"""
    Linear(A, T)

    Transforms data to linear scale from the interval [-A, T] to [0, 1].
"""
function Linear(; A = 0, T = 262144)
    T > 0 || error("Linear transform: We require T > 0")
    0 <= A <= T || error("Linear transform: We require 0 <= A <= T")
    return Transform(x -> (x+A)/(T+A), x -> x * (T+A) - A)
end

"""
    Bound(; min = -Inf, max = Inf)

    Clamps data outside of the interval [min, max].

    When untransforming, values that were clamped to `min` are mapped to `-Inf` and values clamped to `max` are mapped to `Inf`.
"""
function Bound(; min=-Inf, max=Inf)
    min <= max || error("Bound transform: We require min <= max")
    function reverse(x)
        if x == min
            return -Inf
        elseif x == max
            return Inf
        else
            return x
        end
    end
    return Transform(x -> clamp(x, min, max), reverse)
end

"""
    Hyperlog(; W = 1.0, T = 262144, M = 4.5, A = 0)

Transforms data to hyperlog scale. The hyperlog transformation is a continuous, monotonic
    transformation that behaves like a logarithm for large values and like a linear function
    for small values. It is defined by the parameters W, T, M, and A.

The hyperlog function is defined by inverting the function:

    f(x) = a * exp(b * x) + c * x - f

where the parameters a, b, c, and f are computed from W, T, M, and A.

Arguments:
- `W`: The number of linear decades. Must be greater than 0 and less than or equal to M/2.
- `T`: The top of the scale. Must be greater than 0.
- `M`: The number of decades the logarithmic scale covers. Must be greater than 0.
- `A`: The additional negative decades. Must be greater than or equal to -W and less than or equal to M - 2*W.
"""
function Hyperlog(; W=1.0, T=262144, M=4.5, A=0)
    T > 0 || error("Hyperlog transform: We require T > 0")
    M > 0 || error("Hyperlog transform: We require M > 0")
    0 < W <= M/2 || error("Hyperlog transform: We require 0 < W <= M/2")
    -W <= A <= (M - 2*W) || error("Hyperlog transform: We require -W <= A <= (M - 2*W)")

    w = W / (M + A)
    x2 = A / (M + A)
    x1 = x2 + w
    x0 = x2 + 2 * w
    b = (M + A) * log(10)
    e0 = exp(b * x0)
    cbya = e0 / w
    fbya = exp(b * x1) + cbya * x1
    a = T / (exp(b) + cbya - fbya)
    c = cbya * a
    f = fbya * a
    return _Hyperlog(a, b, c, f)
end

function _Hyperlog(a,b,c,f)
    EH(x) = a * exp(b * x) + c * x - f
    root(x, _) = EH(x) - x
    prob = NonlinearProblem(root, 0.0)
    function inverse(x)
        prob = remake(prob; u0 = x)
        sol = NonlinearSolve.solve(prob, NonlinearSolve.NewtonRaphson(), verbose = false)
        if SciMLBase.successful_retcode(sol)
            return sol.u[1]
        else
            return NaN
        end
    end
    return Transform(inverse, EH)
end

#=

For the Logicle transformation, we have based the code on the MATLAB implementation by
Harley Day. This was itself based on:

"""
Moore WA, Parks DR. Update for the Logicle Data Scale Including Operational Code
Implementations. Cytometry Part A : the journal of the International Society for Analytical
Cytology. 2012;81(4):273-277. doi:10.1002/cyto.a.22030. Note that Moore and Parks' code is
no longer hosted at the link provided in the supplmentary material of this paper. It was
moved to this GitHub repository - https://github.com/black98fxstc/FACS/tree/master/CLogicle.
"""

The license used for the MATLAB code is included below.

BSD 3-Clause License

Copyright (c) 2018, Harley Day
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=#

"""
    Logicle(; W = 1.0, T = 262144, M = 4.5, A = 0)

The Logicle transformation is a continuous, monotonic transformation that behaves like a
    logarithm for large values and like a linear function for small values. It is defined by
    the parameters W, T, M, and A.

It is defined by inverting the function:

    f(x) = a * exp(b * x) + c * exp(-d * x) + f

where the parameters a, b, c, d, and f are computed from W, T, M, and A.

Arguments:
- `W`: The number of linear decades. Must be greater than or equal to 0
- `T`: The total range of the transformation. Must be greater than 0
- `M`: The number of decades to be compressed. Must be greater than 0
- `A`: The additional negative decades. Must be greater than or equal to -W and less than or equal to M - 2*W.
"""
function Logicle(; W = 1.0, T = 262144, M = 4.5, A = 0)
    T > 0 || error("Logicle transform: We require T > 0")
    M > 0 || error("Logicle transform: We require M > 0")
    0 <= W <= M/2 || error("Logicle transform: We require 0 <= W <= M/2")
    -W <= A <= (M - 2*W) || error("Logicle transform: We require -W <= A <= (M - 2*W)")

    # actual parameters formulas from biexponential paper
    w = W/(M+A)
    x2 = A/(M+A)
    x1 = x2 + w
    x0 = x2 + 2*w
    b = (M+A)*log(10)
    d = solve_RTSAFE(b, w)
    c_a = exp(x0*(b+d))
    mf_a = exp(b*x1) - c_a/exp(d*x1)
    a = T/((exp(b) - mf_a) - c_a/exp(d))
    c = c_a*a
    f = -mf_a*a

    d = solve_RTSAFE(b, w)

    ## use Taylor series near x1, i.e., data zero to avoid round off problems of formal definition
    xTaylor = x1 + w/4
    # compute coefficients of the Taylor series
    posCoef = a*exp(b*x1)
    negCoef = -c/exp(d*x1)
    # 16 is enough for full precision of typical scales
    taylor = zeros(16, 1)
    for p in 1:16
        posCoef = posCoef*b/p
        negCoef = -negCoef*d/p
        taylor[p] = posCoef + negCoef
    end
    taylor[2] = 0

    return Logicle(a, b, c, d, f, xTaylor, taylor, x1)
end

function Logicle(a, b, c, d, f, xTaylor, taylor, x1)
    function seriesBiexponential(scale)
        # Paraphrasing of c++ implementation by Wayne A. Moore found at
        # http://onlinelibrary.wiley.com/doi/10.1002/cyto.a.22030/full
        # Taylor series is around x1
        x = scale - x1
        # note that taylor(2) should be identically zero according
        # to the Logicle condition so skip it here
        sum = taylor[16]*x # TAYLOR_LENGTH = 16
        for i in 16:-1:3
            sum = (sum + taylor[i])*x
        end
        return (sum*x + taylor[1])*x
    end

    function numerically_invert(value)
        if (value == 0)
            return x1
        end
        # reflect negative values
        negative = value < 0
        if (negative)
            value = -value
        end
        # initial guess at solution
        if (value < f)
            # use linear approximation in the quasi linear region
            x = x1 + value/taylor[1]
        else
            # otherwise use ordinary logarithm
            x = log(value/a)/b
        end
        # try for precision unless in extended range
        tolerance = 3*eps()
        if (x > 1)
            tolerance = 3*eps(x)
        end
        for _ in 0:10
            # compute the function and its first two derivatives
            ae2bx = a*exp(b*x)
            ce2mdx = c/exp(d*x)
            if (x < xTaylor)
                # near zero use the Taylor series
                y = seriesBiexponential(x) - value
            else
                # this formulation has better roundoff behavior
                y = ae2bx - ce2mdx + f - value
            end
            abe2bx = b*ae2bx
            cde2mdx = d*ce2mdx
            dy = abe2bx + cde2mdx
            ddy = b*abe2bx - d*cde2mdx

            # this is Halley's method with cubic convergence
            delta = y/(dy*(1 - y*ddy/(2*dy^2)))
            x = x - delta

            # if we've reached the desired precision we're done
            if (abs(delta)<tolerance)
                break
            end
        end
        # handle negative arguments
        if (negative)
            return 2*x1 - x
        else
            return x
        end
    end

    function inverse(x)
        negative = x < x1
        if (negative)
            x = 2*x1 - x
        end
        # compute the biexponential
        if (x < xTaylor)
            # near x1, i.e., data zero use the series expansion
            inverse = seriesBiexponential(x)
        else
            # this formulation has better roundoff behavior
            inverse = a*exp(b*x) + f - c/exp(d*x)
        end
        # handle scale for negative values
        if (negative)
            inverse = -inverse
        end
        return inverse
    end

    return Transform(inverse, numerically_invert)
end

function solve_RTSAFE(b, w)
    # Paraphrasing of c++ implementation by Wayne A. Moore
    # found at
    # http://onlinelibrary.wiley.com/doi/10.1002/cyto.a.22030/full
    # w == 0 means its really arcsinh
    if (w==0)
        d = b
        return d
    else
        # Precision is the same as that of b
        tolerance = 2*eps(b)
        # Based on RTSAFE from Numerical Recepies 1st Edition
        # Bracket the root
        d_lo = 0
        d_hi = b
        # Bisection first step
        d = (d_lo+d_hi)/2
        last_delta = d_hi - d_lo
        # evaluate the f(w,b) = 2 * (ln(d) - ln(b)) + w * (b +
        # d) and its derrivative
        f_b = -2*log(b) + w*b
        f = 2*log(d) + w*d + f_b
        last_f = NaN # storage of last value of f
        for itratn in 1:20
            df = 2/d + w
            # if Newton's method would step outside the bracke
            # or if it isn't converging quickly enough
            if (((d - d_hi) * df - f) * ((d - d_lo) * df - f) >= 0 ||
                abs(1.9 * f) > abs(last_delta * df))
                # take a bisection step
                delta = (d_hi - d_lo)/2
                d = d_lo + delta
                if (d==d_lo)
                    return d # nothing changed, we're done
                end
            else
                # otherwise take a Newton's method step
                delta = f/df
                t = d
                d = d - delta
                if (d == t)
                    return d # nothing changed, we're done
                end
            end
            # if we've reached the desired precision we're done
            if (abs(delta)<tolerance)
                return d
            end
            last_delta = delta
            # recompute the function
            f = 2 * log(d) + w * d + f_b
            if (f == 0 || f == last_f)
                return d # found the root or are not going to get any closer
            end
            last_f = f
            # update the bracketing interval
            if (f < 0)
                d_lo = d
            else
                d_hi = d
            end
        end
        error("exceeded maximum iterations in solve()")
    end
end
