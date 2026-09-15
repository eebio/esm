function transforms_menu(esm, changes_made)
    transform_options = ["Test Transform", "Add Transform", "Remove Transform", "Edit Transform", "Back"]
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
    esm.transformations[name] = JSON.Object{String,Any}("equation" => equation)
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
