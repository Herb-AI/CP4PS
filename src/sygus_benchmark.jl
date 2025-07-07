using CSV, DataFrames
using DecisionTree

using ProgressBars

using HerbCore, HerbGrammar, HerbConstraints, HerbSearch, HerbSpecification
using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
using HerbBenchmarks.PBE_BV_Track_2018

using Garden.Probe

# Run time parameters
max_time = 120
max_enums = 100000#0
max_size = 10 
max_depth = 7 

# utils
input_rules(grammar::AbstractGrammar) = findall(rule -> occursin("_arg_", string(rule)), grammar.rules)

function add_benchmark_constraints(problem_grammar; constrained_space=2)
    # add syntax constraints
    if constrained_space >= 1
        for i in input_rules(problem_grammar)
            addconstraint!(problem_grammar, Contains(i))
        end

        if constrained_space >= 2
            # for i in 1:length(problem_grammar.rules)
            #     addconstraint!(problem_grammar, Unique(i))
            # end
            for i in filter(i -> !problem_grammar.isterminal[i], 1:length(problem_grammar.rules))
                addconstraint!(problem_grammar, ForbiddenSequence([i,i]))
            end
        end
    end
end

"""

constrained_space denotes which set of constraints to use for RQ2.
"""
function run_probe(ben_module; constrained_space=2)
    name = "probe"
    problem_grammar_pairs = get_all_problem_grammar_pairs(ben_module)
    results_df = DataFrame(Problem = AbstractString[], Program = Any[], Effectivity = Int[], Time_in_s = Float64[])

    results_dir = "data/$ben_module/"
    if !isdir(results_dir) mkpath(results_dir) end
    results_file = "$results_dir$(name)_$(constrained_space)_constraints_results.csv"

    if !isfile(results_file)
        println("Running problems...")
        for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
            problem, problem_grammar = p_g_pair.problem, deepcopy(p_g_pair.grammar)

            if length(problem.spec) > 100
                continue
            end

            # add syntax constraints
            clearconstraints!(problem_grammar)
            add_benchmark_constraints(problem_grammar; constrained_space=constrained_space)
            
            start_time = time_ns()
            program, num_derivations = probe(problem_grammar, :Start, problem; max_iterations=max_enums, max_depth=max_depth, max_size=max_size, max_iteration_time=max_time)  # Run the algorithm
            elapsed_time_ns = time_ns() - start_time
            elapsed_time_s = elapsed_time_ns / 1e9  # Convert nanoseconds to seconds

            if isnothing(program)
                expr = Expr(:Start)
            else
                expr = rulenode2expr(program, problem_grammar)
            end

            push!(results_df, (problem.name, expr, num_derivations, elapsed_time_s))
            GC.gc()
        end

        CSV.write(results_file, results_df)
        println("Writing results to $results_file")
    else
        println("$results_file exists already, not running search for problems.")
    end
end

"""

constrained_space denotes which set of constraints to use for RQ2.
"""
function run_EUSolver(ben_module; constrained_space=2)
    # Settings
    name = "EUSolver"
    problem_grammar_pairs = get_all_problem_grammar_pairs(ben_module)#[1:3]
    results_df = DataFrame(Problem = AbstractString[], Program = Any[], Effectivity = Int[], Time_in_s = Float64[])

    # EUSolver parameters
	n_predicates = 5
    sym_bool = :ntBool
	sym_start = :Start
	sym_constraint = :Input

    results_dir = "data/$ben_module/"
    if !isdir(results_dir) mkpath(results_dir) end
    results_file = "$results_dir$(name)_$(constrained_space)_constraints_results.csv"

    if !isfile(results_file)
        println("Running problems...")
        for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
            problem, problem_grammar = p_g_pair.problem, deepcopy(p_g_pair.grammar)

            idx_ifelse = findfirst(r -> r == :($sym_bool ? $sym_start : $sym_start), problem_grammar.rules) 

            if isnothing(idx_ifelse)
                if ben_module == PBE_BV_Track_2018
                    add_rule!(problem_grammar, :($sym_bool = Start == UInt(0)))
                end

                add_rule!(problem_grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
            end

            # add syntax constraints
            clearconstraints!(problem_grammar)
            add_benchmark_constraints(problem_grammar; constrained_space=constrained_space)

            iterator = BFSIterator(problem_grammar, :Start; max_depth=max_depth, max_size=max_size)
            
            start_time = time_ns()

            program, num_derivations = divide_and_conquer(
                problem,
                iterator,
                sym_bool,
                sym_start,
                sym_constraint,
                n_predicates,
                max_time,
                max_enums
            )

            if isnothing(program)
                expr = Expr(:Start)
            else
                expr = rulenode2expr(program, problem_grammar)
            end

            st = grammar2symboltable(problem_grammar, Main)
            if HerbSearch.evaluate(problem, expr, st, allow_evaluation_errors=true) != 1
                expr = Expr(:Start)
            end

            elapsed_time_ns = time_ns() - start_time
            elapsed_time_s = elapsed_time_ns / 1e9  # Convert nanoseconds to seconds

            push!(results_df, (problem.name, expr, num_derivations, elapsed_time_s))
            GC.gc()
        end

        CSV.write(results_file, results_df)
        println("Writing results to $results_file")
    else
        println("$results_file exists already, not running search for problems.")
    end
end

for i in 0:2
    println("Running constraint set $i.")
    run_probe(PBE_SLIA_Track_2019; constrained_space=i)
    run_EUSolver(PBE_SLIA_Track_2019; constrained_space=i)
end

for i in 0:2
    run_probe(PBE_BV_Track_2018; constrained_space=i)
    run_EUSolver(PBE_BV_Track_2018; constrained_space=i)
end