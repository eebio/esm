module eebiotools

using CSV, DataFrames, FileIO, JSON, Comonicon, FCSFiles, Parameters, JSONTables, XLSX
include("./io/read.jl")
include("./base/main.jl")
export read_fcs, read_csv, read_metadata, asscMetadata,leave, main, read_excel, write_conv

end # module eebiotools
