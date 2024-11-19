using DataFrames, FileIO
"""
    asscMetadata

Data structure that holds all the non-well associated data.
"""
mutable struct asscMetadat
    instrument_type::String
    instrument_name::String
    plate_n::Int
    channels::Dict{String,Array{float}}
    time_date::["plate_$(i)"=>"" for i in range(1,plate_n)]
    user::String
    experiment_type::String
    plate_type::Int
    sample_type::String
    cover_type::String
    filen::Array{String}
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
    exit()
end

@main function main(filen)
    f=read_metadata(filen)
    if lowercase(f.instrument_type) in ["plate reader","plate readers","plate_reader"]
        for i in range(1,len(f.filen))
            f.raw_data["plate_$i"]=read_csv(f.filen[i])
        end
    else
        read_fcs(f)
    end
end