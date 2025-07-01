using Revise, HerbCore, HerbConstraints, HerbSearch, HerbGrammar, HerbInterpret, HerbSpecification, MLStyle

function get_search_nodes(solver::GenericSolver)
    dict = solver.statistics.dict
    if solver.use_uniformsolver
        get!(dict, "[GenericSolver] SearchNodes (TopDownIterator)", 0) +
        get!(dict, "[UniformSolver] #CompleteTrees", 0) +
        get!(dict, "[UniformSolver] #InternalSearchNodes", 0) +
        get!(dict, "[UniformSolver] #InfeasibleTrees", 0) +
        -get!(dict, "[GenericSolver] #FixedShapedTrees", 0)
    else
        get!(dict, "[GenericSolver] SearchNodes (TopDownIterator)", 0) +
        get!(dict, "[GenericSolver] SearchNodes (FixedShapedIterator)", 0) +
        -get!(dict, "[GenericSolver] #FixedShapedTrees", 0) + 1
    end
end

function get_forbidden_propagations(solver::GenericSolver)
    dict = solver.statistics.dict
    get!(dict, "[GenericSolver] LocalForbidden propagation", 0) +
    get!(dict, "[UniformSolver] LocalForbidden propagation", 0)
end

function get_number_of_fixed_shaped_trees(solver::GenericSolver)
    dict = solver.statistics.dict
    get!(dict, "[GenericSolver] #FixedShapedTrees", 0)
end


function retrospective_length(iter::ProgramIterator, constraints)
    @assert isempty(get_grammar(iter.solver).constraints) "The solver should be initialized without any constraints"
    @assert !isempty(constraints) "The list of constraints to check retrospectively should be nonempty"
    l = 0
    for t ∈ iter
        valid = true
        for c ∈ constraints
            if !check_tree(c, t)
                valid = false
                break
            end
        end
        if valid
            l += 1
        end
    end
    return l
end
