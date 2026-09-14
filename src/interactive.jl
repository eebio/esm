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

function main_menu(esm)
    main_options = ["Transforms", "Groups", "Views"]
    menu = RadioMenu(main_options)
    choice = request("Main Menu (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return
    elseif main_options[choice] == "Transforms"
        # Transforms
        return transforms_menu(esm)
    end
end

function transforms_menu(esm)
    transform_options = ["Test Transform",  "Back"]
    menu = RadioMenu(transform_options)
    choice = request("Main Menu / Transforms (press [q] to quit):", menu)
    if choice == -1
        # Quit
        return
    elseif transform_options[choice] == "Test Transform"
        # Test Transform
        return test_transform(esm)
    elseif transform_options[choice] == "Back"
        # Back to main menu
        return main_menu(esm)
    end
end

function test_transform(esm)
    println("Enter a transform to evaluate (or just press Enter to go back):")
    flush(stdout)
    while true
        input = read_with_editing("Test Transform> ")
        if isempty(input)
            # Go back to transforms menu
            return transforms_menu(esm)
        else
            try
                a = ESM.run_transformation(esm, input)
                println("Transform evaluated successfully.")
                print(input, " = ")
                show(a)
                print("\n")
            catch e
                println("Error occurred while evaluating transform: ", e)
            end
        end
    end
end
