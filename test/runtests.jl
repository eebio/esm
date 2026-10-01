using TestItemRunner
using Longwing

# Remove any existing coverage files
for f in readdir(pwd(), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

for f in readdir(joinpath(pwd(), "..", "src"), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

for f in readdir(joinpath(pwd(), "..", "src", "flow"), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

for f in readdir(joinpath(pwd(), "..", "src", "interactive"), join=true)
    if endswith(f, ".cov")
        rm(f)
    end
end

@testsnippet environment_path begin
    println("environment path")
    if "GITHUB_WORKSPACE" ∉ keys(ENV)
        ENV["GITHUB_WORKSPACE"] = pwd()*"/.."
    end
end

@testitem "update example.longwing and summarise.longwing" setup=[environment_path] begin
    println("update example.longwing and summarise.longwing")
    data = read_data("inputs/example.xlsx")
    data["metadata"]["date_created"] = ""
    data["metadata"]["date_modified"] = ""
    data["metadata"]["versioninfo"] = ""
    data["metadata"]["Manifest.toml"] = ""
    data["metadata"]["Project.toml"] = ""
    write_longwing(data, "inputs/example.longwing")

    data = read_data("inputs/summarise.xlsx")
    data["metadata"]["date_created"] = ""
    data["metadata"]["date_modified"] = ""
    data["metadata"]["versioninfo"] = ""
    data["metadata"]["Manifest.toml"] = ""
    data["metadata"]["Project.toml"] = ""
    write_longwing(data, "inputs/summarise.longwing")
end

@run_package_tests
