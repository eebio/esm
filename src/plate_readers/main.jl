abstract type AbstractPlateReaderMethod <: AbstractESMMethod end

abstract type AbstractPlateReader <: AbstractESMDataType end

include("read.jl")
include("calibrate.jl")
include("growth_rate.jl")
include("fluorescence.jl")
