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
    elseif isa(sexp, String)
        return sexp
    else
        print(sexp)
        error("Unexpected type: $(typeof(sexp))")
    end
end

function prod_v(es,trans_meta_map;to_out=[])
    if to_out==[]
        to_out=keys(es.views)
    end
    v_out=Dict()
    for i in to_out
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

function view_to_csv(es,trans_meta_map;outdir="",to_out=[])
    vs = prod_v(es,trans_meta_map;to_out=to_out)
    for i in keys(vs)
        @info "Writing view: $i to $outdir/$i.csv"
        CSV.write("$outdir/$i.csv",vs[i])
    end
    @info "Views written successfully."
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

# Base.hcat(x...) = return hcat(x)

vcat(x...) = return vcat(x)

# function at_time_point(x,y)
    
# end

# gr(x...) = log2(at_time_point)

# function growth_rate(x)
#     gr
# end

# calibration_curve()

groupby_flo(df::DataFrame) = return 

function process_fcs(group::String,gate_channels::Vector,out_channels::Vector{String};gate_frac=0.65,nbins=1024,hl_channels=[],rfi=true,dense=true,hl=true,maxr=missing,minr=missing)
    out_data=[]
    max_len=maximum([length(es.samples.values[map(x -> !isnothing(match(Regex(string(i*raw"\.")), x)), es.samples.name),:][1]) for i in es.groups.sample_IDs[es.groups.group.==group,:][1]])
    @info "Processing flow cytometer data in :$group."
    @showprogress for i in es.groups.sample_IDs[es.groups.group.==group,:][1]
        if rfi
            o=to_rfi(i)
        end
        if hl
            o=high_low(o;chans=hl_channels,maxr=maxr,minr=minr)
        end
        try (rfi == false && hl == false) catch; error("Data must go through initial gating, please set rfi or hl to true.") end
        if dense
            df=density_gate(o,gate_channels;gate_frac=gate_frac,nbins=nbins)
            # print([j=>i*"."*j for j in names(df) if j in out_channels])
            df=rename!(df[:,out_channels],[j=>i*"."*j for j in names(df) if j in out_channels])
            out_data=[out_data;append!(df,DataFrame([names(df)[j]=>[0 for i in range(1,max_len-nrow(df))] for j in range(1,length(out_channels))]))]
        else
            data_inside=stack(o[i][:data] for i in keys(o))
            df=DataFrame(data_inside,[keys(o)...])
            out_data=[out_data;append(rename!(df[:,out_channels],[j=>i*"."*j for j in names(df) if j in out_channels]),DataFrame([names(df)[j]=>[i for i in range(1,max_len-nrow(df))] for j in range(1,length(out_channels))]))]
        end
        # print([names(j) for j in out_data])
    end
    CSV.write("flo_test.csv",filter(row -> any(!=(0), row),hcat(out_data...)))
    return filter(row -> any(!=(0), row),hcat(out_data...))
end

function to_rfi(sample_name;chans=[])
    sub=es.samples[map(x -> !isnothing(match(Regex(string(sample_name*raw"\.")), x)), es.samples.name),:]
    if chans == []
        chans=sub.channel
    end
    at=Dict(i=> parse.(Float64,split(sub[sub.name.=="$sample_name.$i","meta"][1]["amp_type"],",")) for i in chans)
    if length(at)!=length(chans)
        error("Some amplification types not specfied data will not process.")
    end
    if !(false in ["range" in keys(sub.meta[sub.name.=="$sample_name.$i",:][1]) for i in chans])#length([eachmatch(r"\$P[0-9]+?R",join(keys(fcs.params)))...]) >= length(chans)
        ran=Dict(i=> parse(Int,sub.meta[sub.name.=="$sample_name.$i",:][1]["range"]) for i in chans)
    else
        ran=false
    end
    if !(false in ["amp_gain" in keys(sub.meta[sub.name.=="$sample_name.$i",:][1]) && sub.meta[sub.name.=="$sample_name.$i",:][1]["amp_gain"] != nothing for i in chans])
        ag=Dict(i=> parse(Int,sub.meta[sub.name.=="$sample_name.$i",:][1]["amp_gain"]) for i in chans)
    else
        ag = false
    end
    o=Dict()
    for i in chans
        if at[i][1]==0
            if ag==false
                o[i]=Dict(:data=>sub.values[sub.name.=="$sample_name.$i",:][1]./1,:min=>1/1,:max=>ran[i]/1)
            else
                o[i]=Dict(:data=>sub.values[sub.name.=="$sample_name.$i",:][1]./ag[i],:min=>1/ag[i],:max=>ran[i]/ag[i])
            end
        else
            try ran catch; error("Resolution must be specified") end
            o[i]=Dict(:data=>at[i][2]*10 .^(at[i][1]*(sub.values[sub.name.=="$sample_name.$i",:][1]/ran[i])),:min=>at[i][2]*10 ^(at[i][1]*(1/ran[i])),:max=>at[i][2]*10 ^(at[i][1]*(ran[i]/ran[i])))
        end
    end
    return o
end

function high_low(data;chans=[],maxr=missing,minr=missing)
    if !ismissing(maxr) && !ismissing(minr) && (length(chans) >= 1)
        @warn "Processing flow data and limiting more than one channel ($(chans...)) by the same value."
    end
    if chans == []
        chans = keys(data)
    end
    dat_mask=[]
    for i in keys(data)
        if i in chans
            if ismissing(minr) && ismissing(maxr)
                # print([dat_mask;[data[i][:min] < j < data[i][:max] for j in data[i][:data]]])
                dat_mask=[dat_mask;[data[i][:min] < j < data[i][:max] for j in data[i][:data]]]
            else
                dat_mask=[dat_mask;[minr < j < maxr for j in data[i][:data]]]
            end
        end
    end
    dat_mask=hcat(dat_mask)
    dat_m =[if any(col) end for col in eachcol(dat_mask)]
    for i in keys(data)
        data[i][:data]=[xi for (xi,m) in zip(data[i][:data], dat_mask) if m]
    end
    return data
end

function density_gate(data,channels=[];gate_frac=0.65,nbins=1024,outside=false)
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


es = read_esm("./out.esm")
trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
@info "Producing views."
view_to_csv(es,trans_meta_map;outdir="./test",to_out=["flow_cy"])
# for i in keys(views)
#     show(views[i])
#     display(plot(views[i][15:end,"plate_01_time.flo"],[views[i][15:end,j] for j in names(views[i]) if j != "plate_01_time.flo"];legend=false))
#     # plot(stack(views[i]))
# end
# for i in keys(es.models)
#     show(mod_in(i))
# end