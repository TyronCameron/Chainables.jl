"""
Chainables.jl is a library for working better with Chain.jl 
"""
module Chainables
import Chain: @chain, @aside
export 
    @chain, @aside, 
    apply, @apply, with, @with,
    pack, @pack, unpack, @unpack,
    @filteriter, @map, @filter, @reduce, @foldl, @foldr, @accumulate, 
    @count, @sum, @prod, 
    @minimum, @maximum, @any, @all, 
    @extrema, @argmin, @argmax, 
    @findfirst, @findlast, 
    @convert, @parse,
    unzip,
    vectorise, @vec,
    @x, @∂, partial, @partial, Placeholder

# ----------------------------------------------------------------
# Utilities for this module
# ----------------------------------------------------------------

macro create_reverse_macro(function_name)
    quote 
        macro $function_name(a, b)
            f = $function_name
            quote $f($b, $a) end |> esc
        end 
    end |> esc
end 

macro create_as_macro(function_name)
    quote
        macro $function_name(args...)
            Expr(:call, $function_name, args...) |> esc
        end
    end |> esc
end 

# ----------------------------------------------------------------
# Apply
# ----------------------------------------------------------------

"""
    apply(f, args...; kwargs...)

Simply apply `f` with the `args` and `kwargs` given. 
"""
apply(f, args...; kwargs...) = f(args...; kwargs...)

"""
    @apply(x, f)

Apply `f` to `x`. Useful when chaining. For example, imagine we want the first letter of the second word in the following sentence: 

```julia
@chain "Hello Fine Ladies" begin 
    split.(" ")
    @apply x -> x[2][1]
end 
```
"""
@create_reverse_macro apply

"""
    with(f::Function, args...; kwargs...)

Curry out the first variable from function `f`. This is useful if you wanted do blocks in chain statements. For instance:

```julia
@chain 12 begin 
    @apply with(1) do x,y
        x^2 + y 
    end 
end 
# == 12^2 + 1 == 145
```
"""
with(f::Function, args...; kwargs...) = x -> f(x, args...; kwargs...)

# ----------------------------------------------------------------
# Packing and unpacking
# ----------------------------------------------------------------

# struct PackedArgs 
#     args
#     kwargs
# end 

"""
    pack(args...)

Simply return the args in a tuple.
"""
pack(args...) = args
# pack(args...; kwargs...) = PackedArgs(args, kwargs)

"""
    @pack(args...)

Simply returns the args in a tuple
"""
@create_as_macro pack 

"""
    unpack(f::Function)

Return a valid form of `f` that can destructure its args. 
Without this function you may find yourself working with tuples as a single argument to a function: 

```julia
@chain 1:10 begin
    zip(20:30)
    @map t -> t[1] + t[2]
end
```

With this function, you can write: 

```julia
@chain 1:10 begin
    zip(20:30)
    @map unpack((a, b) -> a + b)
end
```
"""
unpack(f::Function) = t -> f(t...)
# unpack(f::Function, t) = f(t...)
# unpack(f::Function, t::PackedArgs) = f(t.args...; t.kwargs...)
# unpack(t, f::Function) = unpack(f, t)

"""
    @unpack(f::Function)

The macro equivalent of `unpack`. 

Enables unpacking of tuples as follows: 

```julia
@chain 1:10 begin
    zip(20:30)
    @map @unpack (a, b) -> a + b 
end
```
"""
@create_as_macro unpack


# ----------------------------------------------------------------
# Functional macros! 
# ----------------------------------------------------------------

macro filteriter(x, f)
    esc( :(Iterators.filter($f, $x)) )
end 

@create_reverse_macro map
@create_reverse_macro filter
@create_reverse_macro reduce
@create_reverse_macro foldl
@create_reverse_macro foldr
@create_reverse_macro accumulate

@create_as_macro count
@create_reverse_macro count

@create_as_macro sum 
@create_reverse_macro sum

@create_as_macro prod 
@create_reverse_macro prod

@create_as_macro minimum
@create_reverse_macro minimum

@create_as_macro maximum
@create_reverse_macro maximum

@create_as_macro any
@create_reverse_macro any

@create_as_macro all
@create_reverse_macro all

@create_as_macro extrema
@create_reverse_macro extrema

@create_as_macro argmin
@create_reverse_macro argmin

@create_as_macro argmax
@create_reverse_macro argmax

@create_reverse_macro findfirst
@create_reverse_macro findlast

@create_reverse_macro convert
@create_reverse_macro parse

# ----------------------------------------------------------------
# Unzipping
# ----------------------------------------------------------------

