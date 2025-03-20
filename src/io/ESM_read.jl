"""
    sexp_to_nested_list(sexp,es,trans_meta_map)

Recursively converts the parsed equations to julia code and produces the correct dataframes over which to operate. This also calls any unprocessed transformations.

Args:

- sexp - Expression or part of expression to be decomposed.
- es - The esm_zones data type that contains the data (global variable).
- trans_meta_map - The transformation map of the parsed transformations.
"""
function sexp_to_nested_list(sexp::Any, es, trans_meta_map)
    if isa(sexp, Symbol)
        if isdefined(ESM, sexp)
            # Is the symbol a function?
            return sexp
        elseif sexp in keys(trans_meta_map)
            # Is the symbol a transformation
            # TODO Needs circular referencing of transformations adjusted
            return eval(sexp_to_nested_list(trans_meta_map[sexp], es, trans_meta_map))
        elseif string(sexp) in es.groups.group
            # Is the symbol a group?
            return form_df(filter_row(es, sexp))
        else
            # Just return it - its something else
            return sexp
        end
    elseif isa(sexp, Expr)
        # Check if the symbol is an expression as this could mean further processing
        result = []
        if true in [isa(i, QuoteNode) for i in sexp.args]
            # Check if there is a quote node - this allows the `.` syntax in the ESM
            if isa(sexp.args[1], Expr)
                # If its a normal expression process it normally
                return sexp_to_nested_list(sexp, es, trans_meta_map)
            elseif Symbol(string(sexp.args[1])) in keys(trans_meta_map)
                # Is it in the transformation map?
                if string(sexp.args[2].value) in es.groups.group
                    # Check if the second part of the quote node is in the groups - this allows a group to be sub-specified. e.g. only return the samples that are part of two groups
                    # `eval` the transformation and then sub filter using the names of the samples
                    return filter_col(
                        eval(sexp_to_nested_list(
                            trans_meta_map[Symbol(string(sexp.args[1]))],
                            es, trans_meta_map)),
                        find_group(es, string(sexp.args[2].value)))
                else
                    # Just `eval` the other transformation
                    return remove_subcols(
                        filter_col(
                            eval(sexp_to_nested_list(
                                trans_meta_map[Symbol(string(sexp.args[1]))],
                                es, trans_meta_map)),
                            [string(sexp.args[2].value)]),
                        sexp.args[2].value)
                end
            else
                if string(sexp.args[2].value) in es.groups.group
                    # Is the symbol a group - create the data frame
                    return filter_col(form_df(filter_row(es, sexp.args[1])),
                        find_group(es, string(sexp.args[2].value)))
                elseif string(sexp.args[1]) * "." * string(sexp.args[2].value) in es.samples.name
                    # Is the group a single data frame?
                    # Filter the original sample frame and create a data frame from that
                    return form_df(es.samples[
                        es.samples.name .== string(sexp.args[1]) * "." * string(sexp.args[2].value),
                        :])
                else
                    # Have a go - will probs cause a crash, but at this point its on the user, in my opinion
                    return remove_subcols(
                        filter_col(
                            form_df(filter_row(es, sexp.args[1])), [sexp.args[2].value]),
                        sexp.args[2].value)
                end
            end
        else
            # Just process it normally - its nothing special
            for arg in sexp.args
                push!(result, sexp_to_nested_list(arg, es, trans_meta_map))
            end
        end
        return Expr(sexp.head, result...)
    elseif isa(sexp, LineNumberNode)
        # Just to catch exceptions
        return []
    elseif isa(sexp, QuoteNode)
        # Probably does nothing
        return sexp_to_nested_list(sexp.value, es, trans_meta_map)
    elseif isa(sexp, Number)
        # Catches and keep any number that comes through the transformations
        return sexp
    elseif isa(sexp, String)
        # Catches any parsed strings and keeps them. This allows for certain keyword args to be parsed
        return sexp
    else
        # Ya dun goofed
        print(sexp)
        error("Unexpected type: $(typeof(sexp))")
    end
end

