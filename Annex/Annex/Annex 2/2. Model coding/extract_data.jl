using XLSX

function get_sheet()
    xf = XLSX.readxlsx("immune_metabolism_time_course6.xlsx")
    return xf["Hoja1"]
end

function get_mat()
    sh = get_sheet()
    mat = sh[:]   
    mat = mat[2:end, :] 
    mat[:,1] = Symbol.(mat[:,1])
    return mat
end

function get_names()
    mat = get_mat()
    names = mat[:,1]
    names = Symbol.(names)
end

function ith_name(i, sh)
    mat = sh[:]
    name = Symbol(mat[i,1])
end

function get_od(od, name)
    return getproperty(od, name; namespace=false)
end

"""
get initial conditions from the matrix built from the excel file, 
mat is the matrix and i is the index I'm querying

"""
function get_ic(mat, i)
    return Float64(mat[i,2])
end

"""
get the index for a particular symbol or "name" from a vector of symbols or "names". 
    So, name, is the particular symbool I'm querying
"""
    function get_name_index(names, name)
    findall(x -> x == name, names)
end


"""
It makes dictionary that goes from names (symbols) to the default initial conditions (value of mat at time zero)
od is the Leish_model that contains the ODE equations
"""
function make_defaults(od)
    names = get_names()
    mat = get_mat()
    # ics = [get_od(name) => get_ic(i) for (i, name) in enumerate(names)]

    defaults = Dict()
    for (i, name) in enumerate(names)
        if hasproperty(od, name)
            defaults[get_od(od, name)] = get_ic(mat, i)
        else
            println(name, " is spelt wrong")
        end
    end
    return defaults
end

function dict_of_mat(mat)
    d = Dict(el[1] => el[2:end] for el in eachrow(mat))
end