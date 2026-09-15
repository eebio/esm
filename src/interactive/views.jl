function views_menu(esm, changes_made)
    view_options = ["Produce Views", "Add View", "Remove View", "Edit View", "Back"]
    menu = RadioMenu(view_options)
    choice = request("Main Menu / Views (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif view_options[choice] == "Back"
        # Back to main menu
        return main_menu(esm, changes_made)
    elseif view_options[choice] == "Produce Views"
        # Produce Views
        return produce_view(esm, changes_made)
    elseif view_options[choice] == "Add View"
        # Add View
        return add_view!(esm, changes_made)
    elseif view_options[choice] == "Remove View"
        # Remove View
        return remove_view!(esm, changes_made)
    elseif view_options[choice] == "Edit View"
        # Edit View
        return edit_view!(esm, changes_made)
    end
end

function produce_view(esm, changes_made)
    options = [collect(keys(esm.views))..., "Back"]
    menu = RadioMenu(options)
    choice = request("Select a view to produce (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif options[choice] == "Back"
        # Back to views menu
        return views_menu(esm, changes_made)
    else
        # Produce the selected view
        trans_meta_map = Dict(Symbol(i) => Meta.parse(esm.transformations[i]["equation"])
                              for i in keys(esm.transformations))
        produce_views(esm, trans_meta_map; to_out=[options[choice]])
        return views_menu(esm, changes_made)
    end
end

function add_view!(esm, changes_made)
    println("Enter the name of the new view (or just press Enter to go back):")
    flush(stdout)
    name = read_with_editing("New View Name> ")
    if isempty(name)
        # Go back to views menu
        return views_menu(esm, changes_made)
    end
    if haskey(esm.views, name)
        println("A view with the name $name already exists. Please choose a different name.")
        return add_view!(esm, changes_made)
    end
    println("Enter the equation for the new view (or just press Enter to go back):")
    flush(stdout)
    equation = read_with_editing("New View Equation> ")
    if isempty(equation)
        # Go back to views menu
        return views_menu(esm, changes_made)
    end
    equation = strip.(split(equation, ","))
    esm.views[name] = JSON.Object{String,Any}("data" => equation)
    changes_made = true
    return views_menu(esm, changes_made)
end

function remove_view!(esm, changes_made)
    view_names = [collect(keys(esm.views))..., "Back"]
    menu = RadioMenu(view_names)
    choice = request("Select a view to remove (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif view_names[choice] == "Back"
        # Back to views menu
        return views_menu(esm, changes_made)
    else
        view_to_remove = view_names[choice]
        delete!(esm.views, view_to_remove)
        changes_made = true
    end
    return views_menu(esm, changes_made)
end

function edit_view!(esm, changes_made)
    view_names = [collect(keys(esm.views))..., "Back"]
    menu = RadioMenu(view_names)
    choice = request("Select a view to edit (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return quit(esm, changes_made)
    elseif view_names[choice] == "Back"
        # Back to views menu
        return views_menu(esm, changes_made)
    else
        view_to_edit = view_names[choice]
        println("Current equation for $view_to_edit: \n", esm.views[view_to_edit]["data"])
        println("Enter the new equation for the view (or just press Enter to go back):")
        flush(stdout)
        new_equation = read_with_editing("New View Equation> ")
        new_equation = strip.(split(new_equation, ","))
        if isempty(new_equation)
            # Go back to views menu
            return views_menu(esm, changes_made)
        else
            esm.views[view_to_edit]["data"] = new_equation
            changes_made = true
        end
    end
    return views_menu(esm, changes_made)
end
