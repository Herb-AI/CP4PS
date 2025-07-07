using CSV, DataFrames

using HerbCore, HerbConstraints, HerbSearch, HerbSpecification
using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
using HerbBenchmarks.PBE_BV_Track_2018

using Garden: Probe

# Run time parameters
max_time = 100
max_enums = 1000000
max_size = 10 
max_depth = 7 

# utils
input_rules(grammar::AbstractGrammar) = findall(rule -> occursin("_arg_", string(rule)), grammar.rules)

function run_problem(problem::Problem, problem_grammar::AbstractGrammar, iterator_type::Type; constrained_space=true)

     # add syntax constraints
    if problem_type != "BUSTLE_SLIA"
        for i in input_rules(problem_grammar)
            addconstraint!(problem_grammar, Contains(i))
        end
    end

    if problem_type != "String"
        for i in filter(i -> !problem_grammar.isterminal[i], 1:length(problem_grammar.rules))
            addconstraint!(problem_grammar, ForbiddenSequence([i,i]))
        end
    end

    st = SymbolTable(problem_grammar)

    iterator = iterator_type(problem_grammar, :Start; max_depth=max_depth, max_size=max_size)
    
    start_time = time()
    counter = 0
    for (i, program) ∈ enumerate(iterator)
        if depth(program) < get_mindepth(iterator)
            continue
        end

        counter += 1

        if time() - start_time > max_time || counter > max_enums
            break;
        end

        st = nothing
        if ben_module != String_transformations_2020
            st = grammar2symboltable(get_current_grammar(iterator))
        end

        falsified = false
        for ex in problem.spec
            try
                expr = rulenode2expr(program, get_current_grammar(iterator))
                output = execute_on_input(st, expr, ex.in)

                if output != ex.out
                    falsified = true
                    break
                end
            catch exception
                falsified = true
                break
            end
        end

        if !falsified
            println("BUMMM! $i\n")
            return (rulenode2expr(program, get_current_grammar(iterator)), i)
        end
    end

    return (Expr(:Start), counter)
end

function add_benchmark_constraints(grammar; constrained_space=2)
    # add syntax constraints
    if constraint_space >= 1
        for i in input_rules(problem_grammar)
            addconstraint!(problem_grammar, Contains(i))
        end

        if constraint_space >= 2
            for i in filter(i -> !problem_grammar.isterminal[i], 1:length(problem_grammar.rules))
                # addconstraint!(problem_grammar, ForbiddenSequence([i,i]))
                addconstraint!(problem_grammar, Unique(i))
            end
        end
    end
end

"""

constraint_space denotes which set of constraints to use for RQ2.
"""
function run_probe(ben_module; constrained_space=2)
    name = "probe"
    problem_grammar_pairs = get_all_problem_grammar_pairs(ben_module)#[1:3]
    results_df = DataFrame(Problem = AbstractString[], Program = Expr[], Effectivity = Int[], Time_in_s = Float64[])

    results_dir = "../data/$ben_module/"
    if !isdir(results_dir) mkpath(results_dir) end
    results_file = "$results_dir$(name)_$(constrainted_space ? "con" : "notcon")_results.csv"

    if !isfile(results_file)
        println("Running problems...")
        for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
            problem, problem_grammar = p_g_pair.problem, p_g_pair.grammar

            # add syntax constraints
            if constrained_space >
                for i in input_rules(problem_grammar)
                    addconstraint!(problem_grammar, Contains(i))
                end

                for i in filter(i -> !problem_grammar.isterminal[i], 1:length(problem_grammar.rules))
                    addconstraint!(problem_grammar, ForbiddenSequence([i,i]))
                end
            end
            
            start_time = time_ns()
            program, num_derivations = probe(problem_grammar, :Start, problem; max_depth=max_depth, max_size=max_size, max_iteration_time=max_time)  # Run the algorithm
            elapsed_time_ns = time_ns() - start_time
            elapsed_time_s = elapsed_time_ns / 1e9  # Convert nanoseconds to seconds

            push!(results_df, (problem.name, program, num_derivations, elapsed_time_s))
            GC.gc()
        end

        CSV.write(results_file, results_df)
        println("Writing results to $results_file")
    else
        println("$results_file exists already, not running search for problems.")
    end
end

"""

constraint_space denotes which set of constraints to use for RQ2.
"""
function run_EUSolver(ben_module; constraint_space=2)
    # Settings
    name = "EUSolver"
    problem_grammar_pairs = get_all_problem_grammar_pairs(ben_module)#[1:3]
    results_df = DataFrame(Problem = AbstractString[], Program = Expr[], Effectivity = Int[], Time_in_s = Float64[])

    # EUSolver parameters
	n_predicates = 5
	sym_bool = :Bool
	sym_start = :Start
	sym_constraint = :Input
	max_EUSolver_enumerations = 10


    results_dir = "../data/$ben_module/"
    if !isdir(results_dir) mkpath(results_dir) end
    results_file = "$results_dir$(name)_$(constrainted_space ? "con" : "notcon")_results.csv"

    if !isfile(results_file)
        println("Running problems...")
        for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
            problem, problem_grammar = p_g_pair.problem, p_g_pair.grammar

            idx_ifelse = findfirst(r -> r == :($sym_bool ? $sym_start : $sym_start), grammar.rules) 

            if isnothing(idx_ifelse)
                add_rule!(grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
            end

            # add syntax constraints
            if constraint_space >= 1
                for i in input_rules(problem_grammar)
                    addconstraint!(problem_grammar, Contains(i))
                end

                if constraint_space >= 2
                    for i in filter(i -> !problem_grammar.isterminal[i], 1:length(problem_grammar.rules))
                        # addconstraint!(problem_grammar, ForbiddenSequence([i,i]))
                        addconstraint!(problem_grammar, Unique(i))
                    end
                end
            end

            iterator = BFSIterator(problem_grammar, :Start; max_depth=max_depth, max_size=max_size)
            
            start_time = time_ns()
            program, num_derivations = probe(problem_grammar, :Start, problem; max_depth=max_depth, max_size=max_size, max_iteration_time=max_time)  # Run the algorithm
            final_program, num_derivations = divide_and_conquer(
                problem,
                iterator,
                sym_bool,
                sym_start,
                sym_constraint,
                n_predicates,
                max_enumerations,
            )
            
            elapsed_time_ns = time_ns() - start_time
            elapsed_time_s = elapsed_time_ns / 1e9  # Convert nanoseconds to seconds

            push!(results_df, (problem.name, program, num_derivations, elapsed_time_s))
            GC.gc()
        end

        CSV.write(results_file, results_df)
        println("Writing results to $results_file")
    else
        println("$results_file exists already, not running search for problems.")
    end
end

run_probe(PBE_SLIA_Track_2019; constraint_space=2)
# run_probe(PBE_SLIA_Track_2019; constraint_space=2)
# run_EUSolver(PBE_BV_Track_2018; constraint_space=2)
# run_EUSolver(PBE_BV_Track_2018; constraint_space=2)