"""
    produce_views(es, trans_meta_map;to_out=[])

Produces the views specified in `to_out` else all views in `esm.views`.

Args:

- `es=<esm_zones>`: The esm_zones object (global)
- `trans_meta_map=<Dict>`: A dictionary mapping transformations to their names.
- `to_out=<Array>`: A list of all the views to be produced.
"""
function produce_views(es, trans_meta_map; to_out = [])
    # No views specified? Do all then
    if to_out == []
        to_out = keys(es.views)
    end
    # Initialise the output of views dict
    v_out = Dict()
    for i in to_out
        @info "Producing view $i."
        # Initialise the result dict that can be concatenated later
        result = []
        # Loop over the views list
        for j in es.views[i]["data"]
            # Check if this is a transformation to initiate the processing
            if Symbol(j) in keys(trans_meta_map)
                # Put the result in the results array
                push!(result,
                    eval(sexp_to_nested_list(
                        trans_meta_map[Symbol(j)], es, trans_meta_map)))
            elseif Symbol(j) in es.groups.group
                # If its a group, put the basal data in the results array
                push!(result, form_df(filter_row(es, Symbol(j))))
            elseif j in es.samples.name
                # If its a sample, create the df and push it
                push!(result, form_df(es.samples[es.samples.name .== j, :]))
            else
                # Ya dun goofed.
                @warn "Transformation/Group - $j - not found please check your transformation and groups. \n Reminder: Time on plate readers is handled per channel and associated with a specific plate. Please specify the time as: plate_0x_time.channel ."
            end
        end
        try
            # Put it all in the same frame and not a vector
            v_out[i] = hcat(result...)
        catch
            # Put in the same vector with different labels because they exist twice
            @warn "Duplicate labels detected, left DataFrame denoted with _1 right denoted with _2.\n"
            v_out[i] = hcat(result..., makeunique = true)
        end
    end
    @info "Views produced."
    return v_out
end

"""
    remove_subcols(df, sub)

Gets rid of certain sub col ids in the col names.

e.g. \n
    remove flo
    a1.flo -> a1
"""
function remove_subcols(df, sub)
    rename!(s -> replace(s, Regex("." * string(sub)) => ""), df)
    return df
end

"""
    filter_row(es,group)

Filter the original es.samples dataframe by a specific group defined in the esm.

Args:

- `es=<esm_zones>`: esm zones data type. global
- `group=<string || vector>`: what group/groups to filter by.
"""
function filter_row(es, group)
    return es.samples[es.samples[!, group] .== true, :]
end

"""
    filter_col(df, reg_l)

Filters a df by a set of columns or parts of columns given in reg_l. reg_l is joined to form regex using `|`.

Args:

- `df=<DataFrame>` DataFrame to filter.
- `reg_l=<Array{String}>`: Array of strings to filter by.
"""
function filter_col(df, reg_l)
    return df[:,
        filter(colname -> occursin((Regex(join(string.(reg_l), "|"))), string(colname)),
            names(df))]
end

"""
    form_df(df)

Creates the data frame from the dataframe it is passed. This is to turn the es.samples.values arrays into dfs.

Args:

- `df=<DataFrame>`: A dataframe of es.samples to parse.
"""
function form_df(df)
    max_dat = maximum(length.(df.values))
    return hcat([DataFrame(j.name => [j.values; fill(missing, max_dat - length(j.values))])
                 for j in eachrow(df)]...)
end

"""
    find_group(es,grn)

Finds a specific group from the original es.groups dataframe and returns the sample names.

Args:

- `es=<esm_zones>`: the original es object.
- `grn=<String>`: A string of a group name which can be used to filter the original dataframe.
"""
function find_group(es, grn)
    return es.groups[es.groups.group .== grn, :sample_IDs][1]
end

"""
    view_to_csv(es,trans_meta_map;out_dir,to_out)

Controls the calling of the view producer and writes the outputted views to a csv file.

Args:

- `es=<esm_zones>`: The original esm struct
- `trans_meta_map=<Dict>`: The transformations that have been parsed at the top level.
- `out_dir=<String>`: The specified output dir - defaults to nothing.
- `to_out=<Array{String}>`: The views to be processed.
"""
function view_to_csv(es, trans_meta_map; outdir = "", to_out = [])
    # Process the views
    vs = produce_views(es, trans_meta_map; to_out = to_out)
    # Write the views to file
    for i in keys(vs)
        @info "Writing view: $i to $outdir/$i.csv"
        CSV.write("$outdir/$i.csv", vs[i])
    end
    @info "Views written successfully."
end

