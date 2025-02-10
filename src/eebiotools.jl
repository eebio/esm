module eebiotools

using CSV, DataFrames, FileIO, JSON, Comonicon, FCSFiles, Parameters, JSONTables, XLSX, Statistics, DataStructures, StatsPlots, StatsBase, KernelDensity, ProgressMeter
import Statistics.mean, DataFrames.hcat
include("./io/read.jl")
# include("./base/main.jl")
include("./io/ESM_read.jl")
include("./io/ESM_write.jl")
export read_esm, esm_zones, read_data, write_esm

@cast create(;name::String) = esm("create";name=name)
@cast produce(;file_name::String,view::String,output_dir::String) = esm("produce";file_name=file_name,view=view,output_dir=output_dir)
@cast template(;output_dir::String) = esm("template";output_dir=output_dir)
@cast process(;file_name::String,view::String,output_dir::String) = esm("produce";file_name=file_name,view=view,output_dir=output_dir)

function esm(action;view::String="",file_name::String="",output_dir::String="",name::String="")
    if action == "create"
        x=read_data(file_name)
        write_esm(x;name=name)
    elseif action == "produce"
        es = read_esm(file_name)
        trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
        @info "Producing views."
        view_to_csv(es,trans_meta_map;outdir=output_dir,to_out=[view])
    elseif action == "template"
        e=pathof(eebiotools)
        e=e[1:length(e)-13]
        # f = read()
        cp(e[1]*"ESM.xlsx",output_dir)
    elseif action == "process"
        es = read_esm(file_name)
        trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
        @info "Producing views."
        view_to_csv(es,trans_meta_map;outdir=output_dir)
    end
end

@main

end # module eebiotools
