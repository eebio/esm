using KernelDensity, Plots, StatsBase, FileIO, GaussianMixtures, LinearAlgebra, Distributions,DataFrames

function load_fcs(filen::String)
    return load(filen)
end

function to_rfi(fcs;chans=[])
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

function std_curve()
end

function density_gate(data,channels=[],gate_frac=0.65;nbins=1024,outside=false)
    length(channels)==2 || error("2 channels must be specified for density gating.")
    x=data[channels[1]][:data]
    y=data[channels[2]][:data]
    N=length(x)
    # Step 2: Create a 2D histogram (for bin edges reference)
    # hist_bins = (-3:0.2:3, -3:0.2:3)  # Define histogram bins
    hist_counts = fit(Histogram, (x, y); nbins=nbins)  # Compute histogram

    # fraction_to_keep = 0.75  # Keep top 20% of highest density points
    # sorted_indices = sortperm(hist_counts.weights, rev=true,dims=1)
    # top_indices = sorted_indices[1:ceil(Int, fraction_to_keep * N)]
    # x_top = x[top_indices]
    # y_top = y[top_indices]

    # Step 3: Define histogram bin edges
    x_bins = hist_counts.edges[1]
    y_bins = hist_counts.edges[2]
    # print(collect(hist_bins[1]))

    # Step 4: Compute KDE for the data
    kd = kde((x, y))#,bandwidth=(0.1,0.1))  # Use KernelDensity for 2D KDE

    # Step 5: Evaluate the KDE at each data point
    density_values = [pdf(kd, xi, yi) for (xi, yi) in zip(x, y)]
    # density_values = pdf.(kd, x',y) 
    # density_values ./= sum(density_values)
    # print(maximum(density_values))

    # Step 6: Define a threshold and filter points (points inside KDE contour)
    fraction_to_keep = 0.75  # Keep top 20% of highest density points
    sorted_indices = sortperm(density_values, rev=true)
    top_indice = sorted_indices[ceil(Int, fraction_to_keep * N)]
    # print(density_values[top_indice])
    threshold = density_values[top_indice]  # Define a density threshold
    inside_indices = density_values .> threshold  # Points inside the contour
    # print(inside_indices)
    data_inside=stack(data[i][:data] for i in keys(data))
    data_inside=data_inside[inside_indices,:]
    out_df=DataFrame(data_inside,[keys(data)...])
    x_inside = x[inside_indices]
    y_inside = y[inside_indices]
    if outside
    # Step 7: Identify points outside the histogram bins
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

function mef_clust(data, clusters::Int;min_covar=1e-3, cluster_params=missing)
    if isa(data,Vector{Float64})
        data=reshape(data,length(data),1)
    end
    gmm=GMM(size(data)[2],clusters;kind=:full)
    # print(gmm.μ)
    weights=[1/clusters for i in 1:1:8]
    means=[]
    covar=UpperTriangular{Float64,Matrix{Float64}}[UpperTriangular([1:2 1:2]) for i=1:clusters]
    dist=sum((data .- minimum(data,dims=1)).^2.0,dims=2)
    sort_idxs=sortperm(dist,dims=1)
    n_per_cluseter=size(data)[1]/clusters
        # print(size(transpose(data)))
    discard_frac=0.5
    sa=I*min_covar
    for i in range(0,clusters-1)
        il =round(Int,(i+discard_frac/2)*n_per_cluseter,RoundDown)
        ih =round(Int,(i+1-discard_frac/2)*n_per_cluseter,RoundDown)
        sorted_idx_cluster=sort_idxs[il:ih]
        data_cluster=data[sorted_idx_cluster,:]
        print(size(data_cluster))
        # print(typeof(data_cluster),", ")
        cova=[]
        print(mean(data_cluster,dims=1))
       means=[means;[mean(data_cluster,dims=1)...]]
        if size(data,1)==1
            cova = reshape(cov(transpose(data_cluster)), (1,1))
            cova .+= sa(size(data)[2])
        else
            cova = cov(data_cluster) 
            cova += sa(size(data)[2])
        end
        covar[i+1]=UpperTriangular(cova)
    end
    # print(covar,",  ")
    means=vcat(means...)
    if size(data,2)==1
        means=reshape(means,length(means),1)
    end
    print(means)
    # print(typeof(means))
    gmm.μ=means
    gmm.w=weights
    gmm.Σ=covar
    em!(gmm,data; nIter=500)
    # gmm=GMM(8, data; method=:kmeans, kind=:diag, nInit=50, nIter=500, nFinal=500)

    # print(gmm.μ,"\n",gmm.w,"\n",gmm.Σ)
    # print(typeof(covar))
    # gmm=GMM(,,,[],0)#;kind=:full,nIter=0)
    g=MixtureModel(gmm)
    out=fit(g,data)
    plot(out)
    
    # em!(gmm,nIter=500,varfloor=1e-3)

    # gmm=GMM(size(data)[1],size(data)[2];kind=:full)#;kind=:full,nIter=0)
    # GMM(weights,means,covars)
    # if cluster_params!=missing
    #     g=GMM(clusters,d;cluster_params...)
    #     em!(g,data_beads;nInter)
    # else
    #     g=GMM(clusters,d;kind=:full)
    # end
    
