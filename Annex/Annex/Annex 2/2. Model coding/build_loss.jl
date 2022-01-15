include("build_model5.jl")
"30 mins 4 hours 24, all + 2 hours"

ts = [2.5 , 6.,  26.]

ssolvet(prob) = solve(prob, AutoTsit5(Rosenbrock23()), callback = cb, tstops = [2.], saveat=ts)


function mat_index(ts)
    last = size(mat,2)
    d = Dict(ts .=> (last-length(ts)+1:last)) 
end


function name_to_ODEidx(od)
    # dict inputting symbolic name and outputting index position in prob.u0
    names = get_names()
    num_states = length(ModelingToolkit.get_states(od))
    d = Dict{Symbol, Int64}()
    query(name,i) = isequal(ModelingToolkit.get_states(od)[i], getproperty(od, name; namespace=false))
    for name in names
        if hasproperty(od, name)
            q(i) = query(name, i)
            entry = filter(q, 1:num_states)
            if !(isempty(entry))
                d[name] = entry[1]
            end
        end
    end
    
    return d
end

function matrixindx_to_name()
    # dict mapping position to name on matrix
    names = get_names()
    d = Dict(i => name for (i, name) in enumerate(names)) 
end

function reverse_dict(d)
    return Dict(d[k] => k for k in keys(d))
end

function indxs_sol_to_mat(od)
    name2sol = name_to_ODEidx(od)
    sol2name = reverse_dict(name2sol)
    mat2name = matrixindx_to_name()
    name2mat = reverse_dict(mat2name)
    sol2mat = Dict(k => name2mat[sol2name[k]] for k in keys(sol2name))
end

function make_loss(prob, od, mat, ts)
    mi = mat_index(ts)
    sol2mat = indxs_sol_to_mat(od)

    function sol_loss(sol)
        num_states = length(sol(0.))
        l = 0.
        for tp in ts
            # ind = mat_index(tp)
            for i = 1:num_states
                if haskey(sol2mat, i)
                    mat_row = sol2mat[i]
                    mat_col = mi[tp]
                    if typeof(mat[mat_row, mat_col]) <: Number
                        l += (sol(tp)[i] - mat[mat_row, mat_col])^2
                    end 
                end

            end
        end   
        return l
    end

    function p_loss(p)
        newprob = remake(prob; p = p)
        sol = ssolvet(newprob) #, AutoTsit5(Rosenbrock23()) , saveat = ts)
        l1 =  sol_loss(sol)
        return l1
    end

    return sol_loss, p_loss
end

function make_i_loss(prob,od,mat,ts)
    mi = mat_index(ts)
    sol2mat = indxs_sol_to_mat(od)
    function i_loss(sol, i)
        if haskey(sol2mat,i)
            l = 0.
            for tp in ts
                mat_row = sol2mat[i]
                mat_col = mi[tp]
                if typeof(mat[mat_row, mat_col]) <: Number
                    l += (sol(tp)[i] - mat[mat_row, mat_col])^2
                end
            end
            return l
        else
            println("state $i is not constrained by data")
            return 0.
        end
    end

    function pi_loss(p,i)
        newprob = remake(prob; p = p)
        sol = ssolvet(newprob) # AutoTsit5(Rosenbrock23()), saveat = ts)
        return i_loss(sol,i)
    end
    return pi_loss
end


function get_worst_states(prob,od,mat,ts)
    pi_loss = make_i_loss(prob,od,mat,ts)

    vec_of_losses = [pi_loss(prob.p, i) for i in 1:length(od.states)]
    vec_of_losses[vec_of_losses .=== nothing] .= 0.
    worst_vals = sortperm(vec_of_losses, rev=true)
    worst_states = od.states[worst_vals] .=> vec_of_losses[worst_vals]
    return worst_states
end

function make_double_loss(prob, od, mat, ts)
    mi = mat_index(ts)
    sol2mat = indxs_sol_to_mat(od)

    function sol_loss(sol)
        num_states = length(sol(0.))
        l = 0.
        for tp in ts
            # ind = mat_index(tp)
            for i = 1:num_states
                if haskey(sol2mat, i)
                    mat_row = sol2mat[i]
                    mat_col = mi[tp]
                    if typeof(mat[mat_row, mat_col]) <: Number
                        l += (sol(tp)[i] - mat[mat_row, mat_col])^2
                    end 
                end

            end
        end   
        return l
    end

    function ss_loss(_probnew)
        u0 = copy(_probnew.u0)
        u0[1] = 0. # delete promastigote
        __probnew = remake(_probnew, u0=u0)
        _sol = ssolvet(__probnew) # , AutoTsit5(Rosenbrock23()), saveat=ts)
        return sum(abs2, sol(ts[end-1]) - u0)
    end

    function p_loss(p)
        newprob = remake(prob; p = p)
        sol = ssolvet(newprob) # , AutoTsit5(Rosenbrock23()) , saveat = ts)
        l1 =  sol_loss(sol)
        l2 = ss_loss(newprob)
        return l1 + l2
    end

    return sol_loss, p_loss
end


function num_datapoints(od, mat)
    nnames = get_names()
    dic = dict_of_mat(mat)
    num = 0
    for name in nnames
        if hasproperty(od, name)
            num += sum(
                typeof.(dic[name]) .<: Number  
            )
        end
    end
    return num
end