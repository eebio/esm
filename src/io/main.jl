
"""
    esm(action; view, file_name, output_dir)

Writes an output file to 
"""
@main function esm(action;view::String,file_name::String,output_dir::String)
    if action == "create"
        x=read_data(file_name)
        write_esm(x)
    elseif action == "produce"
        es = read_esm(file_name)
        trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
        @info "Producing views."
        view_to_csv(es,trans_meta_map;outdir=output_dir,to_out=[view])
    elseif action == "template"
        cp(pathof("eebiotools"*"src/ESM.xlsx"),output_dir)
    elseif action == "process"
        es = read_esm(file_name)
        trans_meta_map = Dict(Symbol(i) => Meta.parse(es.transformations[i]["equation"]) for i in keys(es.transformations))
        @info "Producing views."
        view_to_csv(es,trans_meta_map;outdir=output_dir)
    end
end
# function main(inp_file=false, esm_file=false, wcmd=false, auto=false, update=false,verbosity=0)
#     i=false
#     if inp_file == false
#         @info "Input file missing - switching to command line mode."
#         wcmd=true
#     end
#     if wcmd != false
#         while i != true
#             prim_check = readline("Would you like to:\na. Write a new ESM file.\nb. Update an existing ESM file")
#             if lower(string(prim_check)) == "a"
#                 print("Please choose input option: \n1. Excel input\n2. Commandline input \n")
#                 inp = readline(">")
#             elseif lower(string(prim_check)) == "b"

#             end
#             if lowercase(inp) in ["q","quit","end","exit"]
#                 i= true
#             end
#         end
#     end
# end

# function plate_reader_inp()
# end

# function flow_cyt_inp()
# end

# """Update an existing ESM document"""
# function esm_update()
# end

# """Generate the standard esm excel document"""
# function esm_excel_generate()
# end

# function sdfs()
# end

# """spits out an excel document for mapping a plate."""
# function platemap()
# end

# """Checks the group names and sample IDs are correct. If incorrect spits out an warning indicating the closest matching id to the failed one."""
# function sampgroupcheck()
# end