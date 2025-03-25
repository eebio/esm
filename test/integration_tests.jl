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
    @test isfile(joinpath(dir, "ESM.xlsx"))
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
          "e2163d5e07ac91b201d8d616f1915c72aeb649932568feac159539e020c9ce9a"
    run(`esm create -e inputs/example.xlsx -t $dir/tmp2`)
    @test isfile(joinpath(dir, "tmp2.esm"))
    esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "e2163d5e07ac91b201d8d616f1915c72aeb649932568feac159539e020c9ce9a"
end

@testitem "Process integration" setup=[build] begin
    dir = Base.Filesystem.mktempdir()
    run(`esm create --excel inputs/example.xlsx --target $dir/tmp`)
    run(`esm process --esm $dir/tmp.esm --output-dir $dir`)
    # TODO Add tests for detecting views once working
    run(`esm process -e $dir/tmp.esm -o $dir`)
end

@testitem "Produce intergration" setup=[build] begin
    dir = Base.Filesystem.mktempdir()
    run(`esm create --excel inputs/example.xlsx --target $dir/tmp`)
    run(`esm produce --esm $dir/tmp.esm --view flow_cyt --output-dir $dir`)
    # TODO Add tests for detecting views once working
    run(`esm produce -e $dir/tmp.esm -v flow_cyt -o $dir`)
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" begin
    dir = Base.Filesystem.mktempdir()
    ESM.template(output_path = dir)
    ESM.create(excel = "inputs/example.xlsx", target = joinpath(dir, "tmp"))
    ESM.process(esm_file = joinpath(dir, "tmp.esm"), output_dir = dir)
    ESM.produce(esm_file = joinpath(dir, "tmp.esm"), view = "flow_cyt", output_dir = dir)
end
