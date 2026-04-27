module ESM
@doc read(joinpath(dirname(@__DIR__), "README.md"), String) ESM

using Comonicon

abstract type AbstractESMMethod end

abstract type AbstractESMDataType end

struct ESMData <: AbstractESMDataType end

include("FitEllipse.jl")
include("esm_files.jl")
include("flow.jl")
include("main.jl")
include("plate_readers/main.jl")
include("summarise.jl")
include("views.jl")

export read_esm, esm_zones, read_data, write_esm
export template, translate, views, summarise
export growth_rate, doubling_time, lag_time, max_od, time_to_max_growth, od_at_max_growth
export MovingWindow, FiniteDiff, Endpoints, LinearOnLog
export ParametricGrowthRate, Logistic, Gompertz, ModifiedGompertz, Richards
export Regularization
export fluorescence
export RatioAtTime, RatioAtMaxGrowth
export calibrate
export TimeseriesBlank, SmoothedTimeseriesBlank, MeanBlank, MinBlank, MinData, StartZero
export gate, event_count, gated_proportion
export HighLowGate, RectangleGate, QuadrantGate, PolygonGate, EllipseGate
export and, or, not
export AndGate, OrGate, NotGate
export KDE
export AbstractESMMethod, AbstractPlateReaderMethod
export AbstractGrowthRateMethod
export AbstractESMDataType, AbstractPlateReader
export ESMData, FlowCytometryData, BioTek, SpectraMax, Tecan, GenericTabular
export summary

using Statistics: median
export median

"""
    esm translate

Translates the completed .xlsx template file to a .esm file.

# Args

- `input`: The completed .xlsx template file to be read.
- `output`: The filepath/destination for the .esm file.

"""
@cast function translate(input::String, output::String)
    x = read_data(input)
    write_esm(x, output)
end

"""
    esm views

Produce and save the views from a .esm file.

# Args

- `esm_file`: The .esm file to be read.

# Options
- `-v, --view=<String>`: The view to be produced. All views if not specified.
- `-o, --output-dir=<String>`: The directory to save the output(s) to. Defaults to the
    current directory.

"""
@cast function views(esm_file::String; view = nothing, output_dir::String = ".")
    es = read_esm(esm_file)
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

- `-o, --output-path=<String>`: The path to create the template in. Defaults to ESM.xlsx in
    the current directory.

"""
@cast function template(; output_path::String = "ESM.xlsx")
    e = pathof(ESM)
    e = e[1:(length(e) - 6)]
    cp(joinpath(e, "ESM.xlsx"), output_path)
end

"""
    esm summarise

Summarise a data file (.esm, plate reader, .fcs, etc.).

# Args

- `file`: The data file to be summarised.

# Options

- `-t, --type=<String>`: The type of data file. Options are "auto" (default), "esm",
    "spectramax", "biotek", "generic", "fcs". If "auto" is selected, the type will be
    inferred from the file extension (or raise an error if not possible).

# Flags

- `-p, --plot`: Produce plots of the data. Not available for `--type=esm`.
- `-c, --csv`: Save the data as CSV files. Not available for `--type=esm`.
"""
@cast function summarise(file; type = "auto", plot::Bool = false, csv::Bool = false)
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
            error("File type $ext cannot be inferred from extension. Supported extensions \
            are .esm or .fcs (or directories for generic tabular plate reader data).")
        end
    end
    if lowercase(type) == "esm"
        summary(file, ESMData(); plot = plot)
    elseif lowercase(type) == "fcs"
        summary(file, FlowCytometryData(); plot = plot, csv = csv)
    elseif lowercase(type) == "spectramax"
        summary(file, SpectraMax(); plot = plot, csv = csv)
    elseif lowercase(type) == "biotek"
        summary(file, BioTek(); plot = plot, csv = csv)
    elseif lowercase(type) == "tecan"
        summary(file, Tecan(); plot = plot, csv = csv)
    elseif lowercase(type) == "generic"
        summary(file, GenericTabular(); plot = plot, csv = csv)
    else
        error("Unsupported file type: $type.")
    end
end
Comonicon.@main

end # module ESM
