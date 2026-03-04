# asp_experiments.jl
using HerbCore
using HerbSearch: BFSASPIterator
using Clingo_jll

include("_thesis_helpers.jl")
include("_helper_functions.jl")

robots = 1
arithmetic = 2
symbolic = 3
lists = 4
lists_grounded = 5

const GRAMMARS_4 = (robots, arithmetic, symbolic, lists)

function asp_bfs(grammartype, number_of_constraints::Int=typemax(Int); with_constraints::Bool=true, MAX_TIME=600)
    @assert grammartype in GRAMMARS_4

    name = "asp_bfs_grammar$(grammartype)"
    if !with_constraints
        name *= "_noconstr"
    end
    if number_of_constraints < typemax(Int)
        name *= "_constraints$(number_of_constraints)"
    end

    dirpath = dirname(get_filename(name))
    if !isdir(dirpath)
        mkdir(dirpath)
    end

    open(get_filename(name), "w") do file
        println(file, "max_size, programs, time")
        for max_size ∈ 1:100
            println("[$name] max_size = $max_size")

            grammar = get_thesis_grammar(grammartype, number_of_constraints)
            if !with_constraints
                clearconstraints!(grammar)
            end

            start = get_starting_symbol(grammartype)
            iter  = BFSASPIterator(grammar, start; max_depth=max_size)

            programs = 0
            time = @elapsed begin
                for _ in iter
                    programs += 1
                end
            end

            println(file, "$max_size, $programs, $time")

            if time > MAX_TIME
                @warn "Last experiment took $time seconds"
                break
            end
        end
    end
end


function asp_bfs_all(number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    for gtype in GRAMMARS_4
        asp_bfs(gtype, number_of_constraints; with_constraints=false, MAX_TIME=MAX_TIME)
        asp_bfs(gtype, number_of_constraints; with_constraints=true,  MAX_TIME=MAX_TIME)
    end
end

asp_bfs_all(MAX_TIME=600)