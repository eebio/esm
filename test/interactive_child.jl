using Longwing

lw_file = ARGS[1]
session_count = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1

for _ in 1:session_count
    Longwing.interactive(lw_file)
    println("LONGWING_INTERACTIVE_SESSION_DONE")
    flush(stdout)
end

println("LONGWING_INTERACTIVE_TEST_PASSED")
flush(stdout)
readline(stdin)
