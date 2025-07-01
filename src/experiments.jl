using Revise, MLStyle
using HerbCore, HerbConstraints, HerbSearch, HerbGrammar, HerbInterpret, HerbSpecification

include("_thesis_helpers.jl")
include("_helper_functions.jl")

robots = 1
arithmetic = 2
symbolic = 3
lists = 4
lists_grounded = 5

#enumerate all with the GenericSolver
function main(grammartype, number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    @assert grammartype == robots || grammartype == arithmetic || grammartype == symbolic || grammartype == lists || grammartype == lists_grounded
    name = "grammar$(grammartype)"
    if number_of_constraints < typemax(Int)
        name = name * "_constraints$(number_of_constraints)"
    end
    dirpath = dirname(get_filename(name))
    if !isdir(dirpath)
        mkdir(dirpath)
    end
    open(get_filename(name), "w") do file
        for max_size ∈ 1:100
            println("max_size = $max_size")
            grammar = get_thesis_grammar(grammartype, number_of_constraints)

            solver = GenericSolver(grammar, get_starting_symbol(grammartype), with_statistics=false, use_uniformsolver=true)
            iter = BFSIterator(solver=solver, max_size=max_size)
            
            time = @elapsed programs = length(iter)

            println(file, "$max_size, $programs, $time")
            if time > MAX_TIME
                @warn "Last experiment took $time seconds"
                break
            end
        end
    end
end

#enumerate all with the GenericSolver
function bottom_up_main(grammartype, number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    @assert grammartype == robots || grammartype == arithmetic || grammartype == symbolic || grammartype == lists || grammartype == lists_grounded
    name = "bus_grammar$(grammartype)"
    if number_of_constraints < typemax(Int)
        name = name * "_constraints$(number_of_constraints)"
    end
    dirpath = dirname(get_filename(name))
    if !isdir(dirpath)
        mkdir(dirpath)
    end
    problem=nothing
    println("Writing to $(get_filename(name))")
    open(get_filename(name), "w") do file
        for max_depth ∈ 1:7
            println("max_depth = $max_depth")
            grammar = get_thesis_grammar(grammartype, number_of_constraints)

            iter = BUUniformIterator(grammar, get_starting_symbol(grammartype), max_depth=max_depth)
            max_bank_size = 0

            start_time = time()
            state = Base.iterate(iter)
            while state !== nothing
                if time() - start_time > MAX_TIME
                    @warn "Last experiment took $(time() - start_time) seconds"
                    break
                end

                program, new_state = state
                bank = new_state.bank.tree_shapes_by_symbol
                bank_size = sum(length(v) for v in values(bank))
                # println("bank_size: $bank_size")
                if bank_size > max_bank_size
                    max_bank_size = bank_size
                end

                # Move to the next state
                state = Base.iterate(iter, new_state)
            end

            println("max_bank_size: $max_bank_size")

            println(file, "$max_depth, $max_bank_size, $(time()-start_time)")

        end
    end
end


#enumerate all with the GenericSolver
function bottom_up_retrospective(grammartype, number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    @assert grammartype == robots || grammartype == arithmetic || grammartype == symbolic || grammartype == lists || grammartype == lists_grounded
    name = "bus_grammar$(grammartype)_retrospective"
    if number_of_constraints < typemax(Int)
        name = name * "_constraints$(number_of_constraints)"
    end
    dirpath = dirname(get_filename(name))
    if !isdir(dirpath)
        mkdir(dirpath)
    end
    problem=nothing
    println("Writing to $(get_filename(name))")
    open(get_filename(name), "w") do file
        for max_depth ∈ 1:6
            println("max_depth = $max_depth")
            grammar = get_thesis_grammar(grammartype, number_of_constraints)
            clearconstraints!(grammar)

            iter = BUDepthIterator(grammar, get_starting_symbol(grammartype), max_depth=max_depth)
            max_bank_size = 0

            start_time = time()
            state = Base.iterate(iter)
            while state !== nothing
                if time() - start_time > MAX_TIME
                    @warn "Last experiment took $(time() - start_time) seconds"
                    break
                end

                program, new_state = state
                bank = new_state.bank.rulenodes_by_symbol
                bank_size = sum(length(v) for v in values(bank))
                # println("bank_size: $bank_size")
                if bank_size > max_bank_size
                    max_bank_size = bank_size
                end

                # Move to the next state
                state = Base.iterate(iter, new_state)
            end

            println("max_bank_size: $max_bank_size")

            println(file, "$max_depth, $max_bank_size, $(time()-start_time)")
        end
    end
end


#enumerate all, and retrospective apply constraints
function retrospective(grammartype, number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    @assert number_of_constraints > 0
    @assert grammartype == robots || grammartype == arithmetic || grammartype == symbolic || grammartype == lists
    name = "grammar$(grammartype)_retrospective"
    if number_of_constraints < typemax(Int)
        name = name * "_constraints$(number_of_constraints)"
    end
    open(get_filename(name), "w") do file
        for max_size ∈ 1:100
            println("max_size = $max_size")
            grammar = get_thesis_grammar(grammartype, number_of_constraints)
            constraints = deepcopy(grammar.constraints)
            clearconstraints!(grammar)

            solver = GenericSolver(grammar, get_starting_symbol(grammartype), with_statistics=false, use_uniformsolver=true)
            iter = BFSIterator(solver=solver, max_size=max_size)

            time = @elapsed programs = retrospective_length(iter, constraints)

            println(file, "$max_size, $programs, $time")
            if time > MAX_TIME
                @warn "Last experiment took $time seconds"
                break
            end
        end
    end
end

#number of fixed shaped trees
function shapes(grammartype, number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    @assert grammartype == robots || grammartype == arithmetic || grammartype == symbolic || grammartype == lists
    name = "grammar$(grammartype)_number_of_uniform_trees_UNIFORM_ONLY"
    if number_of_constraints < typemax(Int)
        name = name * "_constraints$(number_of_constraints)"
    end
    open(get_filename(name), "w") do file
        for max_size ∈ 1:100
            println("max_size = $max_size")
            grammar = get_thesis_grammar(grammartype, number_of_constraints)

            solver = GenericSolver(grammar, get_starting_symbol(grammartype), with_statistics=true, use_uniformsolver=true)
            iter = BFSIterator(solver=solver, max_size=max_size)
            
            time = @elapsed programs = length(iter)
            println(solver.statistics)
            number_of_uniform_trees = get_number_of_fixed_shaped_trees(solver)

            println(file, "$max_size, $number_of_uniform_trees")
            if time > MAX_TIME
                @warn "Last experiment took $time seconds"
                break
            end
        end
    end
end

#first order constraints
function firstorderexperiment(grammartype, number_of_constraints::Int=typemax(Int); MAX_TIME=600)
    @assert grammartype == lists || grammartype == lists_grounded
    name = grammartype == lists_grounded  ? "grammar$(grammartype)_grounded" : "grammar$(grammartype)_firstorder"
    open(get_filename(name), "w") do file
        max_size = 8
        println("max_size = $max_size")
        grammar = get_thesis_grammar(grammartype, number_of_constraints)

        solver = GenericSolver(grammar, get_starting_symbol(grammartype), with_statistics=true, use_uniformsolver=true)
        iter = BFSIterator(solver=solver, max_size=max_size)
        
        @elapsed programs = length(iter)

        println(solver.statistics)

        println("SEARCHNODES: $(get_search_nodes(solver))")
    end
end

#manual experiments
for _ ∈ 1:1
    # main(lists, 0, MAX_TIME=1400)
    # bottom_up_main(lists, MAX_TIME=600)
    bottom_up_retrospective(lists, MAX_TIME=600)
end
