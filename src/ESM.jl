module ESM
@doc read(joinpath(dirname(@__DIR__), "README.md"), String) ESM

using Comonicon

abstract type AbstractESMMethod end

abstract type AbstractESMDataType end

struct ESMData <: AbstractESMDataType end

include("esm_files.jl")
include("flow.jl")
include("main.jl")
include("plate_readers.jl")
include("summarise.jl")
include("views.jl")

export read_esm, esm_zones, read_data, write_esm
export growth_rate, doubling_time
export MovingWindow, FiniteDiff, Endpoints, ExpOnLinear, LinearOnLog
export ParametricGrowthRate, Logistic, Gompertz, ModifiedGompertz, Richards
export calibrate
export TimeseriesBlank, MeanBlank, MinBlank, MinData, StartZero
export gate, event_count, to_rfi
export HighLowGate, RectangleGate, QuadrantGate
export and, or, not
export AndGate, OrGate, NotGate
export KDE
export AbstractESMMethod, AbstractPlateReaderMethod
export AbstractGrowthRateMethod
export AbstractESMDataType, AbstractPlateReader
export ESMData, FlowCytometryData, BioTek, SpectraMax, GenericTabular
export summary

"""
    esm translate

Translates the completed .xlsx template file to a .esm file.

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

Produce and save the views from a .esm file.

# Options

- `-e, --esm-file=<String>`: The .esm file to be read.
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

Produce a template excel file for data entry into the ESM.

# Options

- `-o, --output-path=<String>`: The path to create the template in. Defaults to ESM.xlsx in the current directory.

"""
@cast function template(; output_path::String = "ESM.xlsx")
    e = pathof(ESM)
    e = e[1:(length(e) - 6)]
    cp(joinpath(e, "ESM.xlsx"), output_path)
end

"""
    esm summarise

Summarise a data file (.esm, plate reader, .fcs, etc.).

# Options

- `-f, --file=<String>`: The data file to be summarised.
- `-t, --type=<String>`: The type of data file. Options are "auto" (default), "esm", "spectramax", "biotek", "generic", "fcs". If "auto" is selected, the type will be inferred from the file extension (or raise an error if not possible).

# Flags

- `-p, --plot`: Produce plots of the data. Only available for some types.
"""
@cast function summarise(; file=nothing, type="auto", plot::Bool=false)
    if isnothing(file)
        error("Please provide a file to be summarised using the -f or --file option.")
    end
    # If type=="auto", attempt to infer from file extension
    if type == "auto"
        ext = splitext(file)[end]
        if ext == ".esm"
            type = "esm"
        elseif ext == ".fcs"
            type = "fcs"
        elseif isdir(file)
            type = "generic"
        else
            error("File type $ext cannot be inferred from extension. Supported extensions are .esm and .fcs (or directories for generic tabular plate reader data).")
        end
    end
    if type == "esm"
        summary(file, ESMData(); plot=plot)
    elseif type == "fcs"
        summary(file, FlowCytometryData(); plot=plot)
    elseif type == "spectramax"
        summary(file, SpectraMax(); plot=plot)
    elseif type == "biotek"
        summary(file, BioTek(); plot=plot)
    elseif type == "generic"
        summary(file, GenericTabular(); plot=plot)
    else
        error("Unsupported file type: $type.")
    end
end
Comonicon.@main

end # module ESM
