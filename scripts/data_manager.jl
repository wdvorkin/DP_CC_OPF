mutable struct  Generator
   ind::Int
   c::Any
   p̅::Any
   q̅::Any
   tan_ϕ::Any
   node::Int
   function Generator(ind,c,p̅,q̅,tan_ϕ,node)
      i = new()
      i.ind  = ind
      i.c = c
      i.p̅ = p̅
      i.q̅ = q̅
      i.node = node
      i.tan_ϕ = tan_ϕ
      return i
   end
end

mutable struct  Node
   ind::Int
   type::Any
   d_p::Any
   d_q::Any
   c::Any
   p̅::Any
   q̅::Any
   tan_ϕ::Any
   v̅::Any
   v̲::Any
   C::Vector{Int}
   A::Vector{Int}
   Un::Vector{Int}
   Ul::Vector{Int}
   D::Vector{Int}
   function Node(ind,type,d_p,d_q,c,p̅,q̅,tan_ϕ,v̅,v̲,C,A,Un,Ul,D)
      i = new()
      i.ind  = ind
      i.type = type
      i.d_p = d_p
      i.d_q = d_q
      i.c = c
      i.p̅ = p̅
      i.q̅ = q̅
      i.tan_ϕ = tan_ϕ
      i.v̅ = v̅
      i.v̲ = v̲
      i.C = C
      i.A = A
      i.Un = Un
      i.Ul = Ul
      i.D = D
      return i
   end
end

mutable struct  Line
   ind::Int
   node_f::Any
   node_t::Any
   r::Any
   x::Any
   f̅::Any
   function Line(ind,node_f,node_t,r,x,f̅)
      i = new()
      i.ind  = ind
      i.node_f = node_f
      i.node_t = node_t
      i.r = r
      i.x = x
      i.f̅ = f̅
      return i
   end
end

