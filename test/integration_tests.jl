@testmodule build begin
    using Pkg
    Pkg.build()
    if !occursin("/.julia/bin", ENV["PATH"])
        if Sys.iswindows()
            ENV["PATH"] *= ";" * first(DEPOT_PATH)
        else
            ENV["PATH"] *= ":" * first(DEPOT_PATH)
        end
    end
end

@testsnippet getshell begin
    if Sys.iswindows()
        # Use cmd shell for Windows
        shell = ["cmd", "/C"]
    else
        # Use default shell
        shell = []
    end
end

@testitem "Template integration" setup=[build, getshell] begin
    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm template -h`)
    @test_skip isfile(joinpath(dir, "ESM.xlsx"))
    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm template -o $dir`)
    @test_skip isfile(joinpath(dir, "ESM.xlsx"))
end

@testitem "Create integration" setup=[environment_path, build, getshell] begin
    using SHA

    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm create --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp"))`)
    @test isfile(joinpath(dir, "tmp.esm"))
    esm_hash = open(joinpath(dir, "tmp.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "e2163d5e07ac91b201d8d616f1915c72aeb649932568feac159539e020c9ce9a"
    run(`$(shell) esm create -e $(joinpath("inputs", "example.xlsx")) -t $(joinpath(dir, "tmp2"))`)
    @test isfile(joinpath(dir, "tmp2.esm"))
    esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "e2163d5e07ac91b201d8d616f1915c72aeb649932568feac159539e020c9ce9a"
end

@testitem "Process integration" setup=[environment_path, build, getshell] begin
    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm create --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp"))`)
    run(`$(shell) esm process --esm-file $(joinpath(dir, "tmp.esm")) --output-dir $dir`)
    # TODO Add tests for detecting views once working
    @test_broken run(`$(shell) esm process -e $(joinpath(dir, "tmp.esm")) -o $dir`)
end

@testitem "Produce intergration" setup=[environment_path, build, getshell] begin
    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm create --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp"))`)
    run(`$(shell) esm produce --esm-file $(joinpath(dir, "tmp.esm")) --view flow_cy --output-dir $dir`)
    # TODO Add tests for detecting views once working
    @test_broken run(`$(shell) esm produce -e $(joinpath(dir, "tmp.esm")) -v flow_cy -o $dir`)
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" setup=[environment_path] begin
    dir = Base.Filesystem.mktempdir()
    ESM.template(output_path = dir)
    ESM.create(excel = joinpath("inputs", "example.xlsx"), target = joinpath(dir, "tmp"))
    ESM.process(esm_file = joinpath(dir, "tmp.esm"), output_dir = dir)
    ESM.produce(esm_file = joinpath(dir, "tmp.esm"), view = "flow_cy", output_dir = dir)
end
