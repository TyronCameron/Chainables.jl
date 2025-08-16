
@testset "vec" begin
    
    let 
        f = x -> 2x + 3 

        a = @chain 1:100 begin
            @apply @vec f
        end 
        b = @chain 1:100 begin
            @. f
        end

        @test a == b
    end 

end
