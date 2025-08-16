

@testset "unzip" begin
    
    z = zip(1:100, -1:-1:-100)

    (a, b) = unzip(z)

    @test @chain a begin
        @all a -> a > 0
    end

    @test @chain b begin
        @all b -> b < 0
    end

end


