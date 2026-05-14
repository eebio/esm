using TestItemRunner
using ESM

@testsnippet environment_path begin
    println("environment path")
    if "GITHUB_WORKSPACE" ∉ keys(ENV)
        ENV["GITHUB_WORKSPACE"] = pwd()*"/.."
    end
end

@testitem "update example.esm and summarise.esm" setup=[environment_path] begin
    println("update example.esm and summarise.esm")
    data = read_data("inputs/example.xlsx")
    data["metadata"]["date_created"] = ""
    data["metadata"]["date_modified"] = ""
    data["metadata"]["versioninfo"] = ""
    data["metadata"]["Manifest.toml"] = ""
    data["metadata"]["Project.toml"] = ""
    write_esm(data, "inputs/example.esm")

    data = read_data("inputs/summarise.xlsx")
    data["metadata"]["date_created"] = ""
    data["metadata"]["date_modified"] = ""
    data["metadata"]["versioninfo"] = ""
    data["metadata"]["Manifest.toml"] = ""
    data["metadata"]["Project.toml"] = ""
    write_esm(data, "inputs/summarise.esm")
end

@run_package_tests