end

function to_mef()

end

file = load_fcs("./sample001.fcs")
data_dict=to_rfi(file)
d=density_gate(data_dict,["FSC","SSC"],0.3)
# print(d)
data_m=stack(data_dict[i][:data] for i in keys(data_dict))
mef_clust(d[:,"FL1"],8)
# Step 1: Generate some 2D data
# print([bitstring(i) for i in file.data["FSC-A"]])
# print(file.params)
# m=[m for m in file["TIME"]] 
# print(m)
x = [i for i in file["FSC"]]
y = [i for i in file["SSC"]]  # Introduce some correlation
z = [i for i in file["FL1"]]
print(length(z))
# print(x,y,z)
# print(x)
at=[4.0,1.0]
r=1024#1048576
amp(k)=at[2]*10 ^(at[1]*(k/r))

x=amp.(x)
y=amp.(y)
z=amp.(z)
# print(x[end])
# print(amp([1024],[4.0,1,0],1024))
# print(x)
maxr=amp(1024)
maxr=r
dat_mask=[1 < xi < maxr && 280 < yi < maxr && 1 < zi < maxr for (xi, yi,zi) in zip(x, y,z)]
# print(dat_mask)

x=[xi for (xi, m) in zip(x, dat_mask) if m]
# print(x)
y=[yi for (yi, m) in zip(y, dat_mask) if m]
z=[zi for (zi, m) in zip(z, dat_mask) if m]



GMM(n=n_clusters, d=weights; kind=:full)

N=length(x)
# Step 2: Create a 2D histogram (for bin edges reference)
# hist_bins = (-3:0.2:3, -3:0.2:3)  # Define histogram bins
hist_counts = fit(Histogram, (x, y); nbins=1024)  # Compute histogram

# fraction_to_keep = 0.75  # Keep top 20% of highest density points
# sorted_indices = sortperm(hist_counts.weights, rev=true,dims=1)
# top_indices = sorted_indices[1:ceil(Int, fraction_to_keep * N)]
# x_top = x[top_indices]
# y_top = y[top_indices]

# Step 3: Define histogram bin edges
x_bins = hist_counts.edges[1]
y_bins = hist_counts.edges[2]
hist_bins=(x_bins,y_bins)
# print(collect(hist_bins[1]))

# Step 4: Compute KDE for the data
kd = kde((x, y))#,bandwidth=(0.1,0.1))  # Use KernelDensity for 2D KDE

# Step 5: Evaluate the KDE at each data point
density_values = [pdf(kd, xi, yi) for (xi, yi) in zip(x, y)]
# density_values = pdf.(kd, x',y) 
# density_values ./= sum(density_values)
# print(maximum(density_values))

