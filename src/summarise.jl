using Plots
using Printf
using Plots.PlotMeasures
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

function Base.summary(file::AbstractString, ptype::AbstractPlateReader; plot = false, csv = false)
    function ms2hmsms(ms)
        h = floor(Int, ms / 3600000)
        ms -= h * 3600000
        m = floor(Int, ms / 60000)
        ms -= m * 60000
        s = floor(Int, ms / 1000)
        ms -= s * 1000
        return @sprintf("%02d:%02d:%02d.%03d", h, m, s, ms)
    end
    println("")
    @info "Summary of $(typeof(ptype)) file: $file"
    out = read(file, ptype)
    println("")
    # Summarise channels
    @info "Summarising channels"
    @info "Number of channels: $(length(keys(out)))"
    for (key, value) in out
        @info "Channel $key: $(nrow(value)) timepoints and $(ncol(value) - 1) samples."
        @info "Timepoints range from $(ms2hmsms(value[1,1])) to $(ms2hmsms(value[end, 1]))."
    end

    if plot
        # Plot all timeseries in a single multipanel plot with 12 columns
        @info "Plotting timeseries data"
        dir = mktempdir()
        for (key, value) in out
            time = value[:, 1]/60000
            data = value[:, Not(1, 2)]

            # Multipanel plot with 12 columns
            nplots = ncol(data)
            ncols = min(nplots, 12)
            nrows = ceil(Int, nplots / 12)
            for scale in [:identity, :log10]
                plt = Plots.plot(
                    layout = (nrows, ncols), size = (150 * ncols, 150 * nrows), link = :both,
                    plot_title = "Multipanel timeseries for:\nChannel - $key, Scale - $(scale == :identity ? "Linear" : "Log10")")
                if scale == :log10
                    max_data = 10^ceil(log10(maximum(Matrix(data)) * 1.05))
                    min_data = 10^floor(log10(minimum(Matrix(data)) * 0.95))
                end
                if scale == :identity
                    max_data = maximum(Matrix(data)) * 1.05
                    min_data = 0.0
                end
                for row in 1:nrows, col in 1:ncols
                    # Determine subplot position
                    idx = (row - 1) * ncols + col
                    if idx > nplots
                        plot!(plt, subplot = idx, framestyle = :none)
                        continue
                    end
                    show_xticklabels = row == nrows
                    show_yticklabels = col == 1
                    plot!(plt, time, data[!, idx], subplot = idx,
                        title = names(data)[idx], label = nothing,
                        xformatter = show_xticklabels ? :auto : (x->""),
                        yformatter = show_yticklabels ? :auto : (y->""),
                        xrotation = 60,
                        xlabel = show_xticklabels ? "Time (min)" : nothing,
                        ylims = (min_data, max_data),
                        bottom_margin = show_xticklabels ? 7mm : :match,
                        linewidth = 2.0, colour = :black, yscale = scale)
                end
                savefig(plt, joinpath(dir, string(key) * "_" * string(scale) * "_multipanel.pdf"))

                # Single panel plot
                plt = Plots.plot(xlabel = "Time (min)",
                    title = "Overlaid timeseries for:\nChannel - $key, Scale - $(scale == :identity ? "Linear" : "Log10")")
                for i in 1:nplots
                    plot!(plt, time, data[!, i], label = nothing, linewidth = 2.0, alpha = 0.5,
                    yscale = scale)
                end
                savefig(plt, joinpath(dir, string(key) * "_" * string(scale) * "_singlepanel.pdf"))
            end
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, string(file) * ".pdf")
    end

    if csv
        @info "Saving plate reader data as CSV files"
        for (key, value) in out
            @info "Saving channel $key as CSV file"
            CSV.write(string(file) * "_" * string(key) * ".csv", value)
        end
    end
end

function Base.summary(file::AbstractString, ::FlowCytometryData; plot = false, csv = false)
    println("")
    @info "Summary of FCS file: $file"
    f = load(file)
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
        $(length(f["Time"])) timepoints. Accessed through channel: time"

    if plot
        @info "Plotting FCS data"
        dir = mktempdir()
        channels = [c for c in keys(f) if c != "Time"]
        for c in channels
            p = histogram(f[ESM.flow_channel(c)],
                xlabel = "$c", ylabel = "Count")
            savefig(p, joinpath(dir, string(c) * ".pdf"))
            p = scatter(f["Time"], f[ESM.flow_channel(c)],
                xlabel = "Time", ylabel = "$c", marker = :auto)
            savefig(p, joinpath(dir, string(c) * "_time.pdf"))
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

    if csv
        @info "Saving FCS data as CSV file"
        df = DataFrame(Dict(key => f[key] for key in keys(f)))
        CSV.write(string(file) * ".csv", df)
    end
end
