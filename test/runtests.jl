using Chainables, Test, Aqua

Aqua.test_all(Chainables)

###########################################################################
# Run tests
###########################################################################

include(joinpath(@__DIR__, "apply.jl"))
include(joinpath(@__DIR__, "pack.jl"))
include(joinpath(@__DIR__, "functionals.jl"))
include(joinpath(@__DIR__, "convert.jl"))
include(joinpath(@__DIR__, "unzip.jl"))
include(joinpath(@__DIR__, "vec.jl"))
include(joinpath(@__DIR__, "partial.jl"))

