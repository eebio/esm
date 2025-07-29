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
    esm produce

Produces a specific view from within the .esm files and saves it to a specified folder.

# Options

- `-e, --esm-file=<String>`: The .xlsx file to be read.
- `-v, --view=<String>`: The view to be exported.
- `-o, --output-dir=<String>`: The directory to save the output to.

"""
@cast function produce(; esm_file::String, view::String, output_dir::String)
    global es = read_esm(esm_file)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))
    @info "Producing views."
    view_to_csv(es, trans_meta_map; outdir = output_dir, to_out = [view])
end

"""
    esm template

Produces a template excel file for data entry into the ESM.

# Options

- `-o, --output-dir=<String>`: The output file path to write the template to. Does not specify the file.

"""
@cast function template(; output_dir::String)
    e = pathof(ESM)
    e = e[1:(length(e) - 6)]
    cp(joinpath(e, "io", "ESM.xlsx"), joinpath(output_dir, "ESM.xlsx"))
end

"""
    esm process

Produces a all views from within the .esm files and saves them to a specified folder.

# Options

- `-e, --esm-file=<String>`: The .xlsx file to be read.
- `-o, --output-dir=<String>`: The directory to save the output to.

"""
@cast function process(; esm_file::String, output_dir::String=".")
    global es = read_esm(esm_file)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
    for i in keys(es.transformations))
    @info "Producing views."
    view_to_csv(es, trans_meta_map; outdir = output_dir)
end

Comonicon.@main

end # module ESM