"""
    Unzip

A lazy type to undo zipping. Created when calling `unzip(zipped_iter)`
"""
struct Unzip
    iter
    idx
end 

"""
    unzip(zipped_iter)

Lazily unzip a zipped structure. Useful when you need to zip structures together, compute results, and then get back your original iterators. 

```
@chain [1,2,3] begin 
    zip([4,5,6]) 
    collect
    @filter @unpack (x,y) -> x + y <= 7
    unzip 
    @. collect 
end 
```
"""
unzip(iter) = tuple((Unzip(iter, i) for i in 1:length(first(iter)))...)
unzip(iter, n::Int) = Unzip(iter, n)
Base.length(unzip::Unzip) = length(unzip.iter)
Base.eltype(unzip::Unzip) = eltype(unzip.iter).parameters[unzip.idx]

function Base.iterate(unzip::Unzip, state = nothing)
    st = state === nothing ? iterate(unzip.iter) : iterate(unzip.iter, state)
    st === nothing && return nothing
    (val, new_state) = st
    return (val[unzip.idx], new_state)
end

# ----------------------------------------------------------------
# Vectorising 
# ----------------------------------------------------------------

"""
    vectorise(f::Function)

Return the vectorised form of the function. 
"""
vectorise(f::Function) = (args...; kwargs...) -> f.(args...; kwargs...)

"""
    @vec(f::Function)

Return the vectorised form of the function. Useful for ensuring vectorisation when using other utilities from the `Chainables.jl` package.
For example:  

```julia
@chain 1:3 begin 
    zip(4:6)
    @apply @vec @unpack (a, b) -> a * b^2
end 
```
"""
macro vec(f)
    esc( :($vectorise($f)) )
end 

# ----------------------------------------------------------------
# Currying 
# ----------------------------------------------------------------

struct Placeholder end 
Base.show(io::IO, x::Placeholder) = print(io, "_")

macro x()
    ph = Placeholder()
    :( $ph )
end 

struct Partial 
    f::Function
    args
    kwargs
end 

function Base.show(io::IO, partial::Partial)
    cnt = count(x -> x isa Placeholder, partial.args)
    args = @chain ["_"] begin 
        repeat(cnt)
        join(", ")
        @apply x -> isempty(x) ? "(..)" : "($x, ..)"
    end 
    all_args = @chain partial.args begin
        @. string 
        join(", ")
        @apply x -> isempty(x) ? "(.." : "($x, .."
    end
    all_kwargs = @chain partial.kwargs begin
        pairs
        collect
        @map @unpack (key, value) -> "$key = $value"
        join(", ")
        @apply x -> isempty(x) ? "..)" : "$x, ..)"
    end
    if get(io, :compact, false)
        final_args_kwargs = isempty(partial.kwargs) ? "$all_args)" : "$all_args; $all_kwargs"
        print(io, "@∂$(partial.f)")
    else 
        final_args_kwargs = isempty(partial.kwargs) ? "$all_args)" : "$all_args; $all_kwargs"
        print(io, "@∂ $args -> $(partial.f)$(final_args_kwargs)")
    end 
end 

t = (x = 1, b = 2)

pairs(t) |> collect

partial(f, args...; kwargs...) = Partial(f, args, kwargs)

function merge_tuples(orig_args, new_args)
    all_args, orig_args, new_args = [], reverse(collect(orig_args)), reverse(collect(new_args))
    while !isempty(orig_args)
        arg = pop!(orig_args)
        push!(all_args, arg isa Placeholder && !isempty(new_args) ? pop!(new_args) : arg)
    end 
    while !isempty(new_args)
        push!(all_args, pop!(new_args))
    end 
    return all_args
end

function (partial::Partial)(new_args...; new_kwargs...)
    all_args = merge_tuples(partial.args, new_args)
    all_kwargs = merge(partial.kwargs, new_kwargs)
    any(x -> x isa Placeholder, all_args) ? 
        Partial(partial.f, all_args, all_kwargs) : 
        partial.f(all_args...; all_kwargs...)
end 

macro partial(expr)
    @assert expr.head == :call "Cannot apply a partial to a non-function call"
    fn = expr.args[1]
    args = filter(expr.args[2:end]) do a 
        !(a isa Expr && a.head == :parameters)
    end 
    kwargs = filter(expr.args[2:end]) do a 
        a isa Expr && a.head == :parameters
    end 

    isempty(kwargs) ? 
        esc(Expr(:call, :partial, fn, args...)) :
        esc(Expr(:call, :partial, fn, args..., (kwargs[1].args)...))
end

var"@∂" = var"@partial"

end  # module Chainables