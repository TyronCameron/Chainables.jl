using Documenter
using Chainables

push!(LOAD_PATH,"../src/")

makedocs(
    sitename = "Chainables",
    format = Documenter.HTML(),
    modules = [Chainables],
    pages = [
        "Index" => "index.md",
        "API" => "api.md"
    ]
)

deploydocs(
    repo = "github.com/TyronCameron/Chainables.jl.git",
    devbranch = "main"
)
