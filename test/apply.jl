using .Chainables
using Test

@testset "apply" begin
    
    a = @chain 1:100 begin
        @apply x -> sum(x)
    end 
    b = sum(1:100)
    @test a == b

    let 
        x = 5 
        
        a = @chain x begin
            @apply x -> x^2
        end 
        b = x^2

        @test a == b 
    end 

end

@testset "with" begin
    
    a = @chain 1:100 begin
        @apply with() do x 
            2*x
        end 
        maximum
    end 
    @test a == 200

    let 
        x = 5 
        a = @chain x begin
            @apply with() do x 
                x^2
            end 
        end 
        @test a == x^2
    end 

    a = @chain 1:100 begin
        @apply with(20) do x, y
            2*x .+ y
        end 
        maximum
    end 
    @test a == 220

end
