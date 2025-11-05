using Plots
using PDFmerger
using Combinatorics

"""
    summarise_esm(file)

Summarises the contents of an esm file.

Args:

- `file::String`: The path to the esm file to be summarised.
- `plot::Bool`: Whether to plot the timeseries data.
"""
function summarise_esm(file; plot = false)
    # Read the esm file
    es = read_esm(file)

    println("")
    # Print a summary of the contents
    @info "Summary of ESM file: $file"
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
    @info "Number of manually defined groups: $(sum("autodefined" .∉ keys.(es.groups[!,"metadata"])))"
    @info "Number of autodefined groups (such as for plates): $(sum([
        "autodefined" ∈ keys(es.groups[i,"metadata"]) &&
        es.groups[i,"metadata"]["autodefined"]=="true"
        for i in eachindex(es.groups[!,"metadata"])]))"
    group_sizes = Dict(i["group"] => length(i["sample_IDs"]) for i in eachrow(es.groups))
    for (key, value) in sort(group_sizes)
        @info "Group $key has size $value and is$("autodefined" ∉ keys(first(es.groups[es.groups[!, "group"] .== key, "metadata"])) ? " not" : "") autodefined."
    end

    println("")
    # Summarise transformations
    @info "Summarising transformations"
    @info "Number of transformations: $(length(es.transformations))"
    for (key, value) in sort(es.transformations)
        @info "Transformation $key: $(value["equation"])"
    end

    println("")
    # Summarise views
    @info "Summarising views"
    @info "Number of views: $(length(es.views))"
    for (key, value) in sort(es.views)
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

"""
    summarise_spectramax(file)

Summarises a SpectraMax output file.

Args:

- `file::String`: Path to the SpectraMax file.
- `plot::Bool`: Whether to plot the data.
"""
function summarise_spectramax(file; plot = false)
    f = read_into_lines(file)
    containsTime = [occursin(r"\d\d:\d\d:\d\d", j) ? 1 : 0 for j in f]
    function runlength(a, i)
        if i == length(a)
            return 1
        elseif a[i] == 1
            return runlength(a, i + 1) + 1
        else
            return 0
        end
    end
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Find and push header onto table (first row before i that contains Time and the row above it)
        for j in (i - 1):-1:1
            if occursin("Time", f[j])
                push!(table, f[j - 1])
                push!(table, f[j])
                break
            end
        end
        # Find and push the data onto table
        for j in i:length(f)
            if containsTime[j] == 1
                push!(table, f[j])
            else
                break
            end
        end
        push!(data, table)
    end
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        tmp = split(data[i][1], "\t")
        channel = strip(tmp[6] == "Fluorescence" ? tmp[14] : tmp[13])
        # Get the data
        df = CSV.read(IOBuffer(join(data[i][2:end], "\n")), DataFrame, delim = "\t")
        temp_name = names(df)[2]
        rename!(df, temp_name => "temperature")
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        # Remove empty columns
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Do I need to drop temperature?)
        out[channel] = df
    end

    @info "Summary of SpectraMax file: $file"
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

"""
    summarise_biotek(file)
Summarises a Biotek output file.

Args:

- `file::String`: Path to the Biotek file.
- `plot::Bool`: Whether to plot the data.
"""
function summarise_biotek(file; plot = false)
    f = read_into_lines(file)
    containsTime = [occursin(r"\d{1,2}:\d\d:\d\d", j) ? 1 : 0 for j in f]
    function runlength(a, i)
        if i == length(a)
            return 1
        elseif a[i] == 1
            return runlength(a, i + 1) + 1
        else
            return 0
        end
    end
    rl = [runlength(containsTime, i) for i in eachindex(containsTime)]
    datalocations = findall(x -> x == maximum(rl), rl)
    # Trim the data to only the relevant parts
    data = []
    for i in datalocations
        table = []
        # Find and push header onto table (first row before i that contains Time and the row above it)
        for j in (i - 1):-1:1
            if occursin("Time", f[j])
                push!(table, f[j - 2])
                push!(table, f[j])
                break
            end
        end
        # Find and push the data onto table
        for j in i:length(f)
            if containsTime[j] == 1
                push!(table, f[j])
            else
                break
            end
        end
        push!(data, table)
    end
    # Create the dataframes
    out = Dict()
    for i in eachindex(data)
        channel = strip(split(data[i][1], ":")[end])
        # Remove channel name from the first row
        data[i][2] = replace(data[i][2], " $(data[i][1])" => "")
        # Read the data into a DataFrame
        df = CSV.read(IOBuffer(join(data[i][2:end], "\n")), DataFrame)
        temp_name = names(df)[2]
        rename!(df, temp_name => "temperature")
        time_name = names(df)[1]
        rename!(df, time_name => "time")
        # Remove empty columns
        df = df[:, Not(all.(ismissing, eachcol(df)))]
        # Do I need to drop temperature?)
        out[channel] = df
    end

    @info "Summary of BioTek file: $file"
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

function summarise_fcs(file; plot = false)
    f = load(file)
    @info "Summary of FCS file: $file"
    @show f
    println("")
    # Summarise channels
    @info "Summarising channels"
    @info "Number of channels: $(length(keys(f)) - 1)" # Exclude the "Time" key
    for key in keys(f)
        if key == "Time"
            continue
        end
        @info "Channel $key: $(length(f[key])) events."
        @info "Values range from $(minimum(f[key])) to $(maximum(f[key]))."
    end
    @info "Time ranges from $(minimum(f["Time"])) to $(maximum(f["Time"])) with $(length(f["Time"])) timepoints."

    if plot
        @info "Plotting FCS data"
        dir = mktempdir()
        channels = [c for c in keys(f) if c != "Time"]
        for c in channels
            p = histogram(f[c],
                xlabel = "$c", ylabel = "Count")
            savefig(p, joinpath(dir, string(c) * ".pdf"))
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, string(file) * ".pdf")
        dir = mktempdir()
        for (c1, c2) in combinations(channels, 2)
            p = histogram2d(f[c1], f[c2],
                xlabel = "$c1", ylabel = "$c2")
            savefig(p, joinpath(dir, string(c1) * string(c2) * ".pdf"))
        end
        filepaths = [joinpath(dir, f) for f in readdir(dir) if endswith(f, ".pdf")]
        merge_pdfs(filepaths, joinpath(dir, "temp.pdf"))
        append_pdf!(string(file) * ".pdf", joinpath(dir, "temp.pdf"))
    end
end
