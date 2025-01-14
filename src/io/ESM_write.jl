function read_data(filen)
    samples = groupby(DataFrame(XLSX.readtable(filen,"Samples")),:Plate)
    groups = DataFrame(XLSX.readtable(filen,"Groups"))
    trans = DataFrame(XLSX.readtable(filen,"Transformations"))
    views = DataFrame(XLSX.readtable(filen,"Views"))
    sample_dict= OrderedDict()
    group_dict = OrderedDict(i.Group => Dict("sample_IDs" => Vector(split(i.Name,",")), "metadata" => Dict(j => i[j,:] for j in names(i) if !(j in ["Group","Name"]))) for i in eachrow(groups))
    for i in range(1,length(keys(samples)))
        data=Dict()
        ins_type=Set(samples[i].Type)
        # print(ins_type)
        try length(ins_type) == 1 catch; error("All experiments on one plate must be from the same instrument types. \nInstrument types used here are: $(Set(samples[i].Type))") end
        channels = unique(split.(samples[i].Channels,","))[1]
        broad_g=[]
        if "plate reader" in lowercase.(ins_type)
            loc=unique(samples[i][!,"Data Location"])
            try length(loc) == 1 catch; error("Please give the location of only one folder containing all the CSVs for one plate. \nLocations given here are: $(Set(samples[i][!,"Data Location"]))") end
            for j in channels
                data[j]=CSV.read("$(loc...)/$j.tsv",DataFrame)
            end
            for j in eachrow(samples[i])
                if ismissing(j.Name)
                    name = "plate_0$(j.Plate)_$(j.Well)"
                else
                    name = j.Name
                end
                if !("plate_0$(j.Plate)_time" in keys(sample_dict))
                    sample_dict["plate_0$(j.Plate)_time"]=Dict([:values=>Dict(),:type=>"timeseries"])
                    sample_dict["plate_0$(j.Plate)_time"][:values]=Dict(x=>data[x][!,"Time"] for x in channels)
                end
                # print(typeof(j.Well))
                temp = Dict()
                temp[:type]="timeseries"
                temp[:values]=Dict(x=>data[x][!,j.Well] for x in channels)
                sample_dict[name]=temp
                # sample_dict[name]="values"=>temp
                # sample_dict[name]["values"]["Time"]=#;[]
                # print(sample_dict)
                # push!(sample_dict[name]["values"],Dict())
                broad_g=[broad_g;[name]]
            end
            # sample_dict["plate_0$(unique(samples[i].Plate[1][1]))_time"]=Dict([:values=>Dict(),:type=>"timeseries"])
            # sample_dict["plate_0$(unique(samples[i].Plate[1][1]))_time"][:values]=Dict(x=>data[channels[1]][!,"Time"] for x in channels)
        elseif "flow" in lowercase.(ins_type)
            for j in eachrow(samples[i])
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
                     @warn "\n\nSkipping $name as file $(j[i][!,"Data Location"]) invalid - check the specified location or if the file is corrupted." 
                end

                broad_g=[broad_g;[name]]
            end
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
    open("out.json", "w") do file
        JSON.print(file, esm_dict, 4)
    end
end

write_esm(read_data("ESM_input_test.xlsx"))