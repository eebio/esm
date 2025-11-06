using ProgressMeter
using Dates
using FCSFiles
using FileIO
using StatsBase
using KernelDensity

struct FlowCytometryData <: AbstractESMDataType end

"""
    process_fcs(group::String,gate_channels::Vector,out_channels::Vector{String};gate_frac=0.65,nbins=1024,hl_channels=[],rfi=true,dense=true,hl=true,maxr=missing,minr=missing)

Processes fcs files from a given `group`. Can just calculate RFI, but also can do high/low gating and density gating.

Args:
- `group::String`: defines the group to work from.
- `gate_channels::Vector`: defines the channels to work from.
- `out_channels::Vector{String}`: defines the output channel.
- `gate_frac=0.65`: defines the fraction of population to keep.
- `nbins=1024`: defines the number of bins to use - mostly redundant.
- `hl_channels=[]`: which channels to use for high/low gating.
- `rfi=true`: whether to do RFI.
- `dense=true`: whether to do density gating.
- `hl=true`: whether to do high low gating.
- `maxr=missing`: max val for high/low gating.
- `minr=missing`: min val for high/low gating.
"""
function process_fcs(group::String, gate_channels::Vector, out_channels::Vector{String};
        gate_frac = 0.65, nbins = 1024, hl_channels = [], rfi = true,
        dense = true, hl = true, maxr = missing, minr = missing)
    out_data = []
    # Max length of data on out
    max_len = maximum([length(es.samples.values[
                           map(x -> !isnothing(match(Regex(string(i * raw"\.")), x)),
                               es.samples.name),
                           :][1])
                       for i in es.groups.sample_IDs[es.groups.group .== group, :][1]])
    @info "Processing flow cytometer data in :$group."
    # Make sure there is a way to know how far through this is
    @showprogress for i in es.groups.sample_IDs[es.groups.group .== group, :][1]
        if rfi
            o = to_rfi(i)
        end
        if hl
            #TODO Cant specify rfi=false, hl=true
            o = high_low(o; chans = hl_channels, maxr = maxr, minr = minr)
        end
        try
            (rfi == false && hl == false)
        catch
            error("Data must go through initial gating, please set rfi or hl to true.")
        end
        if dense
            df = density_gate(o, gate_channels; gate_frac = gate_frac, nbins = nbins)
            # Make the channels identifiable
            df = rename!(df[:, out_channels],
                [j => i * "." * j for j in names(df) if j in out_channels])
            # Add dataframe to output
            out_data = [out_data;
                        append!(df,
                            DataFrame([names(df)[j] => [0
                                                        for i in range(
                                           1, max_len - nrow(df))]
                                       for j in range(1, length(out_channels))]))]
        else
            data_inside = stack(o[i][:data] for i in keys(o))
            df = DataFrame(data_inside, [keys(o)...])
            out_data = [out_data;
                        append(
                            rename!(df[:, out_channels],
                                [j => i * "." * j for j in names(df) if j in out_channels]),
                            DataFrame([names(df)[j] => [i
                                                        for i in range(
                                           1, max_len - nrow(df))]
                                       for j in range(1, length(out_channels))]))]
        end
    end
    # Get rid of any trailing full 0 rows (they aren't necessary)
    return filter(row -> any(!=(0), row), hcat(out_data...))
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
    end
    return o
end

"""
    high_low(data;chans=[],maxr=missing,minr=missing)

Gate hig/low the data.

Args:

- `data::Dict`: Dictionary of data given by to_rfi
- `chans::Vector`: Channels to work over.
- `maxr::Int64`: max range
- `minr::Int64`: min range
"""
function high_low(data; chans = [], maxr = missing, minr = missing)
    if chans == []
        chans = keys(data)
    end
    if !ismissing(maxr) && !ismissing(minr) && (length(chans) >= 1)
        @warn "Processing flow data and limiting more than one channel ($(chans...)) by the same value."
    end
    dat_mask = true
    #TODO Is chans always a subset of keys?
    for i in keys(data)
        if i in chans
            if ismissing(minr) && ismissing(maxr)
                dat_mask = dat_mask .& (data[i][:min] .< data[i][:data] .< data[i][:max])
            else
                dat_mask = dat_mask .& (minr .< data[i][:data] .< maxr)
            end
        end
    end
    for i in keys(data)
        data[i][:data] = [xi for (xi, m) in zip(data[i][:data], dat_mask) if m]
    end
    return data
end

"""
    density_gate(data,channels=[];gate_frac=0.65,nbins=1024,outside=false)

Function to do density gaing using a KDE.

Args:

- `data::Dict`: Dict returned by RFI.
- `channels::Vector{String}`: Vector of channels to use for gating.
- `gate_frac::Float64`: Amount of samples to keep.
- `nbins::Int64`: Number of histogram bins.
- `outside::Bool`: Whether to return the outside data (only for internal troubleshooting not fore general usage).
"""
function density_gate(data, channels = []; gate_frac = 0.65, nbins = 1024, outside = false)
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

    data_inside = stack(data[i][:data] for i in keys(data))
    # Keep the data still inside for all the columns
    data_inside = data_inside[inside_indices, :]
    # Create the new output dataframe
    out_df = DataFrame(data_inside, [keys(data)...])
    x_inside = x[inside_indices]
    y_inside = y[inside_indices]
    if outside
        inside_bins = (x .>= minimum(x_bins)) .& (x .<= maximum(x_bins)) .&
                      (y .>= minimum(y_bins)) .& (y .<= maximum(y_bins))
        x_outside = x[inside_bins]
        y_outside = y[inside_bins]
        return (x_inside, y_inside), (x_outside, y_outside)
    else
        return out_df
    end
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
