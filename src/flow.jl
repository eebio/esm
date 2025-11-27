using ProgressMeter
using Dates
using FCSFiles
using FileIO
using StatsBase
using KernelDensity
using Meshes

struct FlowCytometryData <: AbstractESMDataType end

abstract type AbstractGatingMethod <: AbstractESMMethod end

abstract type AbstractAutoGate <: AbstractGatingMethod end

abstract type AbstractManualGate <: AbstractGatingMethod end

abstract type AbstractLogicalGate <: AbstractGatingMethod end

"""
    read_flow(samples, sample_dict,channels,broad_g,channel_map)

Read the flow cytometry data from a file.

Args:

- `samples::DataFrame`: DataFrame of samples to read from.
- `sample_dict::Dict`: Output sample Dict.
- `channels::Vector`: Channels to read.
- `broad_g::Vector`: The physical group that this is part of.
- `channel_map::Dict`: The names to replace the old channel names with.
"""
function read_flow(samples, sample_dict, channels, broad_g, channel_map)
    @info "Processing flow cytometer data from plate $(unique(samples.Plate)[1])"
    for j in eachrow(samples)
        if ismissing(j.Name)
            name = "plate_0$(j.Plate)_$(lowercase(j.Well))"
        else
            name = j.Name
        end
        temp = Dict()
        temp[:type] = "population"
        temp_data = load(j."Data Location")
        temp[:values] = Dict(channel_map[x] => temp_data["$(x)"] for x in channels)
        temp[:meta] = Dict(channel_map[x] => extract_flow(temp_data, "$x")
            for x in channels)
        sample_dict[name] = temp
        broad_g = [broad_g; [name]]
    end
    return sample_dict, broad_g
end

"""
    extract_flow(fcs,chan)

Extract the metadata from a fcs file.

Args:

- `fcs::FCSFile`: The read FCS file
- `chan::String`: The channel being read from
"""
function extract_flow(fcs, chan)
    p = findfirst([i == chan for i in keys(fcs)])
    Dict(
        :name => if hasproperty(fcs, Symbol("p$(p)n"))
            getproperty(fcs, Symbol("p$(p)n"))
        else
            missing
        end,
        :amp_type => if hasproperty(fcs, Symbol("p$(p)e"))
            getproperty(fcs, Symbol("p$(p)e"))
        else
            missing
        end,
        :range => if hasproperty(fcs, Symbol("p$(p)r"))
            getproperty(fcs, Symbol("p$(p)r"))
        else
            missing
        end,
        :filter => if hasproperty(fcs, Symbol("p$(p)f"))
            getproperty(fcs, Symbol("p$(p)f"))
        else
            missing
        end,
        :amp_gain => if hasproperty(fcs, Symbol("p$(p)g"))
            getproperty(fcs, Symbol("p$(p)g"))
        else
            missing
        end,
        :ex_wav => if hasproperty(fcs, Symbol("p$(p)l"))
            getproperty(fcs, Symbol("p$(p)l"))
        else
            missing
        end,
        :ex_pow => if hasproperty(fcs, Symbol("p$(p)o"))
            getproperty(fcs, Symbol("p$(p)o"))
        else
            missing
        end,
        :perc_em => if hasproperty(fcs, Symbol("p$(p)p"))
            getproperty(fcs, Symbol("p$(p)p"))
        else
            missing
        end,
        :name_s => if hasproperty(fcs, Symbol("p$(p)s"))
            getproperty(fcs, Symbol("p$(p)s"))
        else
            missing
        end,
        :det_type => if hasproperty(fcs, Symbol("p$(p)t"))
            getproperty(fcs, Symbol("p$(p)t"))
        else
            missing
        end,
        :det_volt => if hasproperty(fcs, Symbol("p$(p)v"))
            getproperty(fcs, Symbol("p$(p)v"))
        else
            missing
        end
    )
end

"""
    to_rfi(sample_name;chans=[])

Calculates relative fluorescence of given sample.

Args:
- `sample_name::String`: channel to use.
- `chans::Vector`: vector of channels to keep.
"""
function to_rfi(sample_name; chans = [])
    sub = es.samples[
        map(x -> !isnothing(match(Regex(string(sample_name * raw"\.")), x)),
            es.samples.name),
        :]
    if chans == []
        chans = sub.channel
    end
    o = Dict()
    for i in chans
        # Load metadata for channel
        at = parse.(
            Float64, split(sub[sub.name .== "$sample_name.$i", "meta"][1]["amp_type"], ","))
        ran = parse(Int, sub.meta[sub.name .== "$sample_name.$i", :][1]["range"])
        if at[1] == 0
            if isnothing(sub.meta[sub.name .== "$sample_name.$i", :][1]["amp_gain"])
                ag = 1.0
            else
                ag = parse(Int, sub.meta[sub.name .== "$sample_name.$i", :][1]["amp_gain"])
            end
            o[i] = Dict(
                :data => sub.values[sub.name .== "$sample_name.$i", :][1] ./ ag,
                :min => 1 / ag, :max => ran / ag)
        else
            # Non-linear gain
            o[i] = Dict(
                :data => at[2] *
                         10 .^ (at[1] *
                          (sub.values[sub.name .== "$sample_name.$i", :][1] / ran)),
                :min => at[2] * 10^(at[1] * (1 / ran)),
                :max => at[2] * 10^(at[1] * (ran / ran)))
        end
        o[i][:id] = 1:length(o[i][:data])
    end
    return o
