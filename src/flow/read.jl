using FCSFiles
using FileIO

"""
    read_flow(samples, sample_dict,channels,broad_g,channel_map)

Read the flow cytometry data from a file.

Arguments:
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
        temp["type"] = "population"
        temp_data = load(j."Data Location")
        if isempty(channels)
            channels = format_channel.(keys(temp_data))
            channels = [c == "Time" ? "time" : c for c in channels]
            channel_map = merge(Dict(c => c for c in channels), channel_map)
        end
        temp["values"] = Dict(channel_map[x] => temp_data[flow_channel("$(x)")]
        for x in channels)
        temp["metadata"] = convert(Dict{String, Any},
            Dict(channel_map[x] => extract_flow(
                     temp_data, flow_channel("$x"))
            for x in channels))
        temp["metadata"]["raw_metadata"] = Dict(k => getproperty(temp_data, k)
        for k in propertynames(temp_data))
        sample_dict[name] = temp
        broad_g = [broad_g; [name]]
    end
    return sample_dict, broad_g
end

function flow_channel(channel)
    if channel == "time"
        return "Time"
    end
    return replace(channel, "_" => "-")
end

"""
    extract_flow(fcs,chan)

Extract the metadata from a FCSFiles.FlowSample.

Arguments:
- `fcs`: The parsed FCS file.
- `chan::String`: The channel being read from.
"""
function extract_flow(fcs, chan)
    p = findfirst([i == chan for i in keys(fcs)])
    function mapper(char)
        if hasproperty(fcs, Symbol("p$(p)$(char)"))
            return getproperty(fcs, Symbol("p$(p)$(char)"))
        else
            return missing
        end
    end
    return Dict(
        "name" => mapper('n'),
        "amp_type" => mapper('e'),
        "range" => mapper('r'),
        "filter" => mapper('f'),
        "amp_gain" => mapper('g'),
        "ex_wav" => mapper('l'),
        "ex_pow" => mapper('o'),
        "perc_em" => mapper('p'),
        "name_s" => mapper('s'),
        "det_type" => mapper('t'),
        "det_volt" => mapper('v')
    )
end

"""
    to_rfi(sample_name;chans=[])

Calculates relative fluorescence of given sample.

Arguments:
- `sample_name::String`: channel to use.
- `chans::Vector`: vector of channels to keep.
"""
function to_rfi(es, sample_name)
    sub = es.samples[
        map(x -> !isnothing(match(Regex(string(sample_name * raw"\.")), x)),
            es.samples.name),
        :]
    chans = sub.channel
    o = Dict()
    for i in chans
        # Load metadata for channel
        amp_type = parse.(
            Float64, split(
                sub[sub.name .== "$sample_name.$i", "metadata"][1]["amp_type"], ","))
        range = parse(Int, sub.metadata[sub.name .== "$sample_name.$i", :][1]["range"])
        if amp_type[1] == 0
            if isnothing(sub.metadata[sub.name .== "$sample_name.$i", :][1]["amp_gain"])
                amp_gain = 1.0
            else
                amp_gain = sub.metadata[sub.name .== "$sample_name.$i", :][1]["amp_gain"]
                amp_gain = parse(Int, replace(amp_gain, ".0" => ""))
            end
            data = sub.values[sub.name .== "$sample_name.$i", :][1] ./ amp_gain
            min = 1 / amp_gain
            max = range / amp_gain
        else
            # Non-linear gain
            data = amp_type[2] *
                   10 .^ (amp_type[1] *
                    (sub.values[sub.name .== "$sample_name.$i", :][1] / range))
            min = amp_type[2] * 10^(amp_type[1] * (1 / range))
            max = amp_type[2] * 10^(amp_type[1] * (range / range))
        end
        o["$i.min"] = min
        o["$i.max"] = max
        o[i] = data
    end
    o["id"] = 1:length(o[chans[1]])
    return DataFrame(o)[!, sort(names(DataFrame(o)))]
end
