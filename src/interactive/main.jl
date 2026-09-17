import REPL
using REPL.TerminalMenus
using REPL.LineEdit
using REPL.Terminals

# TODO TerminalRegressionTests.jl

include("transforms.jl")
include("groups.jl")
include("views.jl")

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
    elseif main_options[choice] == "Groups"
        # Groups
        return group_menu(esm, changes_made)
    elseif main_options[choice] == "Views"
        # Views
        return views_menu(esm, changes_made)
    elseif main_options[choice] == "Save Changes"
        # Groups
        return save_esm(esm, changes_made; exit_on_success=false)
    end
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
            return save_esm(esm, changes_made; exit_on_success=true)
        elseif options[choice] == "Cancel"
            println("Returning to main menu.")
            return main_menu(esm, changes_made)
        end
    else
        println("No changes made.")
    end
    println("Exiting ESM interactive mode.")
    return
end

function save_esm(esm, changes_made; exit_on_success=false)
    println("Enter the filename to save the ESM (or just press Enter to cancel):")
    filename = read_with_editing("Filename> ")
    if isempty(filename)
        println("Save cancelled. Returning to main menu.")
        return main_menu(esm, changes_made)
    else
        # Check metadata compatibility
        new_metadata = get_metadata()
        old_metadata = esm.metadata
        if new_metadata["esm_version"] != old_metadata["esm_version"] ||
            new_metadata["schema_version"] != old_metadata["schema_version"] ||
            new_metadata["Project.toml"] != old_metadata["Project.toml"] ||
            new_metadata["Manifest.toml"] != old_metadata["Manifest.toml"] ||
            new_metadata["versioninfo"] != old_metadata["versioninfo"]
            match = false
        else
            match = false
        end
        if !match
            @warn "The current version of ESM is different from the version used to create \
            the original file. If you have access to the original data, it is recommended \
            to re-translate the .esm file with this version. Otherwise, we can save the \
            file with these changes and append a warning to the description metadata to \
            record the original metadata used to create the esm file."
            options = ["Yes, save changes and update the metadata", "No, discard changes"]
            menu = RadioMenu(options)
            should_save = request("Version mismatch detected. Would you still like to save the changes?", menu)
            should_save = should_save == 1
            if should_save
                new_metadata["description"] = old_metadata["description"] * "\nWARNING: This ESM file was modified after creation using a different version of ESM. Original metadata: \n" * string(old_metadata)
                new_metadata["date_created"] = old_metadata["date_created"]
                esm.metadata = new_metadata
            end
        else
            should_save = true
        end
        if should_save
            esm.metadata["date_modified"] = Dates.now()
            write_esm(esm, filename)
            println("ESM saved to $filename.")
        end
        if exit_on_success
            println("Exiting ESM interactive mode.")
            return
        else
            return main_menu(esm, false)
        end
    end
end