"""
    read_es(filen)

Reads and processes the esm file produced at a file name and creates the esm_zones struct.

Args:

- `filen=<String>`

esm.samples DataFrame cols: |name | channel | type | values | meta | group... |

- name - name.channel
- channel - data channel
- type - type of sample - time series or population
- values - Arrays of data values.
- meta - any meta data associated with the data.
- group - boolean columns associating the groups with samples.
"""
function read_esm(filen)
    @info "Reading ESM file at: $filen"
    # Read in the file in a JSON format
    ef = JSON.parsefile(filen)
    max_len = 0
    # Loop over the samples to look for maximum length of array
    for i in keys(ef["samples"])
        for j in keys(ef["samples"][i]["values"])
            k = length(ef["samples"][i]["values"][j])
            if k > max_len
                max_len = k
            end
        end
    end
    # Create the ESM object
    es = esm_zones(
        samples = DataFrame(
            [(lowercase(i),
                 j,
                 ef["samples"][i]["type"],
                 replace(ef["samples"][i]["values"][j], nothing => NaN),
                 if !isempty(keys(ef["samples"][i]["meta"]))
                     ef["samples"][i]["meta"][j]
                 else
                     ef["samples"][i]["meta"]
                 end,
                 [i in lowercase.(ef["groups"][k]["sample_IDs"])
                  for k in keys(ef["groups"])]...) for i in keys(ef["samples"])
             for j in keys(ef["samples"][i]["values"])],
            ["name", "channel", "type", "values", "meta",
                [k for k in keys(ef["groups"])]...]),
        groups = DataFrame(
            [(i,
                 lowercase.(ef["groups"][i]["sample_IDs"]),
                 ef["groups"][i]["metadata"],
                 :(filter(row -> row.name in ef["groups"][i]["sample_IDs"],
                     samples, view = true))) for i in keys(ef["groups"])],
            ["group", "sample_IDs", "metadata", "meta_select"]),
        transformations = ef["transformations"],
        views = ef["views"]
    )
    # Add channels to sample names - important for creating dataframes from the samples down the line
    es.samples.name = string.(es.samples.name, ".", es.samples.channel)
    @info "ESM file successfully read."
    return es
end

#TODO - remove type piracy on mean
mean(df::DataFrame) = return reduce(+, eachcol(df)) ./ ncol(df)

vcat(x...) = return vcat(x)

"""
    index_between_vals(df; minv, maxv)

Returns the indexes between two points so that these can be later isolated. This is in dict form to allow for individual points to be separated out.
Both ends are inclusive.

If minv is larger than all values in the column, or maxv smaller, will return `(nothing,nothing)`.
Args:

- `df=<DataFrame>`: DataFrame to work on.
- `minv=<Float64>`: Minimum value.
- `maxv=<Float64>`: Maximum value.
"""
function index_between_vals(df::DataFrame; minv = -Inf, maxv = Inf)
    return Dict(col => (findfirst(x -> minv <= x <= maxv, df[:, col]),
                    findlast(x -> minv <= x <= maxv, df[:, col])) for col in names(df))
end

"""
    between_times(df,time_col;mint,maxt)

Returns the DataFrame between two timepoints.

Args:

- `df=<DataFrame>`: DataFrame to work on.
- `time_col=<DataFrame>`: DataFrame of time values.
- `mint=<Float64>`: Minimum time in mins.
- `maxt=<Float64>`: Max time in mins.
"""
function between_times(df::DataFrame, time_col::DataFrame; mint = -Inf, maxt = Inf)
    time_col = mapcols(col -> Dates.Time.(col, dateformat"H:M:S"), time_col)
    time_col = mapcols(col -> [i.instant.value * (1e-9) for i in col], time_col)
    # Do time calculations in seconds to avoid floating point math
    tvals = index_between_vals(time_col; minv = mint * 60, maxv = maxt * 60)[names(time_col)[1]]
    if isnothing(tvals[1]) || isnothing(tvals[2])
        @warn "No values found between $mint and $maxt."
        # Return empty dataframe of the same type
        return df[1:0, :]
    end
    return df[tvals[1]:tvals[2], :]
end

"""
    at_time(df, time_col, time_point)

Returns values at a specific time point.
If no value at specific timepoint, return the last recording before the timepoint.
If time_point < minimum(time_col), return `nothing`.

Args:

- `df=<DataFrame>`: DataFrame on which to work.
- `time_col=<DataFrame>`: Time values in a DataFrame.
- `time_point=<Float64>`: Time point in mins at which to report the measurement.
"""
function at_time(df::DataFrame, time_col::DataFrame, time_point)
    time_col = mapcols(col -> Dates.Time.(col, dateformat"H:M:S"), time_col)
    time_col = mapcols(col -> [i.instant.value * (1e-9) for i in col], time_col)
    tvals = index_between_vals(time_col; minv = 0, maxv = time_point * 60)[names(time_col)[1]]
    if isnothing(tvals[2])
        @warn "No values found at or before $time_point."
        # Return empty dataframe of the same type
        return df[1:0, :]
    end
    return df[tvals[2], :]
end

