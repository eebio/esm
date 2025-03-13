@testmodule build begin
    using Pkg
    Pkg.build()
    if !occursin("/.julia/bin", ENV["PATH"])
        homepath = ENV["HOME"]
        ENV["PATH"] *= ":"*homepath*"/.julia/bin"
    end
end

@testitem "Template integration" setup=[build] begin
    dir = Base.Filesystem.mktempdir()*"/"
    readdir(dir)
    run(`eebiotools template --output-path $dir`)
    readdir(dir)
    @test isfile(joinpath(dir, "ESM.xlsx"))
    dir = Base.Filesystem.mktempdir()*"/"
    @test_broken run(`eebiotools template -o $dir`)
    @test isfile(joinpath(dir, "ESM.xlsx")) broken=true
end

@testitem "Create integration" setup=[build] begin
    using SHA

    dir = Base.Filesystem.mktempdir()
    run(`eebiotools create --excel inputs/example.xlsx --target $dir/tmp`)
    @test isfile(joinpath(dir, "tmp.esm"))
    esm_hash = open(joinpath(dir, "tmp.esm")) do f
        sha256(f)
    end
    @test_broken run(`eebiotools create -e inputs/example.xlsx -t $dir/tmp2`)
    @test bytes2hex(esm_hash) == "806fc9b3a2c4ec394a700286281025f800b268876449a179ccb18565a14dfaf8"
    @test isfile(joinpath(dir, "tmp2.esm")) skip=true
    @test_skip esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) == "806fc9b3a2c4ec394a700286281025f800b268876449a179ccb18565a14dfaf8" skip=true
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" begin
    dir = Base.Filesystem.mktempdir()
    eebiotools.template(output_path=dir)
    eebiotools.create(excel="inputs/example.xlsx", target=joinpath(dir, "tmp"))
end
