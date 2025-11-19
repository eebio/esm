using ProgressMeter
using Dates
using FCSFiles
using FileIO
using StatsBase
using KernelDensity

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
        try
            temp = Dict()
            temp[:type] = "population"
            temp_data = load(j."Data Location")
            temp[:values] = Dict(channel_map[x] => temp_data["$(x)"] for x in channels)
            temp[:meta] = Dict(channel_map[x] => extract_flow(temp_data, "$x")
            for x in channels)
            sample_dict[name] = temp
        catch e
            @warn "\n\nFatal error encountered for well $name as file $(j."Data Location") is invalid - check the specified location or if the file is corrupted."
            throw(e)
        end
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
    p = findfirst([i == chan for i in fcs.data.axes[1]])
    props = unique([i.match[4]
                    for i in eachmatch(Regex("\\\$P$(p)[A-Z]"), join(keys(fcs.params)))])
    Dict(
        :name => if 'N' in props
            fcs.params["\$P$(p)N"]
        else
            missing
        end,
        :amp_type => if 'E' in props
            fcs.params["\$P$(p)E"]
        else
            missing
        end,
        :range => if 'R' in props
            fcs.params["\$P$(p)R"]
        else
            missing
        end,
        :filter => if 'F' in props
            fcs.params["\$P$(p)F"]
        else
            missing
        end,
        :amp_gain => if 'G' in props
            fcs.params["\$P$(p)G"]
        else
            missing
        end,
        :ex_wav => if 'L' in props
            fcs.params["\$P$(p)L"]
        else
            missing
        end,
        :ex_pow => if 'O' in props
            fcs.params["\$P$(p)O"]
        else
            missing
        end,
        :perc_em => if 'P' in props
            fcs.params["\$P$(p)P"]
        else
            missing
        end,
        :name_s => if 'S' in props
            fcs.params["\$P$(p)S"]
        else
            missing
        end,
        :det_type => if 'T' in props
            fcs.params["\$P$(p)T"]
        else
            missing
        end,
        :det_volt => if 'V' in props
            fcs.params["\$P$(p)V"]
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
            local ag
            try
                ag = parse(Int, sub.meta[sub.name .== "$sample_name.$i", :][1]["amp_gain"])
            catch e
                if isa(e, MethodError)
                    # If the gain is not defined, set it to 1
                    ag = 1.0
                else
                    rethrow(e)
                end
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
    gate(data, method::AbstractAutoGate)

Automatically perform density gating.

Args:
- `data::Dict`: Dict returned by RFI.
- `method::AbstractAutoGate`: The method and settings to use for autogating.
"""
function autogate end

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

"""
    gate(data, method::AbstractManualGate)

Filter `data` to only include events within the gate defined by `method`.

Args:
- `data::Dict`: Dict returned by RFI.
- `method::AbstractManualGate`: The method and settings to use for manual gating.
"""
function gate end

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

"""
    event_count(data)

Count the number of events in the flow cytometry data.

Args:
- `data::Dict`: Dict returned by RFI.
"""
function event_count(data)
    if !all(length(data[i][:data]) == length(data[first(keys(data))][:data]) for i in keys(data))
        error("All channels must have the same number of events.")
    end
    return length(data[first(keys(data))][:data])
end

# Logical operations on gates
struct AndGate{X,Y} <: AbstractLogicalGate where {X<:AbstractGatingMethod, Y<:AbstractGatingMethod}
    gate1::X
    gate2::Y
end

struct OrGate{X, Y} <: AbstractLogicalGate where {X <: AbstractGatingMethod, Y <: AbstractGatingMethod}
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
        mask1 .= mask1 .& (data1[i][:id] .∈ data[i][:id])
        mask2 .= mask2 .& (data2[i][:id] .∈ data[i][:id])
    end
    final_mask = mask1 .| mask2
    return apply_mask(data, final_mask)
end

function gate(data, method::NotGate)
    data1 = gate(data, method.gate1)
    mask1 = [true for i in 1:event_count(data)]
    for i in keys(data)
        mask1 .= mask1 .& (data1[i][:id] .∈ data[i][:id])
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
