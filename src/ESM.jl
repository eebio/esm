module ESM

using CSV
using Comonicon
using DataFrames
using DataStructures
using Dates
using FCSFiles
using FileIO
using JSON
using KernelDensity
using Parameters
using ProgressMeter
using Statistics
using StatsBase
using XLSX
import Statistics.mean, DataFrames.hcat
include(joinpath(".","io","ESM_read.jl"))
include(joinpath(".", "io", "ESM_write.jl"))
export read_esm, esm_zones, read_data, write_esm

@with_kw struct esm_zones
    samples::DataFrame
    groups::Any
    transformations::Any
    views::Any
end

"""
    esm translate

Translates the completed .xlsx template file defined by `excel` and to a .esm file from and writes it to `target`.

# Options

- `-e, --excel=<String>`: The .xlsx template file to be read.
- `-t, --target=<String>`: The name of the output .esm file.

"""
@cast function translate(; excel::String, target::String)
    x = read_data(excel)
    write_esm(x, target)
end

"""
    esm views

Produces a specific view from within the .esm files and saves it to a specified folder.

# Options

- `-e, --esm-file=<String>`: The .xlsx file to be read.
- `-v, --view=<String>`: The view to be produced. If not specified, all views will be produced.
- `-o, --output-dir=<String>`: The directory to save the output(s) to. Defaults to the current directory.

"""
@cast function views(; esm_file::String, view = nothing, output_dir::String = ".")
    global es = read_esm(esm_file)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))
    @info "Producing views."
    if isnothing(view)
        views = []
    else
        views = [view]
    end
    view_to_csv(es, trans_meta_map; outdir = output_dir, to_out = views)
end

"""
    esm template

Produces a template excel file for data entry into the ESM.

# Options

- `-o, --output-path=<String>`: The path to create the template in. Defaults to ESM.xlsx in the current directory.

"""
@cast function template(; output_path::String = "ESM.xlsx")
    e = pathof(ESM)
    e = e[1:(length(e) - 6)]
    cp(joinpath(e, "io", "ESM.xlsx"), output_path)
end

Comonicon.@main

end # module ESM
