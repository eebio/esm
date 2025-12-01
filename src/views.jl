using CSV
using DataFrames

"""
    produce_views(es, trans_meta_map;to_out=[])

Produces the subset of views specified in `to_out` or all views if unspecified.

Arguments:
- `es::esm_zones`: The esm_zones object (global)
- `trans_meta_map::Dict`: A dictionary mapping transformations to their names.
- `to_out::Vector{String}`: A list of all the views to be produced.
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
            elseif j in es.groups.group
                # If its a group, put the basal data in the results array
                push!(result, form_df(filter_row(es, Symbol(j))))
            elseif j in es.samples.name
                # If its a sample, create the df and push it
                push!(result, form_df(es.samples[es.samples.name .== j, :]))
            else
                error("View $i = $j is not a sample, group or transformation")
            end
        end
        # Put it all in the same frame and not a vector
        if any(isa.(result, AbstractVecOrMat)) || any(isa.(result, Number))
            v_out[i] = Tables.table(hcat(result...))
        else
            v_out[i] = hcat(result..., makeunique = true)
        end
    end
    @info "Views produced."
    return v_out
end

"""
    view_to_csv(es,trans_meta_map;out_dir,to_out)

Produces views and writes them to CSV files.

Arguments:
- `es::esm_zones`: The original esm struct
- `trans_meta_map::Dict`: The transformations that have been parsed at the top level.
- `outdir::String`: The specified output dir - defaults to nothing.
- `to_out::Vector{String}`: The views to be processed.
"""
function view_to_csv(es, trans_meta_map; outdir = "", to_out = [])
    # Process the views
    vs = produce_views(es, trans_meta_map; to_out = to_out)
    # Write the views to file
    for i in keys(vs)
        @info "Writing view: $i to $(joinpath(outdir,i*".csv"))"
        CSV.write("$(joinpath(outdir,i*".csv"))", vs[i])
    end
    @info "Views written successfully."
end

"""
    sexp_to_nested_list(sexp,es,trans_meta_map)

Recursively converts the parsed equations to julia code and produces the correct dataframes
    over which to operate. This also calls any unprocessed transformations.

Arguments:
- sexp: Expression or part of expression to be decomposed.
- es: The esm_zones data type that contains the data (global variable).
- trans_meta_map: The transformation map of the parsed transformations.
"""
function sexp_to_nested_list(sexp, es, trans_meta_map)
    if isa(sexp, Symbol)
        if sexp in keys(trans_meta_map)
            # Is the symbol a transformation
            # TODO Needs circular referencing of transformations adjusted
            return sexp_to_nested_list(trans_meta_map[sexp], es, trans_meta_map)
        elseif string(sexp) in es.groups.group
            # Is the symbol a group?
            return ESM.form_df(ESM.filter_row(es, sexp))
        elseif string(sexp) in first.(splitext.(es.samples.name))
            # Is the symbol a sample?
            return ESM.form_df(es.samples[string(sexp) .== first.(splitext.(es.samples.name)), :])
        end
        # Just return it - its something else
        return sexp
    end
    if isa(sexp, Expr)
        # Check if the symbol is an expression as this could mean further processing
        for i in eachindex(sexp.args)
            # Recursively process each argument of the expression
            sexp.args[i] = sexp_to_nested_list(sexp.args[i], es, trans_meta_map)
        end
        if sexp.head == :.
            # If there is a dot expression, this could be a channel access
            channel = sexp.args[end]
            if channel isa QuoteNode
                channel = channel.value
            end
            if channel isa Symbol && length(sexp.args) == 2
                channel = string(channel)
                # Want to make sure this isn't some other dot expression
                if any(last.(splitext.(es.samples.name)) .== ".$channel")
                    # This is channel access
                    return ESM.filter_channel(sexp.args[1], channel)
                end
            end
        end
        # Just return the expression as is now its processed
        return sexp
    end
    # Not a symbol or expression - return as is
    return sexp
end