# Step 6: Define a threshold and filter points (points inside KDE contour)
fraction_to_keep = 0.75  # Keep top 20% of highest density points
sorted_indices = sortperm(density_values, rev=true)
top_indice = sorted_indices[ceil(Int, fraction_to_keep * N)]
# print(density_values[top_indice])
threshold = density_values[top_indice]  # Define a density threshold
inside_indices = density_values .> threshold  # Points inside the contour
# print(inside_indices)
x_inside = x[inside_indices]
y_inside = y[inside_indices]

# Step 7: Identify points outside the histogram bins
inside_bins = (x .>= minimum(x_bins)) .& (x .<= maximum(x_bins)) .& (y .>= minimum(y_bins)) .& (y .<= maximum(y_bins))
x_outside = x[inside_bins]
y_outside = y[inside_bins]



n_cluster=length(mef_vals)


# Step 8: Define a fraction of values to retain inside the KDE contour
# fraction_to_keep = 0.75  # Keep top 20% of highest density points
# sorted_indices = sortperm(density_values, rev=true)
# top_indices = sorted_indices[1:ceil(Int, fraction_to_keep * N)]
# x_top = x[top_indices]
# y_top = y[top_indices]

# Step 9: Plot filtered points and contours
p1=scatter(x_outside, y_outside, label="Points outside KDE contour",xscale=:log10,yscale=:log10, color=:orange, alpha=0.1)
p1=scatter!(x_inside, y_inside, label="Points inside KDE contour (top 75%)", title="Filtered Points Inside KDE Contour",xscale=:log10,yscale=:log10,color=:blue)
ylabel!(p1,"SSC")
xlabel!(p1,"FSC")
plot!(p1,minorgrid=true,legend = :bottomright)
xlims!(1e+0, 1e+4)
ylims!(1e+0, 1e+4)
arr=10.0 .^range(0,4,length=255)
p2=stephist(z,bins=arr,color=:steelblue1, alpha=0.4, xscale=:log10,seriestype=:stephist,label="Ungated")

p2=stephist!(z[inside_indices],bins=arr,xscale=:log10,color=:steelblue1,seriestype=stephist,label="Gated")
xlims!(p2,1e+0, 1e+4)
ylabel!(p2,"Counts")
xlabel!(p2,"FL1")
plot!(p2,minorgrid=true)
l=@layout [p1;p2]
plot(p1,p2,layout=l, size=(600,500))


# Optional: Overlay KDE contour for reference
# contour!(kd.density)


# x_grid = 10 .^ range(0, 4, length=500)  # Logarithmic spacing
# y_grid = 10 .^ range(0, 4, length=500)
# kde_grid_values =  [pdf(kd, yi, xi) for xi in x_grid, yi in y_grid] # KDE over a grid
# print(kde_grid_values)
# contour!(x_grid, y_grid, kde_grid_values, levels=[threshold], color=:red, linewidth=2, label="KDE Contour",xscale=:log10,yscale=:log10)



# Step 10: Plot the points outside the histogram bins


