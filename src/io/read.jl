"""
    asscMetadata

Data structure that holds all the non-well associated data.
"""
struct asscMetadata
    instrument_type::String
    instrument_name::String
    plate_n::Int
    optics::Dict{String,Array{Float}}
    time_date::Dict{String:String}
    user::Dict{String:String}
    experiment_type::String
    plate_type::Int
    sample_type::string
    cover_type::String
    index::Array{Float}
    chamber_temp::Array{Float}
    filen::Array{String}

    """
        read_metadata(file)

    Extracts the metadata from a file for future processing. 

    Agruments: 
    - `file`: `DataFrame` - DataFrame type corresponding to the read file from the read() function.

    Returns:
    - ``
    """
    function asscMetadata(filen)
        
    end
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
    out_data::Dict{String,Array{Array{Float}}}
end


"""
    read_fcs(filen)

Reads a set of FCS files into a DataFrame and checks if it is a valid file path.

Arguments: 
- `filen`: `string` - type corresponding to the path at which the file(s) can be found.

Returns: 
- `file` - `DataFrame` type of read data
"""
function read_fcs()
    try
        
    catch
        print("The path you have entered: $(filen) does not correspond to a file path containing valid FCS files. \n\n Exiting - please retry.")
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
        file = CSV.read(filen,DataFrame)
        return file
    catch
        print("The path you have entered: $(filen) does not correspond to a CSV file. \n\n Exiting - please retry.")
        leave(true)
    end
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

function main()

end