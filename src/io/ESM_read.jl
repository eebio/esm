@with_kw struct esm_zones
    samples::DataFrame
    groups
    transformations
    views
end

function sexp_to_nested_list(sexp::Any,group_map,samples,trans_meta_map)
    print(sexp)
    if isa(sexp, Symbol)
        if isdefined(eebiotools,sexp)
            return sexp
        end
        if sexp in keys(trans_meta_map)
            return eval(sexp_to_nested_list(trans_meta_map[sexp],group_map,samples,trans_meta_map))
        end
        if sexp in keys(group_map)
            regex_pattern = r".Time"
            return group_map[sexp][:, setdiff(names(group_map[sexp]),filter(colname -> occursin(regex_pattern, string(colname)), names(group_map[sexp])))]
        else
            return sexp
        end
    elseif isa(sexp, Expr)
        # Handle mathematical operations
        result = []
        if true in [isa(i,QuoteNode) for i in sexp.args] ####### Edit to allow for x.y.z to specify subsets of larger groups
            if isa(sep.args[1],Expr)
                return sexp_to_nested_list(sexp,group_map,samples,trans_meta_map) ############### Pick up here - you are trying to return a list of all the quote nodes and the names of the columns in them. This can then be used to isolate and view the the data you want from the main dataframe.
            end
            if Symbol(string(sexp.args[1],".", sexp.args[2].value)) in keys(group_map)
                return group_map[Symbol(string(sexp.args[1],".", sexp.args[2].value))]
            elseif Symbol(string(sexp.args[1])) in keys(trans_meta_map)
                regex_pattern=Regex(string(sexp.args[2].value))
                return trans_meta_map[Symbol(string(sexp.args[1]))][:,names(filter(colname -> occursin(regex_pattern, string(colname)), names(trans_meta_map[sexp])))]
            end
        # elseif sexp.head == :. 
        #     print(sexp.args[1].args,"hi")
        else
            for arg in sexp.args
                push!(result, sexp_to_nested_list(arg,group_map,samples,trans_meta_map))
            end
        end
        return Expr(sexp.head, result...)
    elseif isa(sexp, LineNumberNode)
        # Handle LineNumberNode by skipping it or returning an empty list
        return []
    elseif isa(sexp, QuoteNode)
        # Handle functions (QuoteNode) by extracting the quoted value
        return sexp_to_nested_list(sexp.value,group_map,samples,trans_meta_map)
    elseif isa(sexp, Number)
        return sexp
    else
        error("Unexpected type: $(typeof(sexp))")
    end
end

function prod_v(es,trans_meta_map,group_map)
    v_out=Dict()
    for i in keys(es.views)
        print(i)
        result = []
        for j in es.views[i]["data"]
            if Symbol(j) in keys(trans_meta_map)
                push!(result,eval(sexp_to_nested_list(trans_meta_map[Symbol(j)],group_map,es.samples,trans_meta_map)))
            elseif Symbol(j) in keys(group_map)
                push!(result,group_map[Symbol(j)])
            end
        end
        try 
            v_out[i]=hcat(result...)
        catch 
            warn("Duplicate labels detected, left DataFrame denoted with _1 right denoted with _2.\n")
            v_out[i]=hcat(result...,makeunique=true)
        end 
    end
    return v_out
end

function dark_read_esm(filen)
    ef = JSON.parsefile(filen)
    pre=DataFrame([(i, j, ef["samples"][i]["type"],ef["samples"][i]["values"][j]) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values"])
    # print(DataFrame([(i, j, ef["samples"][i]["type"],ef["samples"][i]["values"][j]) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values"]))
    max_dat = maximum(length.(pre.values))
    pre2=DataFrame(hcat([DataFrame(string(i.name,".",i.channel)=>vcat(i.values,fill(missing,max_dat-length(i.values)))) for i in eachrow(pre)]...))
    es = esm_zones(
        samples=pre2,#DataFrame(ef["samples"]),
        groups=Dict(Symbol(i)=>@view pre[!,filter(col -> match(Regex(join(ef["groups"][i]["sample_IDs"], "|")), col) !== nothing, names(pre2))] for i in keys(ef["groups"])),#DataFrame([(i,ef["groups"][i]["sample_IDs"],ef["groups"][i]["metadata"]) for i in keys(ef["groups"])],["group","sample_IDs","metadata"]),
        transformations=ef["transformations"],
        views=ef["views"]
    )
    print(es.groups)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
    # print(trans_meta_map)
    # print(dump(trans_meta_map[:model]))
    # print(eval(sexp_to_nested_list(trans_meta_map[:flo_per_OD_LB],es.groups,es.samples,trans_meta_map)))
    # print(prod_v(es,trans_meta_map,group_map))
    # print(trans_meta_map)

    # print(x)
    # print(eval(x))
    return 0
end


function read_esm(filen)
    ef = JSON.parsefile(filen)
    es = esm_zones(
        samples=DataFrame([(i, j, ef["samples"][i]["type"],ef["samples"][i]["values"][j]) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values"]),#DataFrame(ef["samples"]),
        groups=DataFrame([(i,ef["groups"][i]["sample_IDs"],ef["groups"][i]["metadata"],:(filter(row -> row.name in ef["groups"][i]["sample_IDs"], samples, view=true))) for i in keys(ef["groups"])],["group","sample_IDs","metadata","meta_select"]),
        transformations=ef["transformations"],
        views=ef["views"]
    )
    es.samples.name = string.(es.samples.name,".",es.samples.channel)
    max_dat = maximum(length.(es.samples.values))
    # print(x)
    all_sub= ["$j.$i" for i in Set(es.samples.channel) for j in es.groups.group]
    all_sub=[all_sub;es.groups.group]
    # print(es.samples)
    group_map=Dict(Symbol(i)=> 
                        if occursin(".",i) 
                            hcat([DataFrame(j.name=>[j.values;fill(missing,max_dat-length(j.values))]) for j in eachrow(filter(row -> split(row.name,".")[1] in ef["groups"][split(i,".")[1]]["sample_IDs"], es.samples[es.samples.channel .== split(i,".")[2],:]))]...)
                        else 
                            hcat([DataFrame(
                                j.name=>[j.values;fill(missing,max_dat-length(j.values))]) for j in 
                                eachrow(filter(row -> split(row.name,".")[1] in ef["groups"][split(i,".")[1]]["sample_IDs"], es.samples))]...)
                        end
                        for i in all_sub)
    # print(group_map)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
    # print(trans_meta_map)
    # print(dump(trans_meta_map[:model]))
    # print(sexp_to_nested_list(trans_meta_map[:model],group_map,es.samples,trans_meta_map))
    # print(prod_v(es,trans_meta_map,group_map))
    # print(trans_meta_map)

    # print(x)
    # print(eval(x))
    return 0
end

mean(df::DataFrame) = return reduce(+, eachcol(df)) ./ ncol(df)

function model(x...)
    print(x)
end

function landscape(x...)
end

function fit_param(x...)
end

function composable(x...)
end

function spatial(x...)
end

# function model(df)
# std(df::DataFrame)

dark_read_esm("./ESM_proto_pr.json")