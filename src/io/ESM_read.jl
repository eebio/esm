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
                    # print(filter_col(eval(sexp_to_nested_list(trans_meta_map[Symbol(string(sexp.args[1]))],es,trans_meta_map)),[string(sexp.args[2].value)]))
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
    # show(df)
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
        samples=DataFrame([(lowercase(i), j, ef["samples"][i]["type"],ef["samples"][i]["values"][j],if !isempty(keys(ef["samples"][i]["meta"])) ef["samples"][i]["meta"][j] else ef["samples"][i]["meta"] end,[i in lowercase.(ef["groups"][k]["sample_IDs"]) for k in keys(ef["groups"])]...) for i in keys(ef["samples"]) for j in keys(ef["samples"][i]["values"])],["name","channel","type","values","meta",[k for k in keys(ef["groups"])]...]),#DataFrame(ef["samples"]),
        groups=DataFrame([(i,lowercase.(ef["groups"][i]["sample_IDs"]),ef["groups"][i]["metadata"],:(filter(row -> row.name in ef["groups"][i]["sample_IDs"], samples, view=true))) for i in keys(ef["groups"])],["group","sample_IDs","metadata","meta_select"]),
        transformations=ef["transformations"],
        views=ef["views"]
    )
    es.samples.name = string.(es.samples.name,".",es.samples.channel)
    @info "ESM file successfully read."
    return es
end

mean(df::DataFrame) = return reduce(+, eachcol(df)) ./ ncol(df)

hcat(x...) = return hcat(x)

vcat(x...) = return vcat(x)

groupby_flo(df::DataFrame) = return 

function process_fcs(group,gate_channels,out_channels;es=es,rfi=true,denisty=true,high_low=true)
    data=filter_row(es.samples,group)
    for i in es.groups["group"]
    if rfi
        data=to_rfi()
    end
    end

end

function to_rfi(fcs;chans=[],es=es)
    if chans==[]
        chans=[fcs.params[i.match] for i in eachmatch(r"\$P[0-9]+?N",join(keys(fcs.params)))]
    end
    at=Dict(fcs.params["\$P$(filter(isdigit,i.match))N"]=> parse.(Float64,split(fcs.params[i.match],",")) for i in eachmatch(r"\$P[0-9]+?E",join(keys(fcs.params))))
    if length(at)!=length(chans)
        error("Some amplification types not specfied data will not process.")
    end
    if length([eachmatch(r"\$P[0-9]+?R",join(keys(fcs.params)))...]) >= length(chans)
        ran=Dict(fcs.params["\$P$(filter(isdigit,i.match))N"]=> parse(Int,fcs.params[i.match]) for i in eachmatch(r"\$P[0-9]+?R",join(keys(fcs.params))))
    else
        ran=false
    end
    if length([eachmatch(r"\$P[0-9]+?G",join(keys(fcs.params)))...]) >= length(chans)
        ag=Dict(fcs.params["\$P$(filter(isdigit,i.match))N"]=> parse(Int,fcs.params[i.match]) for i in eachmatch(r"\$P[0-9]+?G",join(keys(fcs.params))))
    else
        ag = false
    end
    o=Dict()
    for i in chans
        if at[i][1]==0
            if ag==false
                o[i]=Dict(:data=>fcs[i]./1,:min=>[1/1,:max=>ran[i]/1])
            else
                o[i]=Dict(:data=>fcs[i]./ag[i],:min=>1/ag[i],:max=>ran[i]/ag[i])
            end
        else
            try ran catch; error("Resolution must be specified") end
            o[i]=Dict(:data=>at[i][2]*10 .^(at[i][1]*(fcs[i]/ran[i])),:min=>at[i][2]*10 ^(at[i][1]*(1/ran[i])),:max=>at[i][2]*10 ^(at[i][1]*(ran[i]/ran[i])))
        end
    end
    return o
end

function high_low(data;chans=[],maxr=missing,minr=missing)
    if chans == []
        chans = keys(data)
    end
    for i in keys(data)
        if i in chans
            if maxi == missing && maxr == missing
                try
                    dat_mask=[data[i][:range][1] < j < data[i][:range][2] for j in data[i][:data]]
                    data[i][:data]=[xi for (xi,m) in zip(data[1][:data], dat_mask) if m]
                catch
                    error("Range missing, please specify.")
                end
            else
                dat_mask=[minr < j < maxr for j in data[i][:data]]
                data[i][:data]=[xi for (xi,m) in zip(data[1][:data], dat_mask) if m]
            end
        end
    end
    return data
end

function density_gate(data,channels=[],gate_frac=0.65;nbins=1024,outside=false)
    length(channels)==2 || error("2 channels must be specified for density gating.")
    x=data[channels[1]][:data]
    y=data[channels[2]][:data]
    N=length(x)

    hist_counts = fit(Histogram, (x, y); nbins=nbins) 


    x_bins = hist_counts.edges[1]
    y_bins = hist_counts.edges[2]

    kd = kde((x, y))

    density_values = [pdf(kd, xi, yi) for (xi, yi) in zip(x, y)]

    fraction_to_keep = 0.75  
    sorted_indices = sortperm(density_values, rev=true)
    top_indice = sorted_indices[ceil(Int, fraction_to_keep * N)]

    threshold = density_values[top_indice]
    inside_indices = density_values .> threshold

    data_inside=stack(data[i][:data] for i in keys(data))
    data_inside=data_inside[inside_indices,:]
    out_df=DataFrame(data_inside,[keys(data)...])
    x_inside = x[inside_indices]
    y_inside = y[inside_indices]
    if outside
        inside_bins = (x .>= minimum(x_bins)) .& (x .<= maximum(x_bins)) .& (y .>= minimum(y_bins)) .& (y .<= maximum(y_bins))
        x_outside = x[inside_bins]
        y_outside = y[inside_bins]
        return (x_inside, y_inside), (x_outside,y_outside)
    else 
        return out_df
    end
end

function cluster_beads(data_beads,mef_vals::Vector{Int},mef_chans::Vector{String};clust_chans=[],cluster_f=to_mef,cluster_params=Dict(),stat=median,stat_func=Dict(),selection_func=std,selection_func_params=Dict(),fitfunc=std_curve,fitfunc_params=Dict())
    if clust_chans==[]
        clust_chans=mef_chans
    end

    clusters=length(mef_vals)
    clust_vals=mef_clust(data_beads[clust_chans],clusters,cluster_params)
    u_clust_vals=unique(clust_vals)
    pops = [data_beads[clust_vals==i] for i in u_clust_vals]

end


es = read_esm("./demo.json")
trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
@info "Producing views."
views = prod_v(es,trans_meta_map)
for i in keys(views)
    show(views[i])
    display(plot(views[i][15:end,"plate_01_time.flo"],[views[i][15:end,j] for j in names(views[i]) if j != "plate_01_time.flo"];legend=false))
    # plot(stack(views[i]))
end
# for i in keys(es.models)
#     show(mod_in(i))
# end