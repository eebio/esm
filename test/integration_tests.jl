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
    run(`$(shell) esm template --output-path $dir/tmp.xlsx`)
    @test isfile(joinpath(dir, "tmp.xlsx"))
    run(`$(shell) esm template -o $dir/t2.xlsx`)
    @test isfile(joinpath(dir, "t2.xlsx"))
    cd(dir)
    run(`$(shell) esm template`)
    @test isfile("ESM.xlsx")
end

@testitem "Translate integration" setup=[environment_path, build, getshell] begin
    using SHA

    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm translate --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp.esm"))`)
    @test isfile(joinpath(dir, "tmp.esm"))
    esm_hash = open(joinpath(dir, "tmp.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "7584ebe26cc7b016394151c717b9f4197220db2a9f35a6231f07065f3619a2e0"
    run(`$(shell) esm translate -e $(joinpath("inputs", "example.xlsx")) -t $(joinpath(dir, "tmp2.esm"))`)
    @test isfile(joinpath(dir, "tmp2.esm"))
    esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "7584ebe26cc7b016394151c717b9f4197220db2a9f35a6231f07065f3619a2e0"
end

@testitem "Views integration" setup=[environment_path, build, getshell] begin
    # All views
    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm translate --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp.esm"))`)
    run(`$(shell) esm views --esm-file $(joinpath(dir, "tmp.esm")) --output-dir $dir`)
    @test issetequal(readdir(dir), ["flow_cy.csv", "flowsub.csv", "group1.csv", "group2.csv", "group3.csv", "mega.csv", "odsub.csv", "sample.csv", "tmp.esm"])
    rm.(joinpath.(dir, ["flow_cy.csv", "flowsub.csv", "group1.csv", "group2.csv", "group3.csv", "mega.csv", "odsub.csv", "sample.csv"]), force=true)
    @test issetequal(readdir(dir), ["tmp.esm"])

    run(`$(shell) esm views -e $(joinpath(dir, "tmp.esm")) -o $dir`)
    @test issetequal(readdir(dir), ["flow_cy.csv", "flowsub.csv", "group1.csv", "group2.csv", "group3.csv", "mega.csv", "odsub.csv", "sample.csv", "tmp.esm"])

    # Specifying a specific view
    using SHA

    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm translate --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp.esm"))`)
    run(`$(shell) esm views --esm-file $(joinpath(dir, "tmp.esm")) --view mega --output-dir $dir`)
    @test isfile(joinpath(dir, "mega.csv"))
    esm_hash = open(joinpath(dir, "mega.csv")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "8dc3e2b2a2d60b1d2c2ad0bbcf5564e31aa93961792eb2a88640bbfe59cde9a4"

    dir2 = Base.Filesystem.mktempdir()
    run(`$(shell) esm views -e $(joinpath(dir, "tmp.esm")) -v mega -o $dir2`)
    @test isfile(joinpath(dir2, "mega.csv"))
    esm_hash2 = open(joinpath(dir2, "mega.csv")) do f #Keep as esm_hash2 until test is working
        sha256(f)
    end
    @test bytes2hex(esm_hash2) ==
          "8dc3e2b2a2d60b1d2c2ad0bbcf5564e31aa93961792eb2a88640bbfe59cde9a4"
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" setup=[environment_path] begin
    dir = Base.Filesystem.mktempdir()
    ESM.template(output_path = joinpath(dir, "tmp.xlsx"))
    ESM.translate(excel = joinpath("inputs", "example.xlsx"), target = joinpath(dir, "tmp.esm"))
    ESM.views(esm_file = joinpath(dir, "tmp.esm"), output_dir = dir)
    ESM.views(esm_file = joinpath(dir, "tmp.esm"), view = "mega", output_dir = dir)
end
