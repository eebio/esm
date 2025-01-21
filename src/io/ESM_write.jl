function read_data(filen;ptype="a")
    samples = groupby(DataFrame(XLSX.readtable(filen,"Samples")),:Plate)
    groups = DataFrame(XLSX.readtable(filen,"Groups"))
    trans = DataFrame(XLSX.readtable(filen,"Transformations"))
    views = DataFrame(XLSX.readtable(filen,"Views"))
    sample_dict= OrderedDict()
    group_dict = OrderedDict(i.Group => Dict("sample_IDs" => Vector(split(i.Name,",")), "metadata" => Dict(j => i[j,:] for j in names(i) if !(j in ["Group","Name"]))) for i in eachrow(groups))
    @info "Reading $(length(keys(samples))) plates" 
    for i in range(1,length(keys(samples)))
        data=Dict()
        ins_type=Set(samples[i].Type)
        # print(ins_type)
        try length(ins_type) == 1 catch; error("All experiments on one plate must be from the same instrument types. \nInstrument types used here are: $(Set(samples[i].Type))") end
        # channels = unique(split.(samples[i].Channels,","))[1]
        # print([replace(j.match,"("=>"",")"=>"") for j in eachmatch.(r"\(.+?\)", unique(samples[i].Channels))])#SubString.(unique(samples[i].Channels), findall.(r"\(.+?\)",unique(samples[i].Channels)))])
        # print([[replace((string(k.match)),"("=>"",")"=>"") for k in j] for j in eachmatch.(r"\(.+?\)", unique(samples[i].Channels))]...)#SubString.(unique(samples[i].Channels), findall.(r"\(.+?\)",unique(samples[i].Channels)))])
        if true in [occursin('(',j) for j in unique(samples[i].Channels)]
            channels=unique([filter(s ->!all(isempty,s),unique(split.(samples[i].Channels,r",\(.+?\)"))[1]);[[replace((string(k.match)),"("=>"",")"=>"") for k in j] for j in eachmatch.(r"\(.+?\)", unique(samples[i].Channels))]...])
        else
            channels = unique(split.(samples[i].Channels,","))[1]
        end
        @info "Channels $channels being used to process plate $i"
        broad_g=[]
        if "plate reader" in lowercase.(ins_type)
            sample_dict,broad_g=read_pr(samples[i],sample_dict,channels,broad_g,ptype)
        elseif "flow" in lowercase.(ins_type)
            sample_dict,broad_g=read_flow(samples[i],sample_dict,channels,broad_g)
        else
            error("Unknown instrument type: $ins_type")
        end
        # print(group_dict)
        group_dict["plate_0$i"]=Dict("sample_IDs"=>broad_g,"metadata"=>:autodefined=>"true")
        # group_dict["plate_0$i"]=Dict()
    end
    trans_dict = OrderedDict(i.Name=>"equation"=>i.Equation for i in eachrow(trans))
    views_dict = OrderedDict(i.Name=>:data=>split(i.Groups,",") for i in eachrow(views))
    return OrderedDict(:samples=>sample_dict,:groups=>group_dict,:transformations=>trans_dict,:views=>views_dict)
end

function write_esm(esm_dict)
    open("demo.json", "w") do file
        JSON.print(file, esm_dict, 4)
    end
    @info "ESM written."
end

function read_pr(samples,sample_dict,channels,broad_g,ptype)
    @info "Processing plate reader data from plate $(unique(samples.Plate)[1])"
    loc=unique(samples[!,"Data Location"])
    try length(loc) == 1 catch; error("Please give the location of only one folder containing all the CSVs for one plate. \nLocations given here are: $(Set(samples[!,"Data Location"]))") end
    if length(samples.Plate) == 1
        if length(loc) > 1
            for j in loc
                d2=read_multipr_file("$(loc[j])",ptype,channels)
                for k in channels
                    try names(data[k])==names(d2[k]) catch; @error "Non contiguous columns names used: \nColumns: $(setdiff(names(data[k]),names(d2[k]))) do not match.\n" end
                    data[k]=vcat(data[k],d2[k])
                end
            end
        else
            data=read_multipr_file("$(loc...)",ptype,channels)
        end
        sample_dict=merge(sample_dict,OrderedDict("plate_0$(samples.Plate[1])_$(lowercase(k))" => Dict(:type=>"timeseries",:values => Dict(i=>data[i][!,k] for i in channels)) for k in names(data[channels[2]]) if isvalid(k)))
    else
        data=read_multipr_file("$loc",ptype,channels)
        for j in eachrow(samples)
            if ismissing(j.Name)
                name = "plate_0$(j.Plate)_$(j.Well)"
            else
                name = j.Name
            end
            if !("plate_0$(j.Plate)_time" in keys(sample_dict))
                sample_dict["plate_0$(j.Plate)_time"]=Dict([:values=>Dict(),:type=>"timeseries"])
                sample_dict["plate_0$(j.Plate)_time"][:values]=Dict(x=>data[x][!,"Time"] for x in channels)
            end
            temp = Dict()
            temp[:type]="timeseries"
            temp[:values]=Dict(x=>data[x][!,j.Well] for x in channels)
            sample_dict[name]=temp
            broad_g=[broad_g;[name]]
        end
    end
    return sample_dict, broad_g
end

function read_flow(samples, sample_dict,channels,broad_g)
    @info "Processing flow cytometer data from plate $(unique(samples.Plate)[1])"
    for j in eachrow(samples)
        if ismissing(j.Name)
            name = "plate_0$(j.Plate)_$(j.Well)"
        else
            name = j.Name
        end
        # print(Dict(x=>load(j."Data Location")["$(x)"] for x in channels))
        try 
            temp=Dict()
            temp[:type]="population"
            temp[:values] = Dict(x=>load(j."Data Location")["$(x)"] for x in channels)
            sample_dict[name]=temp

        catch
            # print(j."Data Location")
             warn("\n\nSkipping $name as file $(j[!,"Data Location"]) invalid - check the specified location or if the file is corrupted.")
        end
        broad_g=[broad_g;[name]]
    end
    return sample_dict,broad_g
end

"""
    Function for reading files containing multiple reads from a single CSV file.
    Returns a Dictionary of DataFrames with keys being the channels. 
    Currently works for Agilent (a) and Tecan (t).
"""
function read_multipr_file(filen,ptype,channels)
    o_dict = Dict()
    if ptype=="t"
        i = [j for j in split(read(filen,String),r"\n,+?\n") if (length(j)>1500)]
        o_dict = Dict(match(r"([A-Za-z0-9]+)",j).match =>CSV.read(IOBuffer(j),DataFrame,transpose=true) for j in i if match(r"([A-Za-z0-9]+)",j).match in channels)
    elseif ptype=="a"
        i = [i for i in split(read(filen,String),r"(\r\n.+?\r\n\r\n)") if (length(i) > 8 && (length(i) > 1000 && string(i)[1:7] != "Results"))]
        o_dict=Dict(match(r":([A-Za-z0-9,\[\]]+)",j).match[2:end] => CSV.read(IOBuffer("Time"*split(j,"\nTime")[2]),DataFrame) for j in i if match(r":([A-Za-z0-9,]+)",j).match[2:end] in channels)
    end
    for i in keys(o_dict)
        o_dict[i]=o_dict[i][!,Not(all.(ismissing,eachcol(o_dict[i])))]
    end
    # print(keys(o_dict))
    return o_dict
end

write_esm(read_data("ESM_input_test.xlsx"))