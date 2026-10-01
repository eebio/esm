abstract type AbstractPlateReaderMethod <: AbstractLongwingMethod end

abstract type AbstractPlateReader <: AbstractLongwingDataType end

include("read.jl")
include("calibrate.jl")
include("growth_rate.jl")
include("fluorescence.jl")
include("smoothing.jl")
