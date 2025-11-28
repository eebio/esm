@testmodule build begin
    println("build")
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
    println("get shell")
    if Sys.iswindows()
        # Use cmd shell for Windows
        shell = ["cmd", "/C"]
    else
        # Use default shell
        shell = []
    end
end

@testitem "Template integration" setup=[build, getshell] begin
    println("Template integration")
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
    println("Translate integration")
    using SHA

    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm translate --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp.esm"))`)
    @test isfile(joinpath(dir, "tmp.esm"))
    esm_hash = open(joinpath(dir, "tmp.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "7c2b0070ec0b6aadfa37cfcea2bb3340396731fff3ee7f76190cb4fc2c71089a"
    run(`$(shell) esm translate -e $(joinpath("inputs", "example.xlsx")) -t $(joinpath(dir, "tmp2.esm"))`)
    @test isfile(joinpath(dir, "tmp2.esm"))
    esm_hash = open(joinpath(dir, "tmp2.esm")) do f
        sha256(f)
    end
    @test bytes2hex(esm_hash) ==
          "7c2b0070ec0b6aadfa37cfcea2bb3340396731fff3ee7f76190cb4fc2c71089a"
end

@testitem "Views integration" setup=[environment_path, build, getshell] begin
    println("Views integration")
    # All views
    dir = Base.Filesystem.mktempdir()
    run(`$(shell) esm translate --excel $(joinpath("inputs", "example.xlsx")) --target $(joinpath(dir, "tmp.esm"))`)
    run(`$(shell) esm views --esm-file $(joinpath(dir, "tmp.esm")) --output-dir $dir`)
    @test issetequal(readdir(dir), ["flowsub.csv", "group1.csv", "group2.csv", "group3.csv", "mega.csv", "odsub.csv", "sample.csv", "tmp.esm"])
    rm.(joinpath.(dir, ["flowsub.csv", "group1.csv", "group2.csv", "group3.csv", "mega.csv", "odsub.csv", "sample.csv"]), force=true)
    @test issetequal(readdir(dir), ["tmp.esm"])

    run(`$(shell) esm views -e $(joinpath(dir, "tmp.esm")) -o $dir`)
    @test issetequal(readdir(dir), ["flowsub.csv", "group1.csv", "group2.csv", "group3.csv", "mega.csv", "odsub.csv", "sample.csv", "tmp.esm"])

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

@testitem "Summarise integration" setup=[environment_path, build, getshell] begin
    println("Summarise integration")
    dir = Base.Filesystem.mktempdir()
    cp(joinpath("inputs", "summarise.esm"), joinpath(dir, "summarise.esm"))
    run(`$(shell) esm summarise --file $(joinpath(dir, "summarise.esm")) --plot`)
    @test isfile(joinpath(dir, "summarise.esm.pdf"))
    rm(joinpath(dir, "summarise.esm.pdf"), force=true)
    run(`$(shell) esm summarise -f $(joinpath(dir, "summarise.esm")) -p`)
    @test isfile(joinpath(dir, "summarise.esm.pdf"))

    cp(joinpath("inputs", "small.fcs"), joinpath(dir, "small.fcs"))
    run(`$(shell) esm summarise --file $(joinpath(dir, "small.fcs"))`)
    @test !isfile(joinpath(dir, "small.fcs.pdf"))
    run(`$(shell) esm summarise -f $(joinpath(dir, "small.fcs")) --plot`)
    @test isfile(joinpath(dir, "small.fcs.pdf"))

    cp(joinpath("inputs", "spectramax-summarise.txt"), joinpath(dir, "spectramax-summarise.txt"))
    run(`$(shell) esm summarise --file $(joinpath(dir, "spectramax-summarise.txt")) --type spectramax`)
    @test !isfile(joinpath(dir, "spectramax-summarise.txt.pdf"))
    run(`$(shell) esm summarise -f $(joinpath(dir, "spectramax-summarise.txt")) --type spectramax --plot`)
    @test isfile(joinpath(dir, "spectramax-summarise.txt.pdf"))

    cp(joinpath("inputs", "biotek-summarise.csv"), joinpath(dir, "biotek-summarise.csv"))
    run(`$(shell) esm summarise --file $(joinpath(dir, "biotek-summarise.csv")) --type biotek`)
    @test !isfile(joinpath(dir, "biotek-summarise.csv.pdf"))
    run(`$(shell) esm summarise -f $(joinpath(dir, "biotek-summarise.csv")) --type biotek -p`)
    @test isfile(joinpath(dir, "biotek-summarise.csv.pdf"))

    cp(joinpath("inputs", "pr_folder"), joinpath(dir, "pr_folder"))
    run(`$(shell) esm summarise --file $(joinpath(dir, "pr_folder"))`)
    @test !isfile(joinpath(dir, "pr_folder.pdf"))
    run(`$(shell) esm summarise -f $(joinpath(dir, "pr_folder")) -p`)
    @test isfile(joinpath(dir, "pr_folder.pdf"))
end

#The integration tests won't track code coverage, so we repeat them with the Julia interface here
@testitem "Integration coverage" setup=[environment_path] begin
    println("Integration coverage")
    dir = Base.Filesystem.mktempdir()
    template(output_path = joinpath(dir, "tmp.xlsx"))
    translate(excel = joinpath("inputs", "example.xlsx"), target = joinpath(dir, "tmp.esm"))
    views(esm_file = joinpath(dir, "tmp.esm"), output_dir = dir)
    views(esm_file = joinpath(dir, "tmp.esm"), view = "mega", output_dir = dir)
    cp(joinpath("inputs", "summarise.esm"), joinpath(dir, "summarise.esm"))
    summarise(file = joinpath(dir, "summarise.esm"), plot = true)
    cp(joinpath("inputs", "small.fcs"), joinpath(dir, "small.fcs"))
    cp(joinpath("inputs", "spectramax-summarise.txt"), joinpath(dir, "spectramax-summarise.txt"))
    cp(joinpath("inputs", "biotek-summarise.csv"), joinpath(dir, "biotek-summarise.csv"))
    cp(joinpath("inputs", "pr_folder"), joinpath(dir, "pr_folder"))
    summarise(file = joinpath(dir, "small.fcs"), plot = true)
    summarise(file = joinpath(dir, "spectramax-summarise.txt"), type = "spectramax", plot = true)
    summarise(file = joinpath(dir, "biotek-summarise.csv"), type = "biotek", plot = true)
    summarise(file = joinpath(dir, "pr_folder"), plot = true)
end
