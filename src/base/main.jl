using DataFrames, FileIO
"""
    asscMetadata

Data structure that holds all the non-well associated data.
"""
@with_kw struct asscMetadata
    instrument_type::Vector{String}
    instrument_name::Vector{String}
    plate_n::Vector{Int}
    channels::Vector{String}
    time_date::Vector{String}
    user::Vector{String}
    experiment_type::Vector{String}
    plate_type::Vector{Int}
    sample_type::Vector{String}
    cover_type::Vector{String}
    filen::Vector{String}
    plate_map::Any
end

"""
    well_group

Structure that contains the data associated with one well group.
"""
struct well_group
    media::String
    Antibiotics::Array{String}
    Inducers::Array{String}
    Description::String
    wells::Dict{String,Array{String}}
    out_data::Dict{String,Array{Array{float}}}
end

"""
    leave(throw)

Defines the exit behaviour of the program.

Arguments:
- `throw`: `Bool` - defines the print behaviour of the exit function, with false indicating normal behaviour and True indicating an error.

Returns:
- `nothing` 
"""
function leave(throw)
    if throw
        println("Error occurred - please see printed statements and retry.")
    else
        println("All files processed and converted succesfully.")
    end
    #exit()
end

function gen_meta(data_dict,f)
    metad_dict = Dict(fieldnames(asscMetadata) .=> getfield.(Ref(f), fieldnames(asscMetadata)))
    for i in keys(data_dict)
        for j in keys(metad_dict)
            if j !=:data_map
                metadata!(data_dict[i],String(j),metad_dict[j])
            end
        end
    end
    return data_dict
end

function col_meta()
    
end


@main function main(filen)
    ext = splitext(basename(filen))[2]
    if ext==".xlsx"
        xd=read_excel(filen)
        write_conv(xd)
        filen="config.json"
        f=read_metadata(filen)
    else 
        f=read_metadata(filen)
    end
    if lowercase(f.instrument_type[1]) in ["plate reader","plate readers","plate_reader"]
        data_dict=read_csv(f)
    else
        data_dict=read_fcs(f)
        write_out(f,data_dict)
        # write_conv([DataFrame(Tables.table(f)),data_dict],data_dict,keys(data_dict))
        data_dict=gen_meta(data_dict,f)
        print(DataFrames.metadata(data_dict["BL1-H"]))
        write_json(data_dict)
    end
end