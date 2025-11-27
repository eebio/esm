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
                # Ya dun goofed.
                @warn "Transformation/Group - $j - not found please check your transformation and groups. \n Reminder: Time on plate readers is handled per channel and associated with a specific plate. Please specify the time as: plate_0x_time.channel ."
            end
        end
        # Put it all in the same frame and not a vector
        v_out[i] = hcat(result..., makeunique = true)
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

Recursively converts the parsed equations to julia code and produces the correct dataframes over which to operate. This also calls any unprocessed transformations.

Arguments:
- sexp: Expression or part of expression to be decomposed.
- es: The esm_zones data type that contains the data (global variable).
- trans_meta_map: The transformation map of the parsed transformations.
"""
function sexp_to_nested_list(sexp, es, trans_meta_map)
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
                return sexp
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
