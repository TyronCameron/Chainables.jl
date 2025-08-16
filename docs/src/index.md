# Chainables.jl

Chainables is a package to help you `@chain` (from `Chain.jl`) things together better. This package is inspired by the awesome work done by `Chain.jl` as well as `DataFramesMeta.jl`. I love the concept of chaining functions in the order of execution, and I think it makes code much easier to reason about. 

This packages adds a few utilities to that way of thinking. 

You can install this package by pressing `]` in the Julia REPL and writing `add <github repo>`. 

This package reexports `@chain` and provides:

- A slightly more pleasant way to write anonymous functions (lambdas) during chaining. It does this mainly with `@apply`, `with`. 
- Packing and unpacking of arguments, namely with `@pack`, `@unpack`. The latter simply packs varargs into a tuple, and the latter unpacks a tuple into varargs in a function definition. Useful if you want to splat a tuple into a chained function. 
- Reverse-argument macro-versions of common iterator functions. While the base Julia versions accept a function as the first argument, these accept the iterator as the first argument, allowing simpler chaining. `@filteriter`, `@map`, `@filter`, `@reduce`, `@foldl`, `@foldr`, `@accumulate`. It also provides a macro `@rev` to reverse your own functions and macros on-the-fly.
- Reverse-argument aggregation functions, such as `@count`, `@sum`, `@prod`, `@minimum`, `@maximum`, `@any`, `@all`, `@extrema`, `@argmin`, `@argmax`, `@findfirst`, `@findlast`
- Reverse-argument conversions and parsing, just in case you needed them: `@convert`, `@parse`,
- A handy `unzip` tool, allowing you to create a lazy iterator over a zipped iterator! Useful if you wanted to zip, do some transformations, and get back the unzipped iterators. 
- `vectorise`, `@vec` as a simple was of wrapping a function to be in a vectorised form. 
- Nice partial application (currying) of functions, with `@x`, `@∂`, `partial`, `@partial`, `Placeholder`

## Anonymous function chaining

Old way: 

```julia
@chain 5 begin	
	(x -> x^2 + 10)()
end 
```

New way: 

```julia
using Chainables

# for small anon functions 
@chain 5 begin 
	@apply x -> x^2 + 10
end

# for big ugly anon functions
@chain 5 begin 
	@apply with() do x 
		x^2 + 10
	end 
end
```

## Packing and unpacking

Imagine we wanted to filter one array based on another. There are lots of ways to do this, but one of them is to use zipping, filtering, and then mapping back to one of the zipped iterators. 

```julia
@chain 1:10 begin
    zip(21:30)
	collect
    filter(t -> t[2] <= 25, _)
    map(t -> t[1], _)
end
```

With this package, you can instead write: 

```julia
@chain 1:10 begin
    zip(21:30)
	collect
    @filter @unpack (a, b) -> b <= 25
	@map @unpack (a, b) -> a
end
```
 
## Reverse-argument macros

You can reverse any function or macro like this: 

```julia
@chain 1:100 begin
	@rev reduce(+)
end 

@chain 1:100 begin
	tempval = @rev reduce(+)
end 

@chain 1:100 begin
	@rev @info "abc"
end 

@chain 1:100 begin
	tempval = @rev @pack "abc"
end 
```

But I did it in a very nice way for the common ones already. 

Old way:

```julia
@chain 1:100 begin
	map(x -> x^2, _)
	filter(x -> x < 80, _)
	count(x -> x % 2 == 0, _)
end 
```

New way:

```julia
@chain 1:100 begin
	@map x -> x^2
	@filter x -> x < 80
	@count x -> x % 2 == 0
end 
```

Naturally this comes with all the bells and whistles, such as kwargs. For example, let's say we wanted to figure out the maximum strength of each level, when not ceding, in the Hierarchy in the book "The Will of the Many". We might wish for an initialising variable. 

```julia
@chain 8:-1:1 begin
	@accumulate init = 0 with() do child_strength, level
		child_strength * (level + 1) / 2 + 1
	end 
end 
```

If the `with()` is confusion, just remember that `with() do args expr end` is the same as `(args) -> expr`, but it gives you access to a nice big block to write more complicated code. 

It doesn't matter where you put the kwargs when calling these macros. Anything of the form `a = b` will be treated as a kwarg. 

## Partial application

This is broader than chaining, but I think it's related, because it relates to composition, and completes out the `@pack`, `@unpack` and `@chain` ideas. 

The idea is just to simplify creating new lambas. 

```julia
function foo(a,b,c; kw = 13)
	a + b + c + kw
end 
```

Now you might know the values of `b` and `c`, but want to vary `a`. Therefore, you would create a new function:

```julia
foo_lambda = a -> foo(a, 11, 12; kw = 14)
```

Then you can call it later and have a happy life:

```julia
foo_lambda.(1:10) # a is varying, the other vars are fixed
```

Alternatively, you can use partial application. Now this package provides two ways to do this. The first is simply a nice way to generate these lambda functions. The second way creates a wrapper, which is good if you want repeated partial application, which is admittedly a rare circumstance. 

The first way is the simpler (and faster) way as it just takes in a function and returns a function: 

```julia
foo_partial = partial(foo, @x, 11, 12; kw = 14) # @x denotes the "varying" argument(s)
```

Or in shorthand:

```julia
foo_partial = @∂ foo(@x, 11, 12; kw = 14)
foo_partial(10)
@assert foo_partial(10) == foo_lambda(10)
```

You can also use `@partial` instead of `@∂` in case you like having the full word around. 

This is pretty stylish in and of itself, but it can have an application when chaining too:

```julia
baz(x) = (x^2, x^3) # a function with two outputs

first = @chain 10 begin
	baz # returns 2 values
	@unpack @∂ foo(@x, 12, @x; kw = 20) # choose exactly where those two args go into the subsequent function
end 

# Now let's check that we're still getting the right result
a, b = baz(10)
second = foo(a, 12, b; kw = 20)

@assert first == second 
```

Finally, there is another way to do partial application. We create a `Partial` type which can be called like any regular function. 

```julia
foo_Partial = Partial(foo)
foo_Partial(1; kw = 20) # automatically figures out where the placeholders are needed
foo_Partial(1)(2) # still a Partial
foo_Partial(1)(2)(3) # still a Partial
foo_Partial(1)(2)(3)() # the last empty value returns a value

# alternatives
@assert foo_Partial(1, @x)(2)(3)() == foo(1, 2, 3) # exhause items, can use placeholders
@assert λ(foo_Partial(1)(2))(3) == foo(1, 2, 3) # convert back to regular lambda
@assert apply(foo_Partial(1)(2), 3; kw = 10) == foo(1,2,3; kw = 10) # apply works on this too! 
```

This `Partial` type causes more overhead than using the plain functions. However, it provides additional convenience for repeated calls, printing, and arg checking before you actually call the function. 
