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