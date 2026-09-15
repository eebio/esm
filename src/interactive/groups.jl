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
    push!(esm.groups, (group=name, sample_IDs=samples, metadata=JSON.Object{String,Any}(),
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
    group_names = [g.group for g in eachrow(esm.groups)]
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
        println("Current samples for $group_to_edit: \n", join(esm.groups.sample_IDs[findfirst(g -> g.group == group_to_edit, eachrow(esm.groups))], ", "))
        println("Enter the new samples for the group (comma-separated) (or just press Enter to go back):")
        flush(stdout)
        new_samples_input = read_with_editing("New Group Samples> ")
        if isempty(new_samples_input)
            # Go back to group menu
            return group_menu(esm, changes_made)
        else
            new_samples = expand_groups(new_samples_input)
            esm.groups.sample_IDs[findfirst(g -> g.group == group_to_edit, eachrow(esm.groups))] = new_samples
            esm.samples[!, group_to_edit] = [in(sample_name, new_samples) for sample_name in first.(splitext.(esm.samples[!, :name]))]
            changes_made = true
        end
    end
    return group_menu(esm, changes_made)
end