"""
    at_od(od_df,target_df,target_od)

A function to return a set of values from a different dataframe based on another.
In theory this can be used for many types of data, but this adds the functionality
to target a specific OD and return the values from another dataframe at that index.

Args:

- `od_df=<DataFrame>`: The DataFrame you are getting the indexes from.
- `target_df=<DataFrame>`: The DataFrame you want to get the values from.
- `target_od=<Float64>`: The value at which you are limiting the data to
"""
function at_od(od_df, target_df, target_od)
    dict_2 = Dict()
    for i in names(od_df)
        # Filter out the non-data cols
        if all(isa.(od_df[:, i], String))
            @warn "Skipping $i as it contains only `string`."
        else
            # Note that NaNs are mapped to 0 to ignore them
            if target_od > maximum(replace(od_df[:, i], NaN => 0.0))
                @warn "Skipping $i as the target OD ($target_od) is higher than the maximum OD ($(maximum(replace(od_df[:,i],NaN=>0.0))))."
            else
                dic = index_between_vals(
                    filter_col(od_df, [i]); minv = target_od, maxv = target_od)[i]
                if isnothing(dic[1])
                    dict_2[i] = nothing
                else
                    dict_2[i] = target_df[dic[1], i]
                end
            end
        end
    end
    return DataFrame(dict_2)
end

"""
    doubling_time(df, time_col;max_od)

Calculates the growth rate/doubling time of a given dataframe. returns in min^-1

equation = (t_end - t_start)/log_2(max_od/min_od)

Args:

- `df=<DataFrame>`: DataFrame containing the data.
- `time_col=<DatFrame>`: DataFrame containing the times.
- `max_od=<Float64>`: Maximum OD. Defaults to 0.4 - min_od is 1/4 of this value.
"""
function doubling_time(df::DataFrame, time_col::DataFrame; max_od::Float64 = 0.4)
    min_od = max_od / 4
    dict_2 = Dict()
    time_col = mapcols(col -> Dates.Time.(col, dateformat"H:M:S"), time_col)
    time_col = mapcols(col -> [i.instant.value * (1e-9) for i in col], time_col)
    for i in names(df)
        indexes = index_between_vals(df; minv = min_od, maxv = max_od)[i]
        # Is the max greater than what we can deal with?
        if max_od > maximum(df[:, i])
            @warn "Skipping $i as the max_od 4 x min_od ($max_od) is greater than in this sample ($(maximum(df[:,i])))."
        else
            dict_2[i] = (time_col[indexes[2], 1] - time_col[indexes[1], 1]) /
                        log2(df[indexes[2], 1] / df[indexes[1], 1]) / 60
        end
    end
    return DataFrame(dict_2)
end

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
    # TODO Does to_rfi mutate the data?
    sub = es.samples[
        map(x -> !isnothing(match(Regex(string(sample_name * raw"\.")), x)),
            es.samples.name),
        :]
    if chans == []
        chans = sub.channel
    end
    at = Dict(i => parse.(Float64,
                  split(sub[sub.name .== "$sample_name.$i", "meta"][1]["amp_type"], ","))
    for i in chans)
    if length(at) != length(chans)
        error("Some amplification types not specfied data will not process.")
    end
    if !(false in ["range" in keys(sub.meta[sub.name .== "$sample_name.$i", :][1])
                   for i in chans])
        ran = Dict(i => parse(Int, sub.meta[sub.name .== "$sample_name.$i", :][1]["range"])
        for i in chans)
    else
        ran = false
    end
    if !(false in ["amp_gain" in keys(sub.meta[sub.name .== "$sample_name.$i", :][1]) &&
                   sub.meta[sub.name .== "$sample_name.$i", :][1]["amp_gain"] != nothing
                   for i in chans])
        ag = Dict(i => parse(
                      Int, sub.meta[sub.name .== "$sample_name.$i", :][1]["amp_gain"])
        for i in chans)
    else
        ag = false
    end
    o = Dict()
    for i in chans
        if at[i][1] == 0
            # Linear gain
            if ag == false
                # No gain set, set to 1
                o[i] = Dict(:data => sub.values[sub.name .== "$sample_name.$i", :][1] ./ 1,
                    :min => 1 / 1, :max => ran[i] / 1)
            else
                o[i] = Dict(
                    :data => sub.values[sub.name .== "$sample_name.$i", :][1] ./ ag[i],
                    :min => 1 / ag[i], :max => ran[i] / ag[i])
            end
        else
            # Non-linear gain
            try
                ran
            catch
                error("Resolution must be specified")
            end
            o[i] = Dict(
                :data => at[i][2] *
                         10 .^ (at[i][1] *
                          (sub.values[sub.name .== "$sample_name.$i", :][1] / ran[i])),
                :min => at[i][2] * 10^(at[i][1] * (1 / ran[i])),
                :max => at[i][2] * 10^(at[i][1] * (ran[i] / ran[i])))
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
