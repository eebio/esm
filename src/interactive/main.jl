import REPL
using REPL.TerminalMenus
using REPL.LineEdit
using REPL.Terminals

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
            return save_esm(esm, changes_made)
        elseif options[choice] == "Cancel"
            println("Returning to main menu.")
            return main_menu(esm, changes_made; exit_on_success=true)
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