end

"""
    gate(data, method::AbstractGatingMethod)

Filter `data` to only include events within the gate defined by `method`.

Args:
- `data::Dict`: Dict returned by RFI.
- `method::AbstractGatingMethod`: The method and settings to use for gating.
"""
function gate end

@kwdef struct KDE <: AbstractAutoGate
    channels::Vector{String}
    gate_frac::Float64 = 0.65
    nbins::Int64 = 1024
end

function gate(data, method::KDE)
    channels = method.channels
    gate_frac = method.gate_frac
    nbins = method.nbins
    length(channels) == 2 || error("2 channels must be specified for density gating.")
    x = data[channels[1]][:data]
    y = data[channels[2]][:data]
    N = length(x)

    hist_counts = fit(Histogram, (x, y); nbins = nbins)

    x_bins = hist_counts.edges[1]
    y_bins = hist_counts.edges[2]

    # Make the kde
    kd = kde((x, y))

    # Apply kde to values
    density_values = [pdf(kd, xi, yi) for (xi, yi) in zip(x, y)]

    fraction_to_keep = gate_frac
    sorted_indices = sortperm(density_values, rev = true)
    # Keep only the top density values of the sorted kde within the fraction to keep
    top_indice = sorted_indices[ceil(Int, fraction_to_keep * N)]

    # Threshold based on the least dense point from the sorted density vector above
    threshold = density_values[top_indice]
    # Only keep the values denser than the threshold
    inside_indices = density_values .> threshold
    return apply_mask(data, inside_indices)
end

@kwdef struct HighLowGate <: AbstractManualGate
    channel::String
    max::Float64 = Inf
    min::Float64 = -Inf
end

function gate(data, method::HighLowGate)
    dat_mask = method.min .<= data[method.channel][:data] .< method.max
    return apply_mask(data, dat_mask)
end

@kwdef struct RectangleGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    x_min::Float64
    x_max::Float64
    y_min::Float64
    y_max::Float64
end

function gate(data, method::RectangleGate)
    dat_mask = (method.x_min .<= data[method.channel_x][:data] .< method.x_max) .&
               (method.y_min .<= data[method.channel_y][:data] .< method.y_max)
    return apply_mask(data, dat_mask)
end

@kwdef struct QuadrantGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    x_cutoff::Float64
    y_cutoff::Float64
    quadrant::Int64
end

function gate(data, method::QuadrantGate)
    if method.quadrant == 1
        dat_mask = (data[method.channel_x][:data] .>= method.x_cutoff) .&
                   (data[method.channel_y][:data] .>= method.y_cutoff)
    elseif method.quadrant == 2
        dat_mask = (data[method.channel_x][:data] .>= method.x_cutoff) .&
                   (data[method.channel_y][:data] .< method.y_cutoff)
    elseif method.quadrant == 3
        dat_mask = (data[method.channel_x][:data] .< method.x_cutoff) .&
                   (data[method.channel_y][:data] .< method.y_cutoff)
    elseif method.quadrant == 4
        dat_mask = (data[method.channel_x][:data] .< method.x_cutoff) .&
                   (data[method.channel_y][:data] .>= method.y_cutoff)
    else
        error("Quadrant must be between 1 and 4.")
    end
    return apply_mask(data, dat_mask)
end

@kwdef struct PolygonGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    points::Vector{Tuple{Float64, Float64}}
end

function gate(data, method::PolygonGate)
    poly = PolyArea(method.points)
    dat_mask = [Point(xi, yi) ∈ poly for (xi, yi) in
                zip(data[method.channel_x][:data], data[method.channel_y][:data])]
    return apply_mask(data, dat_mask)
end

struct EllipseGate <: AbstractManualGate
    channel_x::String
    channel_y::String
    center::Tuple{Float64, Float64}
    a::Float64
    b::Float64
    angle::Float64
end

