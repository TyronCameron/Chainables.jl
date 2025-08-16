"""
Chainables.jl is a library for working better with Chain.jl 
"""
module Chainables
import Chain: @chain
export 
    @chain, 
    apply, @apply, with, rev, @rev,
    pack, @pack, unpack, @unpack,
    @filteriter, @map, @filter, @reduce, @foldl, @foldr, @accumulate, 
    @count, @sum, @prod, 
    @minimum, @maximum, @any, @all, 
    @extrema, @argmin, @argmax, 
    @findfirst, @findlast, 
    @convert, @parse,
    unzip,
    vectorise, @vec,
    @x, @∂, partial, @partial, Partial, Placeholder, λ

# ----------------------------------------------------------------
# Utilities for this module
# ----------------------------------------------------------------

macro create_reverse_macro(function_name)
    quote 
        macro $function_name(args...)
            f = $function_name
            posargs, kwargs = get_posargs_kwargs(args)
            a = posargs[1]
            b = posargs[end]
            Expr(:call, f, b, a, kwargs...) |> esc
        end 
    end |> esc
end 

function get_posargs_kwargs(args)
    kwargs = []
    positional = []
    for arg in args
        if arg isa Expr && arg.head == :(=) && arg.args[1] isa Symbol
            push!(kwargs, Expr(:kw, arg.args[1], arg.args[2]))
        else
            push!(positional, arg)
        end
    end
    return (positional, kwargs)
end 

macro create_macro(function_name)
    quote
        macro $function_name(args...)
            posargs, kwargs = get_posargs_kwargs(args)
            Expr(:call, $function_name, posargs..., kwargs...) |> esc
        end
    end |> esc
end 

# ----------------------------------------------------------------
# Rev and apply
# ----------------------------------------------------------------

"""
    rev(f::Function)

Rearrange the inputs to `f` such that the original first arg is now the last one.
"""
rev(f::Function) = (args...; kwargs...) -> begin 
    new_args = (args[2:end]..., args[1])
    f(new_args...; kwargs...)
end
revcall(arg, expr) = Expr(expr.head, expr.args..., arg)
revassignment(arg, expr) = Expr(expr.head, expr.args[1], revcall(arg, expr.args[2]))

"""
    @rev(arg, expr)

Rearrange arg to go into the expr. Useful for doing this kind of thing: 

```julia
@chain 1:100 begin 
    @rev reduce(+)
end 
```

"""
macro rev(arg, expr)
    if expr isa Symbol
        Expr(:call, expr, arg)
    elseif expr.head ∈ (:call, :macrocall)
        revcall(arg, expr)
    elseif expr.head == :(=) && expr.args[2].head ∈ (:call, :macrocall)
        revassignment(arg, expr)
    end |> esc
end 

"""
    apply(f, args...; kwargs...)

Simply apply `f` with the `args` and `kwargs` given. 
"""
apply(f, args...; kwargs...) = f(args...; kwargs...)

"""
    @apply(x, f)

Apply `f` to `x`. Useful when chaining. For example, imagine we want the first letter of the second word in the following sentence: 

```julia
x = @chain "Hello Fine Ladies" begin 
    split.(" ")
    @apply x -> x[2][1]
end 
@assert x == 'F'
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
with(f::Function, args...; kwargs...) = (fargs...) -> f(fargs..., args...; kwargs...)

# ----------------------------------------------------------------
# Packing and unpacking
# ----------------------------------------------------------------

"""
    pack(args...)

Simply return the args in a tuple. 
"""
pack(args...) = args

"""
    @pack(args...)

Simply returns the args in a tuple.
"""
@create_macro pack 

"""
    unpack(f::Function)

Return a valid form of `f` that can destructure its args. Also see @unpack. 
Without this function you may find yourself working with tuples as a single argument to a function.

For instance, the usage of `t[1]` and `t[2]` in the following is untasty. 

```julia
@chain 1:10 begin
    zip(20:30)
    @map t -> t[1] + t[2]
end
```

With this function, you write something equally untasty: 

```julia
@chain 1:10 begin
    zip(20:30)
    @map unpack((a, b) -> a + b)
end
```

See @unpack for something better.
"""
unpack(f) = t -> f(t...)
unpack(f::Function, t::Tuple) = f(t...)
unpack(t::Tuple, f::Function) = unpack(f, t)

"""
    @unpack(f::Function)

The macro equivalent of `unpack`. 

Enables unpacking of tuples. For instance, the usage of `t[1]` and `t[2]` in the following is untasty. 

```julia
@chain 1:10 begin
    zip(20:30)
    @map t -> t[1] + t[2]
end
```

With this macro, you write something tasty: 

```julia
@chain 1:10 begin
    zip(20:30)
    @map @unpack (a, b) -> a + b 
end
```

This uses splatting under the hood so it's not too efficient for a high number of args. For a small number of args, this is good. 
"""
@create_macro unpack


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

@create_reverse_macro count
@create_reverse_macro sum
@create_reverse_macro prod
@create_reverse_macro minimum
@create_reverse_macro maximum
@create_reverse_macro any
@create_reverse_macro all
@create_reverse_macro extrema
@create_reverse_macro argmin
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
vectorise(f) = (args...; kwargs...) -> f.(args...; kwargs...)

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

"""
    Placeholder 

A simple type to represent a placeholder in a partially applied function. 
"""
struct Placeholder end 
Base.show(io::IO, x::Placeholder) = print(io, "_")

"""
    @x 

