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

let 
    foo(a,b,c) = a .+ b .+ c

    @test @chain 1:100 begin 
        @rev map(x -> x) # put the 1:100 in the last arg slot instead of the first one
        @map x -> x # a whole @map macro which automatically does this
        zip(1:100)
        @map @unpack (a, b) -> a # no need to bother with tuple[1] & tuple[2] after zipping
        @apply x -> x # a way to apply a function directly 
        @apply with() do x # do-block support
            x
        end 
        @apply @∂ foo(1, @x, 3) # vectorise and apply a partially applied function 
        @reduce init = 100 (acc, inc) -> acc # allow kwargs
        @convert Float32 # conversions available with type-arg last
        isequal(100.0)
    end 
end 