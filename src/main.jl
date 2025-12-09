"""
    remove_subcols(df, sub)

Gets rid of certain sub col ids in the col names.

e.g. \n
    remove flo
    a1.flo -> a1
"""
function remove_subcols(df, sub)
    df = rename(s -> replace(s, Regex("." * string(sub)) => ""), df)
    return df
end

"""
    filter_row(es,group)

Filter the original es.samples dataframe by a specific group defined in the esm.

Arguments:
- `es::esm_zones`: esm zones data type.
- `group::Union{String,Vector}`: what group/groups to filter by.
"""
function filter_row(es, group)
    return es.samples[es.samples[!, group] .== true, :]
end

function filter_channel(df, channel)
    channel = string(channel)
    if haskey(df, "id")
        return df[:, contains.(names(df), "FL1_A") .|| names(df) .== "id"]
    end
    return remove_subcols(df[:, filter(colname -> splitext(colname)[2] == ".$channel", names(df))], channel)
end

"""
    filter_col(df, reg_l)

Filters a df by a set of columns or parts of columns given in reg_l.
reg_l is joined to form regex using `|`.

Arguments:
- `df::DataFrame`: DataFrame to filter.
- `reg_l::Vector{String}`: Vector of strings to filter by.
"""
function filter_col(df, reg_l)
    reg_l = Regex(join(string.(reg_l), "|"))
    return df[:, filter(colname -> occursin(reg_l, string(colname)), names(df))]
end

"""
    form_df(df)

Creates the data frame from the dataframe it is passed.
This is to turn the es.samples.values arrays into dfs.

Arguments:
- `df::DataFrame`: A dataframe of es.samples to parse.
"""
function form_df(df)
    max_dat = maximum(length.(df.values))
    return hcat([DataFrame(j.name => [j.values; fill(missing, max_dat - length(j.values))])
                 for j in eachrow(df)]...)
end

"""
    find_group(es,grn)

Finds a specific group from the original es.groups dataframe.
Returns the sample names.

Arguments:
- `es::esm_zones`: The data set to search.
- `grn::String`: A string of a group name which can be used to filter the original
    dataframe.
"""
function find_group(es, grn)
    return es.groups[es.groups.group .== grn, :sample_IDs][1]
end

function get_group(es, grn)
    # Is the group a flow group?
    sample_types = es.samples.type[getproperty(es.samples, grn)]
    if all(sample_types .== "population")
        data = [ESM.to_rfi(es, sample) for sample in find_group(es, string(grn))]
        # Check the data is compatible
        # All samples must have the same channels
        channels = [sort(collect(keys(d))) for d in data]
        @assert all([all(c .== channels[1]) for c in channels]) "Samples in group $grn have different channels."
        events = 0
        tmp = Dict{eltype(keys(data[1])), eltype(values(data[1]))}()
        for d in data
            for k in keys(d)
                if !haskey(tmp, k)
                    tmp[k] = Dict(:max => d[k][:max], :min => d[k][:min], :data => Float64[], :id => Int[])
                end
                append!(tmp[k][:data], d[k][:data])
                append!(tmp[k][:id], (events .+ d[k][:id]))
            end
            events += ESM.event_count(d)
        end
        return tmp
    elseif all(sample_types .== "timeseries")
        return ESM.form_df(ESM.filter_row(es, grn))
    else
        error("Group $grn contains mixed sample types (population and timeseries).")
    end
end

function get_sample(es, sample)
    # Is the sample a flow sample?
    sample_types = es.samples[sample .== get_sample_id.(es.samples.name), :type]
    if all(sample_types .== "population")
        return ESM.to_rfi(es, sample)
    end
    # Otherwise return DataFrame
    return ESM.form_df(es.samples[sample .== get_sample_id.(es.samples.name), :])
end

function get_sample_id(sample)
    return first(splitext(sample))
end

colmean(df::DataFrame) = return reduce(+, eachcol(df)) ./ ncol(df)

vcat(x...) = return vcat(x)

"""
    index_between_vals(df; minv=-Inf, maxv=Inf)

Returns the indexes between two points so that these can be later isolated.
This is in dict form to allow for individual points to be separated out.
Both ends are inclusive.

If minv is larger than all values in the column, or maxv smaller, will return
    `(nothing,nothing)`.

Arguments:
- `df::DataFrame`: DataFrame to work on.
- `minv::Float64=-Inf`: Minimum value.
- `maxv::Float64=Inf`: Maximum value.
"""
function index_between_vals(df::DataFrame; minv = -Inf, maxv = Inf)
    return Dict(col => (findfirst(x -> minv <= x <= maxv, df[:, col]),
                    findlast(x -> minv <= x <= maxv, df[:, col])) for col in names(df))
end

"""
    df2time(time_col)

Converts a time column in a DataFrame with String elements to time in seconds.

Arguments:
- `time_col::DataFrame`: DataFrame with time values.
"""
function df2time(time_col::DataFrame)
    if typeof(time_col[1, 1]) != String
        # Assume already converted
        return time_col
    end
    time_col = mapcols(col -> Dates.Time.(col, dateformat"H:M:S"), time_col)
    time_col = mapcols(col -> [i.instant.value * (1e-9) for i in col], time_col)
    return time_col
end

"""
    between_times(df,time_col;mint=-Inf,maxt=Inf)

Returns the DataFrame between two timepoints.

Arguments:
- `df::DataFrame`: DataFrame to work on.
- `time_col::DataFrame`: DataFrame of time values.
- `mint::Float64=-Inf`: Minimum time in mins.
- `maxt::Float64=Inf`: Max time in mins.
"""
function between_times(df::DataFrame, time_col::DataFrame; mint = -Inf, maxt = Inf)
    time_col = df2time(time_col)
    # Do time calculations in seconds to avoid floating point math
    tvals = index_between_vals(time_col; minv = mint * 60, maxv = maxt * 60)
    tvals = tvals[names(time_col)[1]]
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

Arguments:
- `df::DataFrame`: DataFrame on which to work.
- `time_col::DataFrame`: Time values in a DataFrame.
- `time_point::Float64`: Time point in mins at which to report the measurement.
"""
function at_time(df::DataFrame, time_col::DataFrame, time_point)
    time_col = df2time(time_col)
    tvals = index_between_vals(time_col; minv = 0, maxv = time_point * 60)
    tvals = tvals[names(time_col)[1]]
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

Arguments:

- `od_df::DataFrame`: The DataFrame you are getting the indexes from.
- `target_df::DataFrame`: The DataFrame you want to get the values from.
- `target_od::Number`: The value at which you are limiting the data to
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
                @warn "Skipping $i as the target OD ($target_od) is higher than the \
                    maximum OD ($(maximum(replace(od_df[:,i],NaN=>0.0))))."
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
