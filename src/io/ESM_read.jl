@with_kw struct esm_zones
    samples::DataFrame
    groups
    transformations
    views
end

function sexp_to_nested_list(sexp::Any,es,trans_meta_map)
    if isa(sexp, Symbol)
        
        if isdefined(eebiotools,sexp)
            return sexp
        end
        if sexp in keys(trans_meta_map) ### Needs circular referencing of transformations adjusted.
            return eval(sexp_to_nested_list(trans_meta_map[sexp],es,trans_meta_map))
        end
        if string(sexp) in es.groups.group
            return form_df(filter_row(es,sexp)) 
        else
            return sexp
        end
    elseif isa(sexp, Expr)
        result = []
        if true in [isa(i,QuoteNode) for i in sexp.args] 
            if isa(sexp.args[1],Expr)
                return sexp_to_nested_list(sexp,es,trans_meta_map)
            elseif Symbol(string(sexp.args[1])) in keys(trans_meta_map)
                if  string(sexp.args[2].value) in es.groups.group
                    return filter_col(eval(sexp_to_nested_list(trans_meta_map[Symbol(string(sexp.args[1]))],es,trans_meta_map)),find_group(es,string(sexp.args[2].value)))
                else
                    print(filter_col(eval(sexp_to_nested_list(trans_meta_map[Symbol(string(sexp.args[1]))],es,trans_meta_map)),[string(sexp.args[2].value)]))
                    return remove_subcols(filter_col(eval(sexp_to_nested_list(trans_meta_map[Symbol(string(sexp.args[1]))],es,trans_meta_map)),[string(sexp.args[2].value)]),sexp.args[2].value)
                end
            else
                if  string(sexp.args[2].value) in es.groups.group
                    return filter_col(form_df(filter_row(es,sexp.args[1])),find_group(es,string(sexp.args[2].value)))
                else
                    return remove_subcols(filter_col(form_df(filter_row(es,sexp.args[1])),[sexp.args[2].value]),sexp.args[2].value) 
                end
            end
        else
            for arg in sexp.args
                push!(result, sexp_to_nested_list(arg,es,trans_meta_map))
            end
        end
        return Expr(sexp.head, result...)
    elseif isa(sexp, LineNumberNode)
        return []
    elseif isa(sexp, QuoteNode)
        return sexp_to_nested_list(sexp.value,es,trans_meta_map)
    elseif isa(sexp, Number)
        return sexp
    else
        error("Unexpected type: $(typeof(sexp))")
    end
end

function prod_v(es,trans_meta_map)
    v_out=Dict()
    for i in keys(es.views)
        @info "Producing view $i."
        result = []
        for j in es.views[i]["data"]
            if Symbol(j) in keys(trans_meta_map)
                push!(result,eval(sexp_to_nested_list(trans_meta_map[Symbol(j)],es,trans_meta_map)))
            elseif Symbol(j) in es.groups.group
                push!(result,form_df(filter_row(es,Symbol(j))))
            elseif j in es.samples.name
                push!(result,form_df(es.samples[es.samples.name .== j,:]))
            else
                @warn "Transformation/Group - $j - not found please check your transformation and groups. \n Reminder: Time on plate readers is handled per channel and associated with a specific plate. Please specify the time as: plate_0x_time.channel ."
            end
        end
        try 
            v_out[i]=hcat(result...)
        catch 
            @warn "Duplicate labels detected, left DataFrame denoted with _1 right denoted with _2.\n"
            v_out[i]=hcat(result...,makeunique=true)
        end 
    end
    @info "Views produced."
    return v_out
end

function remove_subcols(df,sub)
    rename!(s -> replace(s,Regex("."*string(sub))=>""),df)
    return df
end

function filter_row(es,group)
    return es.samples[es.samples[!,group] .== true,:]
end

function filter_col(df,reg_l)
    return df[:,filter(colname -> occursin((Regex(join(string.(reg_l),"|"))), string(colname)), names(df))]
end

function form_df(df)
    max_dat = maximum(length.(df.values))
    return hcat([DataFrame(j.name=>[j.values;fill(missing,max_dat-length(j.values))]) for j in eachrow(df)]...)
end

function find_group(es,grn)
    return es.groups[es.groups.group .== grn,:sample_IDs][1]
end

function read_esm(filen)
    @info "Reading ESM file at: $filen"
    ef = JSON.parsefile(filen)
    max_len=0
    for i in keys(ef["samples"])
        for j in keys(ef["samples"][i]["values"])
            k = length(ef["samples"][i]["values"][j])
            if k>max_len
                max_len = k
            end
        end
    end
    es = esm_zones(
        samples=DataFrame([(i, j, ef["samples"][i]["type"],ef["samples"][i]["values"][j], [i in ef["groups"][k]["sample_IDs"] for k in keys(ef["groups"])]...) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values",[k for k in keys(ef["groups"])]...]),#DataFrame(ef["samples"]),
        groups=DataFrame([(i,ef["groups"][i]["sample_IDs"],ef["groups"][i]["metadata"],:(filter(row -> row.name in ef["groups"][i]["sample_IDs"], samples, view=true))) for i in keys(ef["groups"])],["group","sample_IDs","metadata","meta_select"]),
        transformations=ef["transformations"],
        views=ef["views"]
    )
    es.samples.name = string.(es.samples.name,".",es.samples.channel)
    @info "ESM file successfully read."
    trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
    @info "Producing views."
    views = prod_v(es,trans_meta_map)
    for i in keys(views)
        show(views[i])
    end
    return 0
end

mean(df::DataFrame) = return reduce(+, eachcol(df)) ./ ncol(df)

hcat(x...) = return hcat(x)

vcat(x...) = return vcat(x)

groupby_flo(df::DataFrame) = return 

function density_gate(df,channels,bins=1024,gate_fraction,sigma,verbose)
    if len length(channels)!=2
        @error "Please send two channels for density gating."
    end
    hist = fit(Histogram,(df[:,channels[1]],df[:,channels[2]]);nbins=bins)
end
#y=fit(Histogram, (x["FSC-A"],x["SSC-A"]),nbins=1024)
#d= imfilter(y.weights,centered(Kernel.gaussian(0.65)))
# D= d/sum(d)
# o= reverse(sortperm(vec(D)))
#p=vec(y.weights)[o]
#k=cumsum(p)
#ids = [i for i in k if i >= 0]
# acc = o[ids]
# g=vec(zeros(size(y.weights)))
# g[acc] = true
# reshape(g,size(y))

function process_pr(samples,blank,odchannel, flochannel,verbose)

end

### Needs standards curve creation, 
function bead_calibrate()
end

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

read_esm("./demo.json")