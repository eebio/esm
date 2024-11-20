module eebiotools

using CSV, DataFrames, FileIO, JSON, Comonicon, FCSFiles, Parameters, JSONTables
include("./io/read.jl")
include("./base/main.jl")
export read_fcs, read_csv, read_metadata, asscMetadata,leave, main

end # module eebiotools
