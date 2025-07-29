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
@cast translate(; excel::String, target::String) = esm(
    "translate"; file_name = excel, name = target)

"""
    esm produce

Produces a specific view from within the .esm files and saves it to a specified folder.

# Options

- `-e, --esm-file=<String>`: The .xlsx file to be read.
- `-v, --view=<String>`: The view to be exported.
- `-o, --output-dir=<String>`: The directory to save the output to.

"""
@cast produce(; esm_file::String, view::String, output_dir::String) = esm(
    "produce"; file_name = esm_file, view = view, output_dir = output_dir)

"""
    esm template

Produces a template excel file for data entry into the ESM.

# Options

- `-o, --output-path=<String>`: The output file path to write the template to. Does not specify the file.

"""
@cast template(; output_path::String) = esm("template"; output_dir = output_path)
# TODO: input form for template is really 'particular'

"""
    esm process

Produces a all views from within the .esm files and saves them to a specified folder.

# Options

- `-e, --esm-file=<String>`: The .xlsx file to be read.
- `-o, --output-dir=<String>`: The directory to save the output to.

"""
@cast process(; esm_file::String, output_dir::String) = esm(
    "process"; file_name = esm_file, output_dir = output_dir)

function esm(action; view::String = "", file_name::String = "",
        output_dir::String = "", name::String = "")
    if action == "translate"
        x = read_data(file_name)
        write_esm(x, name)
    elseif action == "produce"
        global es = read_esm(file_name)
        trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
        for i in keys(es.transformations))
        @info "Producing views."
        view_to_csv(es, trans_meta_map; outdir = output_dir, to_out = [view])
    elseif action == "template"
        e = pathof(ESM)
        e = e[1:(length(e) - 6)]
        cp(joinpath(e, "io", "ESM.xlsx"), joinpath(output_dir, "ESM.xlsx"))
    elseif action == "process"
        global es = read_esm(file_name)
        trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"])
        for i in keys(es.transformations))
        @info "Producing views."
        view_to_csv(es, trans_meta_map; outdir = output_dir)
    end
end

Comonicon.@main

end # module ESM
