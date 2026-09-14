import REPL
using REPL.TerminalMenus
using REPL.LineEdit
using REPL.Terminals

function read_with_editing(prompt_text::String)
    term = REPL.Terminals.TTYTerminal(get(ENV, "TERM", "dumb"), stdin, stdout, stderr)

    p = LineEdit.Prompt(prompt_text;
        prompt_prefix="",
        prompt_suffix="",
        on_enter=s -> true,
        complete=LineEdit.EmptyCompletionProvider(),
    )

    buf, ok, _ = LineEdit.prompt!(term, LineEdit.ModalInterface([p]))
    return ok ? String(take!(copy(buf))) : ""
end

function main_menu(esm, changes_made)
    main_options = ["Transforms", "Groups", "Views", "Save Changes"]
    menu = RadioMenu(main_options)
    choice = request("Main Menu (press [q] to quit):", menu)
    if choice == -1
        return quit(esm, changes_made)
    elseif main_options[choice] == "Transforms"
        # Transforms
        return transforms_menu(esm, changes_made)
    elseif main_options[choice] == "Save Changes"
        # Groups
        return save_esm(esm, changes_made; exit_on_success = false)
    end
end

function transforms_menu(esm, changes_made)
    transform_options = ["Test Transform", "Add Transform", "Remove Transform", "Edit Transform",  "Back"]
    menu = RadioMenu(transform_options)
    choice = request("Main Menu / Transforms (press [q] to quit):", menu)
    if choice == -1
        # Quit
        quit(esm, changes_made)
    elseif transform_options[choice] == "Test Transform"
        # Test Transform
        return test_transform(esm, changes_made)
    elseif transform_options[choice] == "Back"
        # Back to main menu
        return main_menu(esm, changes_made)
    elseif transform_options[choice] == "Add Transform"
        # Add Transform
        return add_transform!(esm, changes_made)
    elseif transform_options[choice] == "Remove Transform"
        # Remove Transform
        return remove_transform!(esm, changes_made)
    elseif transform_options[choice] == "Edit Transform"
        # Edit Transform
        return edit_transform!(esm, changes_made)
    end
end

function test_transform(esm, changes_made)
    println("Enter a transform to evaluate (or just press Enter to go back):")
    flush(stdout)
    while true
        input = read_with_editing("Test Transform> ")
        if isempty(input)
            # Go back to transforms menu
            return transforms_menu(esm, changes_made)
        else
            try
                a = ESM.run_transformation(esm, input)
                println("Transform evaluated successfully.")
                print(input, " = ")
                show(a)
                print("\n")
            catch e
                # TODO Would be helpful to show some better error messages here, like parse errors
                println("Error occurred while evaluating transform: ", e)
            end
        end
    end
end

function add_transform!(esm, changes_made)
    println("Enter the name of the new transform (or just press Enter to go back):")
    flush(stdout)
    name = read_with_editing("New Transform Name> ")
    if isempty(name)
        # Go back to transforms menu
        return transforms_menu(esm, changes_made)
    end
    println("Enter the equation for the new transform (or just press Enter to go back):")
    flush(stdout)
    equation = read_with_editing("New Transform Equation> ")
    if isempty(equation)
        # Go back to transforms menu
        return transforms_menu(esm, changes_made)
    end
    esm.transformations[name] = JSON.Object{String, Any}("equation" => equation)
    changes_made = true
    return transforms_menu(esm, changes_made)
end

