@testset "BondGraph Properties" begin
    bg = BondGraph()
    @test bg.name == :BG
    @test isempty(bg.nodes)
    @test eltype(bg) == AbstractNode
    @test edgetype(bg) == Graphs.AbstractSimpleEdge{Integer}
    @test is_directed(bg)
end

@testset "Adding and removing elements" begin
    c = Component(:C, :C1)
    r = Component(:R, :C1, numports = 1)
    j = EqualEffort()

    bg = BondGraph()

    @test add_vertex!(bg, c)
    b = add_edge!(bg, c, j)

    @test src(b) == vertex(c)
    @test dst(b) == vertex(j)

    add_vertex!(bg, r)
    add_vertex!(bg, j)

    @test ne(bg) == 1
    @test has_edge(bg, vertex(c), vertex(j))
    @test !has_edge(bg, vertex(c), vertex(r))

    @test nv(bg) == 3
    @test has_vertex(bg, j)

    @test inneighbors(bg, vertex(c)) == []
    @test outneighbors(bg, vertex(c)) == [3]

    @test rem_edge!(bg, c, j) == b
    @test ne(bg) == 0
    @test rem_vertex!(bg, r)
    @test nv(bg) == 2
end

@testset "BondGraphNode" begin
    bg = BondGraph(:RCI)
    bgn = BondGraphNode(bg)

    @test bgn.type == :BG
    @test bgn.name == :RCI
    @test bgn.freeports == Bool[]
end

@testset "Printing" begin
    C = Component(:C)
    SS = Component(:SS, :Source)
    J0 = EqualEffort(name = :J)
    b1 = Bond(C, J0)
    b2 = Bond(J0, SS)
    bg = BondGraph(:newbg)
    bgn = BondGraphNode(bg)

    # repr returns the output of the 'show' function
    @test repr(C) == "C:C"
    @test repr(SS) == "SS:Source"
    @test repr(b1) == "Bond C:C ⇀ J"
    @test repr(b2) == "Bond J ⇀ SS:Source"
    @test repr(bg) == "BondGraph BG:newbg (0 Nodes, 0 Bonds)"
    @test repr(bgn) == "BG:newbg"

    add_vertex!(bg, C)
    add_vertex!(bg, SS)
    add_vertex!(bg, J0)
    add_edge!(bg, C, J0)
    add_edge!(bg, J0, SS)
    @test repr(bg) == "BondGraph BG:newbg (3 Nodes, 2 Bonds)"
end

@testset "LightGraph Extra Functions" begin
    c1 = Component(:C)
    c2 = Component(:R)
    c3 = Component(:I)
    j = EqualFlow()

    bg = BondGraph()

    add_vertex!(bg, c1)
    add_vertex!(bg, c2)
    add_vertex!(bg, c3)
    add_vertex!(bg, j)

    add_edge!(bg, c1, j)
    add_edge!(bg, j, c2)
    add_edge!(bg, j, c3)

    # Testing on a selection of common graph functions
    @test Δ(bg) == 3
    @test Graphs.density(bg) == 0.25
    @test Array(adjacency_matrix(bg)) == [0 0 0 1; 0 0 0 0; 0 0 0 0; 0 1 1 0]
end