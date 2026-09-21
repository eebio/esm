using ESM

esm_file = ARGS[1]
session_count = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1

for _ in 1:session_count
    ESM.interactive(esm_file)
    println("ESM_INTERACTIVE_SESSION_DONE")
    flush(stdout)
end

println("ESM_INTERACTIVE_TEST_PASSED")
flush(stdout)
readline(stdin)
