function read_data(filen)
    samples = groupby(DataFrame(XLSX.readtable(filen,"Samples")),:Plate)
    groups = DataFrame(XLSX.readtable(filen,"Groups"))
    trans = DataFrame(XLSX.readtable(filen,"Transformations"))
    views = DataFrame(XLSX.readtable(filen,"Views"))
    sample_dict=Dict()
    group_dict = Dict(i.Group => Dict("sample_IDs" => Vector(split(i.Name,",")), "metadata" => Dict(j => i[j,:] for j in names(i) if !(j in ["Group","Name"]))) for i in eachrow(groups))
    for i in range(1,length(keys(samples)))
        data=Dict()
        ins_type=Set(samples[i].Type)
        try length(ins_type) == 1 catch; error("All experiments on one plate must be from the same instrument types. \nInstrument types used here are: $(Set(samples[i].Type))") end
        if "plate reader" in lowercase.(ins_type)
            loc=unique(samples[i][!,"Data Location"])
            try length(loc) == 1 catch; error("Please give the location of only one folder containing all the CSVs for one plate. \nLocations given here are: $(Set(samples[i][!,"Data Location"]))") end
            channels = unique(split.(samples[i].Channels,","))[1]
            for j in channels
                data[j]=CSV.read("$(loc...)/$j.tsv",DataFrame)
            end
            broad_g=[]
            for j in eachrow(samples[i])
                if ismissing(j.Name)
                    name = "plate_0$(j.Plate)_$(j.Well)"
                else
                    name = j.Name
                end
                # print(typeof(j.Well))
                temp=Dict(x=>data[x][!,j.Well] for x in channels)
                temp["Time"]=data[channels[1]][!,"Time"]
                sample_dict[name]="values"=>temp
                # sample_dict[name]["values"]["Time"]=#;[]
                # print(sample_dict)
                # push!(sample_dict[name]["values"],Dict())
                broad_g=[broad_g;[name]]
            end
        elseif lowercase(ins_type) == "flow"
            for j in eachrow(samples[i])
                if ismissing(j.Name)
                    name = "plate_0$(j.Plate)_$(j.Well)"
                else
                    name = j.Name
                end
                try sample_dict[name]=[x=>load(samples[i][!,"Data Location"])["$(x)"] for x in channels] catch; warn("Skipping $name as file invalid - check the specified location or if the file is corrupted.") end
            end
        else
            error("Unknown instrument type: $ins_type")
        end
        # print(group_dict)
        group_dict["plate_0$i"]=Dict("sample_IDs"=>broad_g,"meatadata"=>:autodefined=>"true")
        # group_dict["plate_0$i"]=Dict()
    end
    trans_dict = [i.Name=>i.Equation for i in eachrow(trans)]
    views_dict = [i.Name=>[:data=>split(i.Groups,",")] for i in eachrow(views)]
    return Dict(:samples=>sample_dict,:groups=>group_dict,:transformations=>trans_dict,:views=>views_dict)
end

function write_esm(esm_dict)
    open("out.json", "w") do file
        JSON.print(file, esm_dict, 4)
    end
end

write_esm(read_data("ESM_input_test.xlsx"))