using Plots
using PDFmerger
using Combinatorics

"""
    summary(file, ptype::AbstractESMDataType; plot=false)

Summarise a data file (.esm, plate reader, .fcs, etc.).

# Arguments
- `file::AbstractString`: The data file to be summarised.
- `ptype::AbstractESMDataType`: The type of data file.
- `plot::Bool=false`: Produce plots of the data. Defaults to false.
"""
function Base.summary(file::AbstractString, ::ESMData; plot = false)
    println("")
    # Print a summary of the contents
    @info "Summary of ESM file: $file"
    # Read the esm file
    es = read_esm(file)
    # Summarise samples
    @info "Summarising samples"
    # Number of timeseries and populations
    @info "Number of timeseries: $(sum(es.samples[!,"type"].=="timeseries"))"
    @info "Number of populations: $(sum(es.samples[!,"type"].=="population"))"
    @info "Available channels are: $(unique(es.samples[!,"channel"]))"

    println("")
    # Summarise groups
    @info "Summarising groups"
    @info "Number of groups: $(nrow(es.groups))"
    count = sum("autodefined" .∉ keys.(es.groups[!, "metadata"]))
    @info "Number of manually defined groups: $count"
    count = (sum(["autodefined" ∈ keys(es.groups[i, "metadata"]) &&
                  es.groups[i, "metadata"]["autodefined"] == "true"
                  for i in eachindex(es.groups[!, "metadata"])]))
    @info "Number of autodefined groups (such as for plates): $count"
    group_sizes = Dict(i["group"] => length(i["sample_IDs"]) for i in eachrow(es.groups))
    for (key, value) in group_sizes
        isautodefined = "autodefined" ∈
                        keys(first(es.groups[es.groups[!, "group"] .== key, "metadata"]))
        @info "Group $key has size $value and is$(isautodefined ? " not" : "") autodefined."
    end

    println("")
    # Summarise transformations
    @info "Summarising transformations"
    @info "Number of transformations: $(length(es.transformations))"
    for (key, value) in es.transformations
        @info "Transformation $key: $(value["equation"])"
    end

    println("")
    # Summarise views
    @info "Summarising views"
    @info "Number of views: $(length(es.views))"
    for (key, value) in es.views
        @info "View $key: $(value["data"])"
    end

    if plot
        # Plot all timeseries
        @info "Plotting timeseries data"
        # TODO need to know the times for all samples automatically
        dir = mktempdir()
        for r in eachrow(es.samples)
            if r.type == "timeseries"
                p = Plots.plot(r.values,
                    xlabel = "Time (#units missing#)", ylabel = "Value",
                    title = "Timeseries for $(string(r.name))")
                savefig(p, joinpath(dir, string(r.name) * ".pdf"))
            end
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, string(file) * ".pdf")
    end
end

function Base.summary(file::AbstractString, ptype::AbstractPlateReader; plot = false)
    println("")
    @info "Summary of $(typeof(ptype)) file: $file"
    out = read(file, ptype)
    println("")
    # Summarise channels
    @info "Summarising channels"
    @info "Number of channels: $(length(keys(out)))"
    for (key, value) in out
        @info "Channel $key: $(nrow(value)) timepoints and $(ncol(value) - 1) samples."
        @info "Timepoints range from $(value[1, 1]) to $(value[end, 1])."
    end

    if plot
        # Plot all timeseries
        @info "Plotting timeseries data"
        # TODO need to know the times for all samples automatically
        dir = mktempdir()
        for (key, value) in out
            for col in names(value)[2:end]
                p = Plots.plot(value[!, 1], value[!, col],
                    xlabel = "Time (#units missing#)", ylabel = "Value",
                    title = "Timeseries for $col: Channel $key")
                savefig(p, joinpath(dir, string(col) * string(key) * ".pdf"))
            end
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, string(file) * ".pdf")
    end
end

function Base.summary(file::AbstractString, ::FlowCytometryData; plot = false)
    println("")
    @info "Summary of FCS file: $file"
    f = load(file)
    @show f
    println("")
    # Summarise channels
    @info "Summarising channels"
    @info "Number of channels: $(length(keys(f)) - 1)" # Exclude the "Time" key
    for key in keys(f)
        if key == "Time"
            continue
        end
        esm_channel = replace(key, "-" => "_")
        @info "Channel $esm_channel: $(length(f[key])) events."
        @info "Values range from $(minimum(f[key])) to $(maximum(f[key]))."
    end
    @info "Time ranges from $(minimum(f["Time"])) to $(maximum(f["Time"])) with \
        $(length(f["Time"])) timepoints."

    if plot
        @info "Plotting FCS data"
        dir = mktempdir()
        channels = [c for c in keys(f) if c != "Time"]
        for c in channels
            p = histogram(f[ESM.flow_channel(c)],
                xlabel = "$c", ylabel = "Count")
            savefig(p, joinpath(dir, string(c) * ".pdf"))
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, string(file) * ".pdf")
        dir = mktempdir()
        for (c1, c2) in combinations(channels, 2)
            p = histogram2d(f[ESM.flow_channel(c1)], f[ESM.flow_channel(c2)],
                xlabel = "$c1", ylabel = "$c2")
            savefig(p, joinpath(dir, string(c1) * string(c2) * ".pdf"))
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, joinpath(dir, "temp.pdf"))
        append_pdf!(string(file) * ".pdf", joinpath(dir, "temp.pdf"))
    end
end