function load_data(caseID)
    gen_data = CSV.read("testcase/$caseID/generators.csv")
    node_data = CSV.read("testcase/$caseID/nodes.csv")
    line_data = CSV.read("testcase/$caseID/lines.csv")

    gen = Dict()
    for i in 1:size(gen_data,1)
        ind = i
        c = gen_data[i,:cost]
        p̅ = gen_data[i,:p_max]
        q̅ = gen_data[i,:q_max]
        tan_ϕ = 0.5
        node = gen_data[i,:node]
        add_gen = Generator(ind,c,p̅,q̅,tan_ϕ,node)
        gen[add_gen.ind] = add_gen
    end
    gen=SortedDict(gen)

    line = Dict()
    for i in 1:size(line_data,1)
        ind = i
        node_f = line_data[i,:node_f]
        node_t = line_data[i,:node_t]
        r = line_data[i,:r]
        x = line_data[i,:x]
        f̅ = line_data[i,:s_max]
        add_line = Line(ind,node_f,node_t,r,x,f̅)
        line[add_line.ind] = add_line
    end
    line=SortedDict(line)

    node = Dict()
    for i in 0:size(node_data,1)-1
        ind = node_data[i+1,:index]
        d_p = node_data[i+1,:d_P]
        d_q = node_data[i+1,:d_Q]
        v̅ = node_data[i+1,:v_max]
        v̲ = node_data[i+1,:v_min]
        C = Int[]
        A = Int[]
        Un = Int[]
        Ul = Int[]
        D = Int[]
        for l in 1:size(line_data,1)
            line[l].node_f == i ? push!(C,line[l].node_t) : NaN
            line[l].node_t == i ? push!(A,line[l].node_f) : NaN
        end
        type = 2
        c = 0
        p̅ = 0
        q̅ = 0
        tan_ϕ = 0
        for g in 1:size(gen_data,1)
            if gen[g].node == i
                type = 1
                c =  gen[g].c
                p̅ = gen[g].p̅
                q̅ = gen[g].q̅
                tan_ϕ = gen[g].tan_ϕ
            end
        end
        add_node = Node(ind,type,d_p,d_q,c,p̅,q̅,tan_ϕ,v̅,v̲,C,A,Un,Ul,D)
        node[add_node.ind] = add_node
    end
    node=SortedDict(node)

    R = zeros(length(line),length(line)) # upstream lines (path to the root)
    for i in 0:length(node)-1
        j = i
        while j != 0
            R[i,j] = 1
            j = node[j].A[1]
        end
    end

    D_n = [
    1	1	1	1	1	1	1	1	1	1	1	1	1	1
    0	1	1	1	1	1	1	1	1	1	1	0	0	0
    0	0	1	1	1	1	1	1	1	1	1	0	0	0
    0	0	0	1	1	1	1	1	1	1	1	0	0	0
    0	0	0	0	1	1	0	0	0	0	0	0	0	0
    0	0	0	0	0	1	0	0	0	0	0	0	0	0
    0	0	0	0	0	0	0	0	0	0	0	0	0	0
    0	0	0	0	0	0	0	0	0	0	0	0	0	0
    0	0	0	0	0	0	1	0	1	1	1	0	0	0
    0	0	0	0	0	0	0	0	0	1	1	0	0	0
    0	0	0	0	0	0	0	0	0	0	1	0	0	0
    0	0	0	0	0	0	0	0	0	0	0	0	0	0
    0	0	0	0	0	0	0	0	0	0	0	0	1	1
    0	0	0	0	0	0	0	0	0	0	0	0	0	1
    0	0	0	0	0	0	0	0	0	0	0	0	0	0
    ]

    U_n = [
    0	0	0	0	0	0	0	0	0	0	0	0	0	0
    1	0	0	0	0	0	0	0	0	0	0	1	1	1
    1	1	0	0	0	0	0	0	0	0	0	1	1	1
    1	1	1	0	0	0	0	0	0	0	0	1	1	1
    1	1	1	1	0	0	1	1	1	1	1	1	1	1
    1	1	1	1	1	0	1	1	1	1	1	1	1	1
    1	1	1	1	1	1	1	1	1	1	1	1	1	1
    1	1	1	1	1	1	1	1	1	1	1	1	1	1
    1	1	1	1	1	1	0	1	0	0	0	1	1	1
    1	1	1	1	1	1	1	1	1	0	0	1	1	1
    1	1	1	1	1	1	1	1	1	1	0	1	1	1
    1	1	1	1	1	1	1	1	1	1	1	1	1	1
    1	1	1	1	1	1	1	1	1	1	1	1	0	0
    1	1	1	1	1	1	1	1	1	1	1	1	1	0
    1	1	1	1	1	1	1	1	1	1	1	1	1	1
    ]

    D_l = [
    0	0	0	0	0	0	0	0	0	0	0	0	0	0
    1	0	0	0	0	0	0	0	0	0	0	0	0	0
    1	1	0	0	0	0	0	0	0	0	0	0	0	0
    1	1	1	0	0	0	0	0	0	0	0	0	0	0
    1	1	1	1	0	0	0	0	0	0	0	0	0	0
    1	1	1	1	1	0	0	0	0	0	0	0	0	0
    1	1	1	1	1	1	0	0	0	0	0	0	0	0
    1	1	1	0	0	0	1	1	0	0	0	0	0	0
    1	1	1	0	0	0	0	1	0	0	0	0	0	0
    1	1	1	0	0	0	0	1	1	0	0	0	0	0
    1	1	1	0	0	0	0	1	1	1	0	0	0	0
    1	1	1	0	0	0	0	1	1	1	1	0	0	0
    0	0	0	0	0	0	0	0	0	0	0	1	0	0
    0	0	0	0	0	0	0	0	0	0	0	1	1	0
    0	0	0	0	0	0	0	0	0	0	0	1	1	1
    ]

    U_l = [
    1	1	1	1	1	1	1	1	1	1	1	1	1	1
    0	1	1	1	1	1	1	1	1	1	1	1	1	1
    0	0	1	1	1	1	1	1	1	1	1	1	1	1
    0	0	0	1	1	1	1	1	1	1	1	1	1	1
    0	0	0	0	1	1	1	1	1	1	1	1	1	1
    0	0	0	0	0	1	1	1	1	1	1	1	1	1
    0	0	0	0	0	0	1	1	1	1	1	1	1	1
    0	0	0	1	1	1	0	0	1	1	1	1	1	1
    0	0	0	1	1	1	1	0	1	1	1	1	1	1
    0	0	0	1	1	1	1	0	0	1	1	1	1	1
    0	0	0	1	1	1	1	0	0	0	1	1	1	1
    0	0	0	1	1	1	1	0	0	0	0	1	1	1
    1	1	1	1	1	1	1	1	1	1	1	0	1	1
    1	1	1	1	1	1	1	1	1	1	1	0	0	1
    1	1	1	1	1	1	1	1	1	1	1	0	0	0
    ]
    T = D_n .- U_n
    return node,line,R,D_n,U_n,U_l,D_l,T
end
