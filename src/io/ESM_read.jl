@with_kw struct esm_zones
    samples::DataFrame
    groups
    transformations
    views
end

struct group

end

function transformation(eq_list,es)
    for i in eq_list
        x = Meta.parse(i)
        
    end
end

function sexp_to_nested_list(sexp::Any)
    if isa(sexp, Symbol)
        return [string(sexp)]
    elseif isa(sexp, Expr)
        # Handle mathematical operations
        result = []
        for arg in sexp.args
            push!(result, sexp_to_nested_list(arg))
        end
        return result
    elseif isa(sexp, LineNumberNode)
        # Handle LineNumberNode by skipping it or returning an empty list
        return []
    elseif isa(sexp, QuoteNode)
        # Handle functions (QuoteNode) by extracting the quoted value
        return sexp_to_nested_list(sexp.value)
    else
        error("Unexpected type: $(typeof(sexp))")
    end
end

function parse_and_evaluate_expression(expr_str, mapping, df)
    expr = Meta.parse(expr_str)
    print(expr.args)
    
    for (symbol, sub_df) in mapping
        # Ensure symbol is a Symbol
        if !isa(symbol, Symbol)
            error("Mapping keys must be Symbols")
        end
        
        # Ensure sub_df is a SubDataFrame
        if !(sub_df isa SubDataFrame)
            error("Mapping values must be SubDataFrames")
        end
        # print(symbol,"\n", sub_df)
        sub_df.name = string.(sub_df.name,".",sub_df.channel)
        print(sub_df)
        # print(sub_df.name)
        expr.args = replace(expr.args, symbol => DataFrame(sub_df.values,sub_df.name))
    end
    # Evaluate the expression
    return eval(expr)
end

function read_esm(filen)
    ef = JSON.parsefile(filen)
    es = esm_zones(
        samples=DataFrame([(i, j, ef["samples"][i]["type"],ef["samples"][i]["values"][j]) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values"]),#DataFrame(ef["samples"]),
        groups=DataFrame([(i,ef["groups"][i]["sample_IDs"],ef["groups"][i]["metadata"],:(filter(row -> row.name in ef["groups"][i]["sample_IDs"], samples, view=true))) for i in keys(ef["groups"])],["group","sample_IDs","metadata","meta_select"]),
        transformations=ef["transformations"],
        views=ef["views"]
    )
    print(es.groups.sample_IDs)
    all_sub= ["$j.$i" for i in Set(es.samples.channel) for j in es.groups.group]
    all_sub=[all_sub;es.groups.group]
    print(all_sub)
    group_map=Dict(Symbol(i)=> 
                        if occursin(".",i) 
                            filter(row -> row.name in ef["groups"][split(i,".")[1]]["sample_IDs"], es.samples[es.samples.channel .== split(i,".")[2],:], view=true) 
                        else 
                            filter(row -> row.name in ef["groups"][split(i,".")[1]]["sample_IDs"], es.samples, view=true) 
                        end
                        for i in all_sub)
    print(keys(group_map))
    # print(group_map)
    # print(group_map[:sample_LB])
    result=parse_and_evaluate_expression(es.transformations["flo per_OD_LB"]["equation"][1], group_map, es.samples)
    print(result)
    # print(filter(row -> row.group in [String(Meta.parse(es.transformations["flo per_OD_LB"]["equation"][1]).args[1].args[2])], es.groups, view=true)[!,"sample_IDs"])
    # print(filter(row -> row.name in filter(row -> row.group in [String(Meta.parse(es.transformations["flo per_OD_LB"]["equation"][1]).args[1].args[2])], es.groups, view=true)[!,"sample_IDs"][1], es.samples, view=true))
    x=Meta.parse(es.transformations["flo per_OD_LB"]["equation"][1])
    # print(es.samples)
    return x
    # filter(row -> row.name in ef["groups"][i]["sample_IDs"]
end

read_esm("./ESM_proto.json")