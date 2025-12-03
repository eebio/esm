using TestItemRunner

@testsnippet environment_path begin
    println("environment path")
    if "GITHUB_WORKSPACE" ∉ keys(ENV)
        ENV["GITHUB_WORKSPACE"] = pwd()*"/.."
    end
end

@run_package_tests
