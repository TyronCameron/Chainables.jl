
@testset "convert" begin
    
    @test @chain 1 begin
        @convert Float32
        @apply x -> x isa Float32
    end 

    let 
        str = "122"
        type = Int
        @test @chain str begin
            @parse type
            @apply x -> x isa Int
        end 
    end 

end

