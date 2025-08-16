


@testset "partial" begin
    let 
        function foo(a,b,c; kw = 13)
            a + b + c + kw
        end 

        foo_lambda = a -> foo(a, 11, 12; kw = 14)
        foo_partial1 = partial(foo, @x, 11, 12; kw = 14) # @x denotes the "varying" argument(s)
        foo_partial2 = @∂ foo(@x, 11, 12; kw = 14)
        @test foo_partial1(10) == foo_partial2(10) == foo_lambda(10)
        @test foo_partial1 isa Function 
        @test foo_partial2 isa Function 

        baz(x) = (x^2, x^3) # a function with two outputs
        first = @chain 10 begin
            baz # returns 2 values
            @unpack @∂ foo(@x, 12, @x; kw = 20) # choose exactly where those two args go into the subsequent function
        end 

        # Now let's check that we're still getting the right result
        a, b = baz(10)
        second = foo(a, 12, b; kw = 20)
        @test first == second 

        foo_Partial = Partial(foo)
        @test foo_Partial(1; kw = 20) isa Partial # automatically figures out where the placeholders are needed
        @test foo_Partial(1)(2) isa Partial # still a Partial
        @test foo_Partial(1)(2)(3) isa Partial # still a Partial
        @test foo_Partial(1)(2)(3)() isa Int # the last empty value returns a value

        # alternatives
        @test foo_Partial(1, @x)(2)(3)() == foo(1, 2, 3)
        @test λ(foo_Partial(1)(2))(3) == foo(1, 2, 3)
        @test apply(foo_Partial(1)(2), 3; kw = 10) == foo(1,2,3; kw = 10)

        # foo_Partial = ~foo 
        # foo_some_Partial = foo~(1,@x,3)

        # @assert foo_Partial(1,2,3)() == foo_some_Partial(2)() == foo(1,2,3)
    end 
end 

