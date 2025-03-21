@testmodule build begin
    using Pkg
    Pkg.build()
    if !occursin("/.julia/bin", ENV["PATH"])
        homepath = ENV["HOME"]
        ENV["PATH"] *= ":" * homepath * "/.julia/bin"
    end
end

@testitem "Template integration" setup=[build] begin
    dir = Base.Filesystem.mktempdir() * "/"
    readdir(dir)
    run(`esm template --output-path $dir`)
    readdir(dir)
    @test isfile(joinpath(dir, "ESM.xlsx"))
    dir = Base.Filesystem.mktempdir() * "/"
    run(`esm template -o $dir`)
    @test isfile(joinpath(dir, "ESM.xlsx")) broken=true
end

@testitem "Create integration" setup=[build] begin
    using SHA

    dir = Base.Filesystem.mktempdir()
    run(`esm create --excel inputs/example.xlsx --target $dir/tmp`)
    @test isfile(joinpath(dir, "tmp.esm"))
    esm_hash = open(joinpath(dir, "tmp.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "b98d7cd46924ec510fa286d340db3b21756e8aa0ec3af6262129405de766e236"
    run(`esm create -e inputs/example.xlsx -t $dir/tmp2`)
    @test isfile(joinpath(dir, "tmp2.esm")) skip=true
    esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "b98d7cd46924ec510fa286d340db3b21756e8aa0ec3af6262129405de766e236"
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" begin
    dir = Base.Filesystem.mktempdir()
    ESM.template(output_path = dir)
    ESM.create(excel = "inputs/example.xlsx", target = joinpath(dir, "tmp"))
    ESM.process(esm_file = joinpath(dir, "tmp.esm"), output_dir = dir)
end