function remove_transform!(esm, changes_made)
    transform_names = [collect(keys(esm.transformations))..., "Back"]
    menu = RadioMenu(transform_names)
    choice = request("Select a transform to remove (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif transform_names[choice] == "Back"
        # Back to transforms menu
        return transforms_menu(esm, changes_made)
    else
        transform_to_remove = transform_names[choice]
        delete!(esm.transformations, transform_to_remove)
        changes_made = true
    end
    return transforms_menu(esm, changes_made)
end

function edit_transform!(esm, changes_made)
    transform_names = [collect(keys(esm.transformations))..., "Back"]
    menu = RadioMenu(transform_names)
    choice = request("Select a transform to edit (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif transform_names[choice] == "Back"
        # Back to transforms menu
        return transforms_menu(esm, changes_made)
    else
        transform_to_edit = transform_names[choice]
        println("Current equation for $transform_to_edit: \n", esm.transformations[transform_to_edit]["equation"])
        println("Enter the new equation for the transform (or just press Enter to go back):")
        flush(stdout)
        new_equation = read_with_editing("New Transform Equation> ")
        if isempty(new_equation)
            # Go back to transforms menu
            return transforms_menu(esm, changes_made)
        else
            esm.transformations[transform_to_edit]["equation"] = new_equation
            changes_made = true
        end
    end
    return transforms_menu(esm, changes_made)
end

function quit(esm, changes_made)
    if changes_made
        options = ["Save changes and exit", "Discard changes and exit", "Cancel"]
        menu = RadioMenu(options)
        choice = request("You have unsaved changes. What would you like to do?", menu)
        if choice == -1 || options[choice] == "Discard changes and exit"
            println("Discarding changes.")
            return
        elseif options[choice] == "Save changes and exit"
            return save_esm(esm, changes_made)
        elseif options[choice] == "Cancel"
            println("Returning to main menu.")
            return main_menu(esm, changes_made; exit_on_success = true)
        end
    else
        println("No changes made.")
    end
    println("Exiting ESM interactive mode.")
    return
end

function save_esm(esm, changes_made; exit_on_success = false)
    println("Enter the filename to save the ESM (or just press Enter to cancel):")
    filename = read_with_editing("Filename> ")
    if isempty(filename)
        println("Save cancelled. Returning to main menu.")
        return main_menu(esm, changes_made)
    else
        write_esm(esm, filename)
        println("ESM saved to $filename.")
        if exit_on_success
            println("Exiting ESM interactive mode.")
            return
        else
            return main_menu(esm, false)
        end
    end
end

function group_menu(esm, changes_made)
    group_options = ["Add Group", "Remove Group", "Edit Group", "Group Metadata", "Back"]
    menu = RadioMenu(group_options)
    choice = request("Main Menu / Groups (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif group_options[choice] == "Back"
        # Back to main menu
        return main_menu(esm, changes_made)
    elseif group_options[choice] == "Add Group"
        # Add Group
        return add_group!(esm, changes_made)
    elseif group_options[choice] == "Remove Group"
        # Remove Group
        return remove_group!(esm, changes_made)
    elseif group_options[choice] == "Edit Group"
        # Edit Group
        return edit_group!(esm, changes_made)
    end
    # TODO another menu for group metadata, which will allow adding/editing/removing metadata fields for a group
end

function add_group!(esm, changes_made)
    println("Enter the name of the new group (or just press Enter to go back):")
    flush(stdout)
    name = read_with_editing("New Group Name> ")
    if isempty(name)
        # Go back to group menu
        return group_menu(esm, changes_made)
    end
    println("Enter the samples for the new group (comma-separated) (or just press Enter to go back):")
    flush(stdout)
    samples_input = read_with_editing("New Group Samples> ")
    if isempty(samples_input)
        # Go back to group menu
        return group_menu(esm, changes_made)
    end
    # TODO check for metadata in other groups and ask user to fill in values
    samples = expand_groups(samples_input)
    meta_select = :(filter(row -> row.name in ef["groups"][i]["sample_IDs"],
        samples, view=true))
    push!(esm.groups, (name=name, samples=samples, metadata=JSON.Object{String,Any}(),
        meta_select=meta_select))
    changes_made = true
    esm.samples[!, name] = [in(sample_name, samples) for sample_name in first.(splitext.(esm.samples[!, :name]))]
    return group_menu(esm, changes_made)
end

function remove_group!(esm, changes_made)
    group_names = [g.group for g in esm.groups]
    push!(group_names, "Back")
    menu = RadioMenu(group_names)
    choice = request("Select a group to remove (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif group_names[choice] == "Back"
        # Back to group menu
        return group_menu(esm, changes_made)
    else
        group_to_remove = group_names[choice]
        filter!(g -> g.group != group_to_remove, esm.groups)
        select!(esm.samples, Not(group_to_remove))
        changes_made = true
    end
    return group_menu(esm, changes_made)
end

function edit_group!(esm, changes_made)
    group_names = [g.group for g in esm.groups]
    push!(group_names, "Back")
    menu = RadioMenu(group_names)
    choice = request("Select a group to edit (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif group_names[choice] == "Back"
        # Back to group menu
        return group_menu(esm, changes_made)
    else
        group_to_edit = group_names[choice]
        println("Current samples for $group_to_edit: \n", join(esm.groups[findfirst(g -> g.group == group_to_edit, esm.groups)].samples, ", "))
        println("Enter the new samples for the group (comma-separated) (or just press Enter to go back):")
        flush(stdout)
        new_samples_input = read_with_editing("New Group Samples> ")
        if isempty(new_samples_input)
            # Go back to group menu
            return group_menu(esm, changes_made)
        else
            new_samples = expand_groups(new_samples_input)
            esm.groups[findfirst(g -> g.group == group_to_edit, esm.groups)].samples = new_samples
            esm.samples[!, group_to_edit] = [in(sample_name, new_samples) for sample_name in first.(splitext.(esm.samples[!, :name]))]
            changes_made = true
        end
    end
    return group_menu(esm, changes_made)
end

