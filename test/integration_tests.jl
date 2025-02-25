using Pkg
using SHA
using eebiotools

function build()
    Pkg.build()
    if !occursin("/.julia/bin", ENV["PATH"])
        homepath = ENV["HOME"]
        ENV["PATH"] *= ":"*homepath*"/.julia/bin"
    end
end

build()

@testset "Template integration" begin
    dir = Base.Filesystem.mktempdir()*"/"
    run(`eebiotools template --output-path $dir`)
    @test isfile(joinpath(dir, "ESM.xlsx"))
    dir = Base.Filesystem.mktempdir()*"/"
    run(`eebiotools template -o $dir`)
    @test isfile(joinpath(dir, "ESM.xlsx"))
end

@testset "Create integration" begin
    dir = Base.Filesystem.mktempdir()
    run(`eebiotools create --excel inputs/ESM.xlsx --target $dir/tmp`)
    @test isfile(joinpath(dir, "tmp.esm"))
    esm_hash = open(joinpath(dir, "tmp.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) == "600ec268f7a50736b5d0f70798fc695df09eb5832e418c5f9af5c936b4a11cc0"
    run(`eebiotools create -e inputs/ESM.xlsx -t $dir/tmp2`)
    @test isfile(joinpath(dir, "tmp2.esm"))
    esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) == "600ec268f7a50736b5d0f70798fc695df09eb5832e418c5f9af5c936b4a11cc0"
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testset "Integration coverage" begin
    dir = Base.Filesystem.mktempdir()
    eebiotools.template(output_path=dir)
    eebiotools.create(excel="inputs/ESM.xlsx", target=joinpath(dir, "tmp"))
end
