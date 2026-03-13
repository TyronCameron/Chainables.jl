
module TestModule
    using Chainables
    export testfunc, @testfunc

    function testfunc(f, x)
        f(x)
    end
    @chainable testfunc
end

using .TestModule

@testset "chainable is exported correctly" begin 
    let 
        arg1 = 4
        f = x -> 6 * x

        @test @testfunc(arg1, f) == testfunc(f, arg1) == 24 # last arg supplied to @testfunc is put in the front!
    end 
end 

@testset "can reverse" begin 
    let 
        f = (lambda, x) -> lambda(x)

        @test rev(f)(3, x -> x^2) == 9
        @test @chain 3 begin 
            @rev f(x -> x^2) 
            isequal(9)
        end 

        @chain 3 begin 
            y = @rev f(x -> x^2) # can still assign
        end
        @test y == 9
    end 
end 