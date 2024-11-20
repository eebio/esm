"""
    read_fcs(filen)

Reads a set of FCS files into a DataFrame and checks if it is a valid file path.

Arguments: 
- `filen`: `Array{String}` - type corresponding to the path at which the file(s) can be found.

Returns: 
- `file` - `DataFrame` type of read data
"""
function read_fcs(metad)
    try
        output_channels=Dict(keys(metad.channels) .=>[DataFrame() for i in 1:length(keys(metad.channels))])
        for pl in range(1,length(metad.filen))
            fcs = [fcs for fcs in readdir("$(metad.filen[pl])") if fcs[length(fcs)-2:length(fcs)]=="fcs"]
            for channel in keys(metad.channels)
                data=Dict(["$(i)$(k)_$(pl)" for i in ["A","B","C","D","E","F","G","H"] for k in range(1,12)][1:length(fcs)] .=> [load("$(metad.filen[pl])/$i")["$(channel)"] for i in fcs])
                maxy=maximum([length(i) for i in values(data)])
                df=DataFrame(["t"=>[missing for i in range(1,maxy)]])
                for i in keys(data)
                    if maxy >= length(data)
                        b=[missing for i in range(1,maxy - length(data[i]))]
                        df=hcat(df,DataFrame([i=>[data[i].:data;b]]))
                    else
                        df=hcat(df,DataFrane([i=>[data[i].:data;b]]))
                    end
                end
                output_channels[channel]=hcat(output_channels[channel],df)
            end
        end
        return output_channels
    catch
        print("The path you have entered: $(metad.filen) does not correspond to a file path containing valid FCS files. \n\n Exiting - please retry.")
        leave(true)
    end
end

"""
    read_csv(file)

Reads a CSV file into a DataFrame and checks if it is a valid file.

Arguments: 
- `filen`: `string` - type corresponding to the path at which the file can be found.

Returns: 
- `file` - `DataFrame` type of read data
"""
function read_csv(filen) 
    try 
        output_channels=Dict(metad.channels.=>DataFrame())
        for pl in range(1,length(metad.filen))
            for channel in metad.channels
                output_channels[channel]=hact(output_channels[channel], CSV.read(filen,DataFrame))
            end
            output_channels[channel]=hcat(output_channels[channel],df)
        end
        return output_channels
    catch
        print("The path you have entered: $(metad.filen) does not correspond to a CSV file. \n\n Exiting - please retry.")
        leave(true)
    end
end

"""
    read_metadata(file)

Extracts the metadata from a file for future processing. 

Agruments: 
- `filen`: `String` -  type corresponding to the read file from the read() function.

Returns:
- ``
"""
function read_metadata(filen)
    jfile = JSON.parsefile(filen)
    try
        fmet = asscMetadata(instrument_type=jfile["instrument_type"],
                            instrument_name=jfile["instrument_name"],
                            plate_n=jfile["plate_n"],
                            channels=jfile["channels"],
                            time_date=jfile["time_date"],
                            user=jfile["user"],
                            experiment_type=jfile["experiment_type"],
                            plate_type=jfile["plate_type"],
                            sample_type=jfile["sample_type"],
                            cover_type=jfile["cover_type"],
                            filen=jfile["filen"],
                            data_map=jfile["data_map"]
                            )
        return fmet
    catch 
        print("The path you have entered: $(filen) does not correspond to a JSON file or this file is not formatted correctly. \n\n Exiting - please retry.")
        leave(true)
    end
end

function write_json(data_dict)
    write("output.json", objecttable(data_dict["BL1-H"]))
end