A quick macro to create a placeholder variable for partial application (currying) purposes. 

@x creates a `Placeholder`, and this is recognised by:

- `partial` (the function) such as `partial(foo, arg1, @x, arg2)`
- `@partial` (the macro) such as `@partial foo(arg1, @x, arg2)`
- `@∂` such as `@∂ foo(arg1, @x, arg2)`
"""
macro x()
    :( $Placeholder() )
end 


"""
    Partial 

A lightweight struct to hold a function and its args, for the purposes of partial application.  
"""
struct Partial 
    f::Function
    args
    kwargs
end 

Partial(f, args...; kwargs...) = Partial(f, args, kwargs)
# Base.:(~)(f::Function, t::Tuple) = Partial(f, t, Dict())
# Base.:(~)(f::Function) = Partial(f)

apply(p::Partial, args...; kwargs...) = isempty(args) && isempty(kwargs) ? p(args...; kwargs...) : p(args...; kwargs...)()

function merge_tuples(a, b)
    state = 1 
    lcombined = length(a) + length(b) - min(count(x -> x isa Placeholder, a), length(b))
    ntuple(lcombined) do idx 
        if idx <= length(a) && !(a[idx] isa Placeholder) return a[idx] end 
        if idx <= length(a) && state > length(b) return a[idx] end 
        ret = b[state]
        state += 1 
        ret 
    end 
end

merge_args(f_args, f_kwargs, new_args, new_kwargs) = (merge_tuples(f_args, new_args), merge(f_kwargs, new_kwargs))

function valid_args(f, all_args)
    proposed_arity = length(all_args)
    any(methods(f)) do m
        method_arity = m.nargs - 1 
        proposed_arity == method_arity || (proposed_arity > method_arity && m.isva)
    end 
end

any_placeholders(all_args) = any(x -> x isa Placeholder, all_args)
complete_with_placeholders(arity, all_args) = (all_args..., ntuple(_ -> @x, max(arity - length(all_args), 0))...)

function complete_and_check_args(f, all_args)
    relevant_methods = filter(m -> m.nargs - 1 >= length(all_args), methods(f))
    all_args = isempty(relevant_methods) ? all_args : complete_with_placeholders(minimum(m -> m.nargs - 1, relevant_methods), all_args) 
    @assert valid_args(f, all_args) """Args are not valid in partial $(Partial(f, all_args))). This is possibly because you have supplied more placeholders than the underlying function `$(f)` can handle."""
    all_args
end 

function (partial::Partial)(new_args...; new_kwargs...)
    if isempty(new_args) && isempty(new_kwargs) return partial.f(partial.args...; partial.kwargs...) end 
    all_args, all_kwargs = merge_args(partial.args, partial.kwargs, new_args, new_kwargs)
    all_args = complete_and_check_args(partial.f, all_args)
    Partial(partial.f, all_args, all_kwargs)
end

"""
    λ(partial::Partial)

Convert the partial back into a function. 
"""
λ(p::Partial) = (new_args...; new_kwargs...) -> apply(p, new_args...; new_kwargs...)


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

"""
    partial(f, args...; kwargs...)

Create a `Partial` (a partially applied function). For more convenience, see `@partial` or `@∂`. 
    
Example:

```julia
f(a,b) = 2*a + b
f_partial = partial(f, 3) # put 3 in place of a 
@assert f_partial(1) == f(3, 1)
```

This can handle varargs and kwargs: 

```julia
foo(args...; kwargs...) = sum(args) + length(kwargs) 
foo_partial = @∂ foo(10, 10; a = 5)
foo_partial(20; b = 7) == foo(10,10,20; a = 5, b = 7) == 42
```

You can choose where the positional arguments get curried to with use of `@x`.

```julia
foo_partial_2 = @∂ foo(10, @x; a = 5)
foo_partial_2(30; b = 7) == foo(10,30; a = 5, b = 7) == 42
```

If you have not fully exhausted the list of unknown placeholders, and you call a `Partial`, you will get back a `Partial`. 
As such:

```julia 
foo_partial_3 = @∂ foo(1,@x,@x,@x)
foo_partial_4 = foo_partial_3(10)
final_answer = foo_partial_4(30)(1)
@assert final_answer == foo(1,10,30,1) == 42
```

You can chain partials together as follows: 

```julia 
bar(args...) = sum(args)

b1 = @∂ bar(6,@x,2,@x,@x,12)
b2 = @∂ b1(5,10) 
b3 = @∂ b1(@x,10,7)

@assert @all [
    b1(5,10,7)
    b2(7)
    b3(5)
] @∂ ==(42) 
```
"""
partial(f::Partial, args...; kwargs...) = Partial(f.f, merge_tuples(f.args, args), merge(f.kwargs, kwargs))
partial(f::Function, args...; kwargs...) = (new_args...; new_kwargs...) -> begin
    all_args, all_kwargs = merge_args(args, kwargs, new_args, new_kwargs)
    f(all_args...; all_kwargs...)
end

"""
    @partial(expr)

A macro form of the `partial` function. See that function for further documentation. 

```julia
foo(varargs...) = sum(varargs)
p1 = @partial foo(1)
p2 = @∂ foo(1)
p3 = partial(foo, 1)
@assert p1 == p2 == p3 
```
"""
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

"""
    @∂(expr)

See `@partial` or `partial`. 
"""
var"@∂" = var"@partial"

end  # module Chainables