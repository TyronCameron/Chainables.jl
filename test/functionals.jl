
@testset "Functionals" begin
    
    @test @chain 1:100 begin
        @map x -> x^2
        @filter x -> x < 80
        @reduce init = 100 with(+)
        @pack 10 
        @sum x -> x
        isequal(100 + 1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 10)
    end 

    let 
        levels = 8:-1:1
        parent_strength(child_strength, level) = child_strength * (level + 1) / 2 + 1

        @test @chain levels begin
            @accumulate init = 0 parent_strength
            isequal([1.0,5.0,18.5,56.5,142.25,285.5,429.25,430.25])
        end 
    end 

end

@testset "rev" begin
    let 
        f = reduce

        x = @chain 1:100 begin
            @rev f(+)
        end 

        @chain 1:100 begin
            t1 = @rev f(+)
        end 

        @test x == t1 == reduce(+, 1:100)

        y = @chain "def" begin
            @rev @pack "abc"
        end 

        @chain "def" begin
            t2 = @rev @pack "abc"
        end 

        @test y == t2 == ("abc", "def")
    end 
end