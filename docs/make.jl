using Documenter, ESM
using DocumenterInterLinks

links = InterLinks(
)

PAGES = [
    "Introduction" => "index.md",
    "Tutorial" => "tutorial.md",
    "Plate Readers" => [
        "plate_readers/index.md",
        "plate_readers/growth_rate.md",
        "plate_readers/fluorescence.md"
    ],
    "Flow Cytometers" => [
        "flow_cytometers/index.md",
        "flow_cytometers/auto_gating.md",
        "flow_cytometers/manual_gating.md"
    ],
    "qPCR" => [
        "qpcr/index.md",
    ],
    "Data Format" => "data_format.md",
    "Command Line Interface" => "cli.md",
    "API" => "api.md"
]

modules = [ESM
]

makedocs(sitename = "Mermaid.jl",
    repo = Remotes.GitHub("eebio", "esm"), modules = modules, checkdocs = :exports,
    pages = PAGES, plugins = [links])

deploydocs(
    repo = "github.com/eebio/esm",
)
