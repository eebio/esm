module eebiotools

using CSV, DataFrames, FileIO, JSON, Comonicon, FCSFiles, Parameters, JSONTables, JSONSchema, XLSX, Statistics
import Statistics.mean
include("./io/read.jl")
include("./base/main.jl")
include("./io/ESM_read.jl")
include("./io/ESM_write.jl")
export read_fcs, read_csv, read_metadata, asscMetadata,leave, main, read_excel, write_conv, read_esm, esm_zones, read_data

end # module eebiotools
