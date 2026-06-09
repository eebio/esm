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
        temp["values"] = Dict{String, Any}(channel_map[x] => temp_data[flow_channel(x, temp_data)]
        for x in channels)
        temp["metadata"] = convert(Dict{String, Any},
            Dict(channel_map[x] => extract_flow(
                     temp_data, flow_channel(x, temp_data))
            for x in channels))
        temp["metadata"]["raw_metadata"] = Dict(k =>
            try
                getproperty(temp_data, k)
            catch
                "Error: Property could not be read"
            end
        for k in propertynames(temp_data))

        # Handle time channel units
        if haskey(channel_map, "time") && haskey(temp["values"], channel_map["time"])
            times = collect(temp["values"][channel_map["time"]])
            if hasproperty(temp_data, :timestep)
                if eltype(times) <: Integer
                    # Times are stored as integer multiples of timestep (as they should be)
                    timestep = parse(Float64, temp_data.timestep) # in seconds
                    temp["values"][channel_map["time"]] = times .* timestep .* 1000 # store time in milliseconds
                else
                    # Has a timestep but is stored as floats
                    # Has time been stored in seconds or milliseconds?
                    start_time = Time(strip(temp["metadata"]["raw_metadata"][:btim]))
                    end_time = Time(strip(temp["metadata"]["raw_metadata"][:etim]))
                    experiment_time = maximum(times)
                    if end_time - Second(2) <= start_time + Millisecond(round(experiment_time .* 1000)) <= end_time + Second(2)
                        # Already in seconds, convert to ms
                        temp["values"][channel_map["time"]] = times .* 1000
                    elseif end_time - Second(2) <= start_time + Millisecond(round(experiment_time)) <= end_time + Second(2) &&
                        end_time - start_time - Millisecond(round(experiment_time)) <= Millisecond(round(experiment_time))
                        # Also needed to check that start_time+experiment_time is closer to end_time than start_time
                        # Already in ms, do nothing
                    else
                        # Assume the time is meant to be an integer multiple of the timestep but was stored as floats
                        timestep = parse(Float64, temp_data.timestep) # in seconds
                        temp["values"][channel_map["time"]] = times .* timestep .* 1000 # convert to ms
                    end
                end
            end
            # Check time was handled correctly by comparing machine start and end times with the time channel data
            start_time = strip(temp["metadata"]["raw_metadata"][:btim])
            if count(==(':'), start_time) > 2
                start_time = Time(start_time, dateformat"HH:MM:SS:ss")
            else
                start_time = Time(start_time)
            end
            end_time = strip(temp["metadata"]["raw_metadata"][:etim])
            if count(==(':'), end_time) > 2
                end_time = Time(end_time, dateformat"HH:MM:SS:ss")
            else
                end_time = Time(end_time)
            end
            times = collect(temp["values"][channel_map["time"]])
            experiment_time = maximum(times)
            @assert end_time - Second(2) <= start_time + Millisecond(round(experiment_time)) <= end_time + Second(2) "Data from time channel does not match start and end times in the metadata. Please report this issue to the ESM developers with the FCS file that caused this error so we can fix it."
        end
        sample_dict[name] = temp
        broad_g = [broad_g; [name]]
    end
    return sample_dict, broad_g
end

function flow_channel(esmchannel, data)
    all_channels = keys(data)
    for c in all_channels
        if format_channel(c) == esmchannel
            return c
        end
    end
    for c in all_channels
        if lowercase(format_channel(c)) == lowercase(esmchannel)
            return c
        end
    end
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