#"#WINEXT" => "0", "\$P3R" => "1048576", "\$BTIM" => "16:45:41", "\$CYTSN" => "2AFC210781115", "\$P4S" => "BL1-A", "\$ENDSTEXT" => "000000000000", "\$P4N" => "BL1-A", "#LASER4DELAY" => "375", "\$TIMESTEP" => "0.001", "#P1TARGET" => "NA", "\$FIL" => "beads.fcs", "#LASER3COLOR" => "Violet", "\$P7F" => "530", "\$P2R" => "1048576", "\$P6S" => "SSC-H", "#WIDTHTHRESHOLD" => "1000", "\$P8V" => "340", "\$CELLS" => "NA", "\$P1E" => "0,0", "#LASER1COLOR" => "Blue", "\$VOL" => "40000", "\$PAR" => "10", "\$P4R" => "1048576", "\$P4L" => "488", "\$P1L" => "NA", "\$SMNO" => "control", "#LASER2ASF" => "1.11", "\$P10E" => "0,0", "\$P10B" => "32", "#LASER1DELAY" => "1100", "\$LAST_MODIFIER" => "crobinson", "\$P9N" => "SSC-W", "\$P6V" => "360", "\$P3E" => "0,0", "\$P10F" => "530", "#TR1" => "AND_FSC,2000", "\$P2B" => "32", "\$LOST" => "0", "\$P2S" => "FSC-A", "\$P3S" => "SSC-A", "\$P5B" => "32", "\$P5S" => "FSC-H", "\$DATE" => "21-Nov-2019", "\$P5E" => "0,0", "\$P7L" => "488", "\$P7N" => "BL1-H", "\$P3L" => "488", "\$NEXTDATA" => "000000000000", "\$P3N" => "SSC-A", "#TR2" => "AND_SSC,1000", "\$P2N" => "FSC-A", "\$P4F" => "530", "\$P2V" => "340", "\$P3B" => "32", "\$ETIM" => "16:46:05", "#LASER1ASF" => "1.08", "\$P10N" => "BL1-W", "\$P9S" => "SSC-W", "\$P1S" => "Time", "\$P7V" => "345", "\$P8N" => "FSC-W", "\$P9E" => "0,0", "\$P1F" => "NA", "\$P6L" => "488", "\$P9V" => "360", "\$P6B" => "32", "\$SYS" => "OPTIXE2 Microsoft Windows 7 Professional ", "\$P3F" => "488", "#LASERCONFIG" => "BRVY", "\$P5F" => "NA", "\$P5N" => "FSC-H", "\$P2F" => "NA", "\$P6N" => "SSC-H", "\$EXP" => "NA", "\$P2E" => "0,0", "#LASER2DELAY" => "1486", "\$P8E" => "0,0", "\$P1B" => "32", "\$TOT" => "14106", "\$P8F" => "NA", "\$OP" => "clare robinson", "\$P6F" => "488", "\$P1N" => "Time", "#LASER3ASF" => "1.05", "#PTDATE" => "21-Nov-2019", "#LASER4COLOR" => "Yellow", "\$P4B" => "32", "\$P7S" => "BL1-H", "\$P7R" => "1048576", "\$P7E" => "0,0", "\$P8R" => "1024", "\$ENDANALYSIS" => "000000000000", "\$P10L" => "488", "\$P4V" => "345", "\$SRC" => "NA", "\$P8B" => "32", "\$CYT" => "4486521 Attune NxT Acoustic Focusing Cytometer (Lasers: BRVY)", "\$P2L" => "488", "\$ORIGINALITY" => "NonDataModified", "\$PLATENAME" => "2019_11_21_consGFP", "\$SPILLOVER" => "3,BL1-A,BL1-H,BL1-W,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000", "\$P5R" => "1048576", "\$INST" => "NA", "\$P3V" => "360", "#LASER3DELAY" => "756", "\$P5L" => "488", "\$P6E" => "0,0", "\$P7B" => "32", "\$P10R" => "1024", "\$P8S" => "FSC-W", "#LASER2COLOR" => "Red", "\$P9B" => "32", "#LASER4ASF" => "1.05", "#P1LABEL" => "NA", "\$P1R" => "67108864", "\$PROJ" => "2019_11_21_consGFP", "\$P10S" => "BL1-W", "\$P5V" => "340", "#FLOWRATE" => "100", "\$P6R" => "1048576", "\$ENDDATA" => "000000572431", "\$BYTEORD" => "1,2,3,4", "\$P10V" => "345", "\$DATATYPE" => "F", "\$P8L" => "488", "\$BEGINSTEXT" => "000000000000", "\$P4E" => "0,0", "\$P9R" => "1024", "\$LAST_MODIFIED" => "25-Nov-2019 09:28:47", "\$P1V" => "NA", "\$P9F" => "488", "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      " => "", "#PTRESULT" => "Pass", "\$BEGINDATA" => "000000008192", "" => "10", "\$P9L" => "488", "\$BEGINANALYSIS" => "000000000000", "\$COM" => "NA", "\$MODE" => "L")