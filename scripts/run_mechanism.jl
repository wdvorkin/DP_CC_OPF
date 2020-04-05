function run_mechanism(mechanism,node,line,σ,Σ,T,U_n,D_n,U_l,D_l,η_g,η_u,η_f,ψ,σ̂,θ,ϱ)
    mechanism == "D_OPF" ? Σ = Σ .* 0 .+ 1e-10 : NaN
    mechanism == "D_OPF" ? σ = σ .* 0 .+ 1e-10 : NaN
    # functions to return inverse CDF and PDF of the SND at x'th quantile
    Φ(x) = quantile(Normal(0,1),x)
    ϕ(x) = 1/(sqrt(2*π))*exp(-x^2/2)
    # inner polygon coefficients for power flow constraints
    α_f = [1 1 0.2679 -0.2679 -1 -1 -1 -1 -0.2679 0.2679 1 1]
    β_f = [0.2679 1 1 1 1 0.2679 -0.2679 -1 -1 -1 -1 -0.2679]
    δ_f = [-1 -1.366 -1 -1 -1.366 -1 -1 -1.366 -1 -1 -1.366 -1]
    # sets
    C = 1:length(α_f)
    N = 0:length(node)-1
    L = 1:length(node)-1
    PV_bus=Int[]
    PQ_bus=Int[]
    PV_bus_wo_root=Int[]
    for i in N
        node[i].type==1 ? push!(PV_bus,i) : NaN
        node[i].type==2 ? push!(PQ_bus,i) : NaN
        if i != 0
            node[i].type==1 ? push!(PV_bus_wo_root,i) : NaN
        end
    end
    # build optimization model
    m = Model(Mosek.Optimizer)
    set_optimizer_attributes(m, "LOG" => 0)
    # variables
    @variable(m, g_p[PV_bus])
    @variable(m, g_q[PV_bus])
    @variable(m, α[N,L])
    @variable(m, f_p[L])
    @variable(m, f_q[L])
    @variable(m, u[N])
    @variable(m, t[L])
    @variable(m, τ[L])
    @variable(m, σ_c)
    @variable(m, CVaR)
    # objective function
    mechanism == "D_OPF" ?        @objective(m, Min, sum(node[i].c*g_p[i] for i in PV_bus))                             : NaN
    mechanism == "CC_OPF" ?       @objective(m, Min, sum(node[i].c*g_p[i] for i in PV_bus))                             : NaN
    mechanism == "ToV_CC_OPF" ?   @objective(m, Min, sum(node[i].c*g_p[i] for i in PV_bus) + ψ*sum(t[i] for i in L))    : NaN
    mechanism == "TaV_CC_OPF" ?   @objective(m, Min, sum(node[i].c*g_p[i] for i in PV_bus) + ψ*sum(τ[i] for i in L))    : NaN
    mechanism == "CVaR_CC_OPF" ?  @objective(m, Min, sum(node[i].c*g_p[i] for i in N)*(1-θ) + CVaR*θ)                   : NaN
    # deterministic constraints
    @constraint(m, root_p[i=0], g_p[i] == sum(f_p[j] for j in node[i].C))
    @constraint(m, root_q[i=0], g_q[i] == sum(f_q[j] for j in node[i].C))
    @constraint(m, root_v[i=0], u[i] == 1)
    @constraint(m, flow_p_PV[i=PV_bus_wo_root], f_p[i] == node[i].d_p - g_p[i] + sum(f_p[j] for j in node[i].C))
    @constraint(m, flow_q_PV[i=PV_bus_wo_root], f_q[i] == node[i].d_q - g_q[i] + sum(f_q[j] for j in node[i].C))
    @constraint(m, flow_p_PQ[i=PQ_bus], f_p[i] == node[i].d_p + sum(f_p[j] for j in node[i].C))
    @constraint(m, flow_q_PQ[i=PQ_bus], f_q[i] == node[i].d_q + sum(f_q[j] for j in node[i].C))
    @constraint(m, volt[i=L], 1/2*(u[node[i].A[1]] - u[i]) == f_p[i]*line[i].r + f_q[i]*line[i].x)
    @constraint(m, gen_p[i=PV_bus], 0 <= g_p[i] <= node[i].p̅)
    @constraint(m, gen_q[i=PV_bus], 0 <= g_q[i] <= node[i].q̅)
    @constraint(m, p_q_f[i=PV_bus_wo_root], g_q[i] == g_p[i]*node[i].tan_ϕ)
    @constraint(m, volt_lim[i=N], node[i].v̲ <= u[i] <= node[i].v̅)
    @constraint(m, flow_f̅[i=L,c=C], α_f[c]*f_p[i] + β_f[c]*f_q[i] + δ_f[c]*line[i].f̅ <= 0)
    @constraint(m, α_PQ[i=PQ_bus,j=L], α[i,j] == 0)
    @constraint(m, α_zero[i=PV_bus,j=L;T[i+1,j]==0], α[i,j] == 0)
    # CVaR declaration
    @constraint(m, CVaR == sum(node[i].c*g_p[i] for i in N) + σ_c*ϕ(Φ(1-ϱ))/(ϱ))
    # affine policy constraints
    @constraint(m, up_stream_bal[i=L], sum(α[j,i] for j in PV_bus if U_l[j+1,i] == 1) == 1)
    @constraint(m, dw_stream_bal[i=L], sum(α[j,i] for j in PV_bus if D_l[j+1,i] == 1) == 1)
    # generator chance constraints
    for i in PV_bus
        arg_p=[]
        arg_q=[]
        for j in L
            arg_p=push!(arg_p,Φ(1-η_g)*σ[j]*α[i,j]*T[i+1,j])
            arg_q=push!(arg_q,Φ(1-η_g)*σ[j]*α[i,j]*T[i+1,j]*node[i].tan_ϕ)
        end
        g_p_max_soc=vcat(node[i].p̅ - g_p[i],arg_p)
        g_q_max_soc=vcat(node[i].q̅ - g_q[i],arg_q)
        g_p_min_soc=vcat(g_p[i] - 0,arg_p)
        g_q_min_soc=vcat(g_q[i] - 0,arg_q)
        @constraint(m, g_p_max_soc in SecondOrderCone())
        @constraint(m, g_q_max_soc in SecondOrderCone())
        @constraint(m, g_p_min_soc in SecondOrderCone())
        @constraint(m, g_q_min_soc in SecondOrderCone())
    end
    # voltage chance constraints
    for i in L
        arg = []
        norm = 2*sum(line[j].r*(T[j+1,:].*Array(α[j,:]) + sum(D_n[j+1,k]*(T[k+1,:].*Array(α[k,:])) for k in L)) + line[j].x*(T[j+1,:].*Array(α[j,:])*node[j].tan_ϕ + sum(D_n[j+1,k]*(T[k+1,:].*Array(α[k,:])*node[k].tan_ϕ) for k in L)) for j in L if R[i,j] == 1)
        for j in L
            arg=push!(arg,@expression(m, Φ(1-η_u)*norm[j]*σ[j]))
        end
        u_max_soc = vcat(node[i].v̅ - u[i],arg)
        u_min_soc = vcat(u[i] - node[i].v̲,arg)
        @constraint(m, u_max_soc in SecondOrderCone())
        @constraint(m, u_min_soc in SecondOrderCone())
    end
    # power flow chance constraints
    for i in L, c in C
        arg = []
        norm = α_f[c]*(T[i+1,:].*Array(α[i,:]) + sum(D_n[i+1,j]*T[j+1,:].*Array(α[j,:]) for j in L)) + β_f[c]*(T[i+1,:].*Array(α[i,:])*node[i].tan_ϕ + sum(D_n[i+1,j]*T[j+1,:].*Array(α[j,:])*node[j].tan_ϕ for j in L))
        for j in L
            arg=push!(arg,@expression(m, Φ(1-η_f)*norm[j]*σ[j]))
        end
        f_max_soc=vcat(- α_f[c]*f_p[i] - β_f[c]*f_q[i] - δ_f[c]*line[i].f̅,arg)
        @constraint(m, f_max_soc in SecondOrderCone())
    end
    # cost standard deviation constraints
    for index in 1
        arg = []
        norm = sum(node[i].c*T[i+1,:].*Array(α[i,:]) for i in N)
        for i in L
            arg = push!(arg, @expression(m, norm[i]*σ[i]))
        end
        @constraint(m, vcat(σ_c-0,arg) in SecondOrderCone())
    end
    # power flow standard deviation constraints
    if mechanism == "ToV_CC_OPF"
        for i in L
            arg = []
            norm = T[i+1,:].*Array(α[i,:]) + sum(D_n[i+1,j]*T[j+1,:].*Array(α[j,:]) for j in L)
            for j in L
                arg = push!(arg,@expression(m,norm[j]*σ[j]))
            end
            var_control=vcat(t[i]-0,arg)
            @constraint(m, var_control in SecondOrderCone())
        end
    end
    if mechanism == "TaV_CC_OPF"
        for i in L
            arg = []
            norm = T[i+1,:].*Array(α[i,:]) + sum(D_n[i+1,j]*T[j+1,:].*Array(α[j,:]) for j in L)
            for j in L
                arg = push!(arg,@expression(m,norm[j]*σ[j]))
            end
            var_control=vcat(t[i]-0,arg)
            @constraint(m, var_control in SecondOrderCone())
        end
        for i in L
            @constraint(m, [τ[i]-0,t[i]-σ̂[i]] in SecondOrderCone())
        end
    end
    # solve optimization model
    optimize!(m)
    CPU_time =  MOI.get(m, MOI.SolveTime())
    status=termination_status(m)
    @info("$(mechanism) terminates with status $(status)")
    # prepare results
    output = DataFrame(i=Any[],d_p=Any[],g_p=Any[],g_p_σ=Any[],g_q=Any[],g_q_σ=Any[],f_p=Any[],f_p_σ=Any[],f_q=Any[],f_q_σ=Any[],u=Any[],u_σ=Any[],v=Any[])
    for i in N
        gen_p_std = sqrt((T[i+1,:].*Array(JuMP.value.(α[i,:])))'*Σ*(T[i+1,:].*Array(JuMP.value.(α[i,:]))))
        gen_q_std = sqrt((T[i+1,:].*Array(JuMP.value.(α[i,:])).*node[i].tan_ϕ)'*Σ*(T[i+1,:].*Array(JuMP.value.(α[i,:])).*node[i].tan_ϕ))
        if i == 0
            push!(output,[i,node[i].d_p,JuMP.value(g_p[i]),gen_p_std,JuMP.value(g_q[i]),gen_q_std,"---","---","---","---",JuMP.value(u[i]),"---",sqrt(JuMP.value(u[i]))])
        end
        if i != 0
            u_std = sqrt(2*sum(line[j].r*(T[j+1,:].*Array(JuMP.value.(α[j,:])) + sum(D_n[j+1,k]*(T[k+1,:].*Array(JuMP.value.(α[k,:]))) for k in L)) + line[j].x*(T[j+1,:].*Array(JuMP.value.(α[j,:]))*node[j].tan_ϕ + sum(D_n[j+1,k]*(T[k+1,:].*Array(JuMP.value.(α[k,:]))*node[k].tan_ϕ) for k in L)) for j in L if R[i,j] == 1)'*Σ*(2*sum(line[j].r*(T[j+1,:].*Array(JuMP.value.(α[j,:])) + sum(D_n[j+1,k]*(T[k+1,:].*Array(JuMP.value.(α[k,:]))) for k in L)) + line[j].x*(T[j+1,:].*Array(JuMP.value.(α[j,:]))*node[j].tan_ϕ + sum(D_n[j+1,k]*(T[k+1,:].*Array(JuMP.value.(α[k,:]))*node[k].tan_ϕ) for k in L)) for j in L if R[i,j] == 1)))
            flow_p_std = sqrt((T[i+1,:].*Array(JuMP.value.(α[i,:])) + sum(D_n[i+1,j]*T[j+1,:].*Array(JuMP.value.(α[j,:])) for j in L))'*Σ*(T[i+1,:].*Array(JuMP.value.(α[i,:])) + sum(D_n[i+1,j]*T[j+1,:].*Array(JuMP.value.(α[j,:])) for j in L)))
            flow_q_std = sqrt((T[i+1,:].*Array(JuMP.value.(α[i,:])).*node[i].tan_ϕ + sum(D_n[i+1,j]*T[j+1,:].*Array(JuMP.value.(α[j,:])).*node[j].tan_ϕ for j in L))'*Σ*(T[i+1,:].*Array(JuMP.value.(α[i,:])).*node[i].tan_ϕ + sum(D_n[i+1,j]*T[j+1,:].*Array(JuMP.value.(α[j,:])).*node[j].tan_ϕ for j in L)))
            push!(output,[i,node[i].d_p,JuMP.value(g_p[i]),gen_p_std,JuMP.value(g_q[i]),gen_q_std,JuMP.value(f_p[i]),flow_p_std,JuMP.value(f_q[i]),flow_q_std,JuMP.value(u[i]),u_std,sqrt(JuMP.value(u[i]))])
        end
    end
    return output, sum(JuMP.value(g_p[i])*node[i].c for i in PV_bus), JuMP.value(CVaR), CPU_time
end