function EllipseGate(; channel_x::String, channel_y::String, center::Union{Tuple{Float64, Float64}, Nothing}=nothing,
                     points::Vector{Tuple{Float64, Float64}})
    if (length(points) < 3 && !isnothing(center)) || (length(points) < 5 && isnothing(center))
        error("At least 3 points and a center or 5 points without a center are required to fit an ellipse.")
    end
    # Fit ellipse to points
    xs = [p[1] for p in points]
    ys = [p[2] for p in points]
    if length(points) < 5
        # Add extra points on ellipse until we have 5
        for i in length(points)+1:5
            push!(xs, points[i-length(points)][1] + 2*(center[1] - points[i-length(points)][1]))
            push!(ys, points[i-length(points)][2] + 2*(center[2] - points[i-length(points)][2]))
        end
        points = zip(xs, ys)
    end
    # Fit ellipse to 5 points
    xs = [p[1] for p in points]
    ys = [p[2] for p in points]
    a, b, θ, centerx, centery = fit_ellipse(xs, ys)
    center = (centerx, centery)
    angle = rad2deg(θ)
    return EllipseGate(channel_x, channel_y, center, a, b, angle)
end

function gate(data, method::EllipseGate)
    cos_angle = cosd(method.angle)
    sin_angle = sind(method.angle)
    cx, cy = method.center
    a, b = method.a, method.b
    dat_mask = zeros(Bool, length(data[method.channel_x][:data]))
    for (i, xi, yi) in zip(1:event_count(data),data[method.channel_x][:data], data[method.channel_y][:data])
        # Rotate points onto ellipse axes
        x_rot = cos_angle * (xi - cx) + sin_angle * (yi - cy)
        y_rot = -sin_angle * (xi - cx) + cos_angle * (yi - cy)
        # Check against canonical ellipse equation
        val = (x_rot^2) / (a^2) + (y_rot^2) / (b^2)
        dat_mask[i] = val <= 1.0
    end
    return apply_mask(data, dat_mask)
end

"""
    event_count(data)

Count the number of events in the flow cytometry data.

Args:
- `data::Dict`: Dict returned by RFI.
"""
function event_count(data)
    if !all(length(data[i][:data]) == length(data[first(keys(data))][:data])
    for i in keys(data))
        error("All channels must have the same number of events.")
    end
    return length(data[first(keys(data))][:data])
end

"""
    gated_proportion(data, gate)
    gated_proportion(data_before, data_after)

Calculate the proportion of events remaining after gating.

Args:
- `data::Dict`: Dict returned by RFI.
- `gate::AbstractGatingMethod`: A gating method to report on.
- `data_before::Dict`: Dict returned by RFI before gating.
- `data_after::Dict`: Dict returned by RFI after gating.
"""
function gated_proportion(data, method::AbstractGatingMethod)
    total_events = event_count(data)
    gated_data = gate(data, method)
    gated_events = event_count(gated_data)
    return gated_events / total_events
end

function gated_proportion(data_before, data_after)
    total_events = event_count(data_before)
    gated_events = event_count(data_after)
    return gated_events / total_events
end

# Logical operations on gates
struct AndGate{X, Y} <:
       AbstractLogicalGate where {X <: AbstractGatingMethod, Y <: AbstractGatingMethod}
    gate1::X
    gate2::Y
end

struct OrGate{X, Y} <:
       AbstractLogicalGate where {X <: AbstractGatingMethod, Y <: AbstractGatingMethod}
    gate1::X
    gate2::Y
end

struct NotGate{X} <: AbstractLogicalGate where {X <: AbstractGatingMethod}
    gate1::X
end

function Base.:&(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return AndGate(g1, g2)
end

function Base.:|(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return OrGate(g1, g2)
end

function Base.:!(g::AbstractGatingMethod)
    return NotGate(g)
end

function and(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return g1 & g2
end
function or(g1::AbstractGatingMethod, g2::AbstractGatingMethod)
    return g1 | g2
end

function not(g::AbstractGatingMethod)
    return !g
end

function gate(data, method::AndGate)
    data = gate(data, method.gate1)
    data = gate(data, method.gate2)
    return data
end

function gate(data, method::OrGate)
    data1 = gate(data, method.gate1)
    data2 = gate(data, method.gate2)
    mask1 = [true for i in 1:event_count(data)]
    mask2 = [true for i in 1:event_count(data)]
    for i in keys(data)
        mask1 .= mask1 .& [id ∈ data1[i][:id] for id in data[i][:id]]
        mask2 .= mask2 .& [id ∈ data2[i][:id] for id in data[i][:id]]
    end
    final_mask = mask1 .| mask2
    return apply_mask(data, final_mask)
end

function gate(data, method::NotGate)
    data1 = gate(data, method.gate1)
    mask1 = [true for i in 1:event_count(data)]
    for i in keys(data)
        mask1 .= mask1 .& [id ∈ data1[i][:id] for id in data[i][:id]]
    end
    final_mask = .!mask1
    return apply_mask(data, final_mask)
end

function apply_mask(data, mask)
    data = deepcopy(data)
    for i in keys(data)
        data[i][:data] = [xi for (xi, m) in zip(data[i][:data], mask) if m]
        data[i][:id] = [xi for (xi, m) in zip(data[i][:id], mask) if m]
    end
    return data
end
