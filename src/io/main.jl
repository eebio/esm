function main(inp_file=false, esm_file=false, wcmd=false, auto=false, update=false,verbosity=0)
    i=false
    if inp_file == false
        @info "Input file missing - switching to command line mode."
        wcmd=true
    end
    if wcmd != false
        while i != true
            prim_check = readline("Would you like to:\na. Write a new ESM file.\nb. Update an existing ESM file")
            if lower(string(prim_check)) == "a"
                print("Please choose input option: \n1. Excel input\n2. Commandline input \n")
                inp = readline(">")
            elseif lower(string(prim_check)) == "b"

            end
            if lowercase(inp) in ["q","quit","end","exit"]
                i= true
            end
        end
    end
end

function plate_reader_inp()
end

function flow_cyt_inp()
end

"""Update an existing ESM document"""
function esm_update()
end

"""Generate the standard esm excel document"""
function esm_excel_generate()
end

function sdfs()
end

"""spits out an excel document for mapping a plate."""
function platemap()
end

"""Checks the group names and sample IDs are correct. If incorrect spits out an warning indicating the closest matching id to the failed one."""
function sampgroupcheck()
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
        o_dict=Dict(match(r":([A-Za-z0-9,]+)",j).match[2:end] => CSV.read(IOBuffer("Time"*split(j,"\nTime")[2]),DataFrame) for j in i if match(r":([A-Za-z0-9,]+)",j).match[2:end] in channels)
    end
    for i in keys(o_dict)
        o_dict[i]=o_dict[i][!,Not(all.(ismissing,eachcol(o_dict[i])))]
    end
    return o_dict
end