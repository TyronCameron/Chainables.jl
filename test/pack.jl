
@testset "pack and unpack" begin
    
    a = @chain 10 begin
        @pack 20 30 
    end 
    
    @test a == (10,20,30)

    @test @chain 10 begin
        @pack 20 30 
        @apply @unpack min
        isequal(10)
    end

    let 
        y = 5

        @test @chain 10 begin
            @pack y 30 
            @apply @unpack min
            isequal(y)
        end 
    end 

end

