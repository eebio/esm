struct FlowCytometryData <: AbstractLongwingDataType end

include("read.jl")
include("transform.jl")
include("gate.jl")
include("mef.jl")
