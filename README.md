[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tyroncameron.github.io/Chainables.jl/dev/)

# Chainables.jl

Flip those function calls upside down so that `@chain` (from [Chain.jl](https://github.com/jkrumbiegel/Chain.jl)) is even nicer! 

This is a package for true `@chain` connoisseurs. Continue that `@chain` without feeling peer-pressured by those pesky reverse-argument functions.

```julia 
foo(a,b,c) = a + b + c

@assert @chain 1:100 begin 
    @rev map(x -> x) # put the 1:100 in the last arg slot instead of the first one
    @map x -> x # a whole @map macro which automatically does this -- other functional iterator functions also available
    zip(1:100)
    @map @unpack (a, b) -> a # unpack tuple[1] & tuple[2] into the function
    @apply x -> x # a way to apply a function immediately
    @apply with() do x # do-block support
        x
    end 
    @apply @∂ foo(1, @x, 3) # a partially applied function -- more useful outside @chain, equivalent to foo(1,_,3)
    @reduce init = 100 (acc, inc) -> acc # supports kwargs 
    @convert Float32 # conversions available with type-arg last
    isequal(100.0)
end 
```

