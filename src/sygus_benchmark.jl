using CSV, DataFrames
using DecisionTree

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

using ProgressBars

using HerbCore, HerbGrammar, HerbConstraints, HerbSearch, HerbSpecification, HerbInterpret
using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
using HerbBenchmarks.PBE_BV_Track_2018

using Garden.Probe

# Run time parameters
max_time = 120
max_enums = 10^6
max_size = 10 
max_depth = 6 

# utils
input_rules(grammar::AbstractGrammar) = findall(rule -> occursin("_arg_", string(rule)), grammar.rules)

find_rules(grammar::AbstractGrammar, rule_string::AbstractString) = findall(rule -> occursin(rule_string, string(rule)), grammar.rules)

function find_rules_exact(grammar::AbstractGrammar, target_rhs::AbstractString)
    return findall(grammar.rules) do rule
        string(rule) == target_rhs
    end
end

function add_benchmark_constraints(grammar, ben_module; constrained_space=2)
    # add syntax constraints
    if constrained_space >= 1
        for i in input_rules(grammar)
            addconstraint!(grammar, Contains(i))
        end

        if ben_module == PBE_BV_Track_2018
            for rule_string in ["bvadd", "bvxor", "bvand", "bvor"]
                indices = find_rules(grammar, rule_string)
                if !isempty(indices)
                    RID_i = indices[1]

                    # break symmetry
                    ord_const = Ordered(RuleNode(RID_i, [VarNode(:a), VarNode(:b)]), [:a, :b])
                    addconstraint!(grammar, ord_const) 

                    # make everything right-associate
                    assoc_const = Forbidden(RuleNode(RID_i, [RuleNode(RID_i, [VarNode(:a), VarNode(:b)]), VarNode(:c)]))
                    addconstraint!(grammar, assoc_const) 
                end
            end

            for rule_string in ["bvxor", "bvand", "bvor"]
                indices = find_rules(grammar, rule_string)
                if !isempty(indices)
                    RID_i = indices[1]
                    self_const = Forbidden(RuleNode(RID_i, [VarNode(:a), VarNode(:a)]))
                    addconstraint!(grammar, self_const) 
                end
            end

            indices = find_rules(grammar, "bvnot")
            if !isempty(indices)
                RID_NOT = indices[1]
                no_double_not = Forbidden(RuleNode(RID_NOT, [RuleNode(RID_NOT, [VarNode(:a)])]))
                addconstraint!(grammar, no_double_not) 
            end

            for rule_string in ["im_cvc", "if0_cvc"]
                indices = find_rules(grammar, rule_string)
                if !isempty(indices)
                    constraint = Ordered(RuleNode(indices[1], [VarNode(:a), VarNode(:b), VarNode(:c)]), [:b, :c])
                    addconstraint!(grammar, constraint)
                end
            end
        end 
e
        if constrained_space >= 2
            # for i in 1:length(grammar.rules)
            #     addconstraint!(grammar, Unique(i))
            # end
            if ben_module == PBE_SLIA_Track_2019
                terminal_rules = collect(1:length(grammar.rules))[grammar.isterminal]
                in_rules = input_rules(grammar)
                base_rules = [find_rules_exact(grammar, ""); find_rules_exact(grammar, " ")]

                terminal_rules = [rule for rule in terminal_rules if rule ∉ in_rules && rule ∉ base_rules && grammar.types[rule] == :ntString]

                for rule in terminal_rules
                    addconstraint!(grammar, Contains(rule))
                end
            elseif ben_module == PBE_BV_Track_2018
                for i in filter(i -> !grammar.isterminal[i], 1:length(grammar.rules))
                    addconstraint!(grammar, ForbiddenSequence([i,i]))
                end
            else
                error("Invalid benchmark selected.")
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
    if ben_module == PBE_SLIA_Track_2019
        problem_grammar_pairs = problem_grammar_pairs[1:100]
    end

    results_df = DataFrame(
        Problem      = AbstractString[],
        Program      = Any[],
        Effectivity  = Int[],
        Time_in_s    = Float64[],
    )

    results_dir = "data/$ben_module/"
    if !isdir(results_dir)
        mkpath(results_dir)
    end
    results_file = "$results_dir$(name)_$(constrained_space)_constraints_results.csv"

    if isfile(results_file)
        println("$results_file exists already, not running search for problems.")
        return
    end

    println("Running problems...")

    for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
        problem = p_g_pair.problem
        problem_grammar = deepcopy(p_g_pair.grammar)

        if length(problem.spec) > 100
            continue
        end

        # add syntax constraints
        clearconstraints!(problem_grammar)
        add_benchmark_constraints(problem_grammar, ben_module; constrained_space=constrained_space)

        # Compile interpreter ONCE per constrained grammar/problem
        interp = HerbInterpret.make_interpreter(
            problem_grammar;
            target_module = ben_module,
            cache_module  = ben_module,
        )

        start_time = time_ns()

        program, num_derivations = probe(
            problem_grammar, :Start, problem;
            interpret = interp,
            max_iterations = max_enums,
            max_depth = max_depth,
            max_size = max_size,
            max_iteration_time = max_time,
            allow_errors=true
        )

        elapsed_time_s = (time_ns() - start_time) / 1e9

        expr = isnothing(program) ? Expr(:Start) : rulenode2expr(program, problem_grammar)

        push!(results_df, (problem.name, expr, num_derivations, elapsed_time_s))
        GC.gc()
    end

    CSV.write(results_file, results_df)
    println("Writing results to $results_file")
end


"""
constrained_space denotes which set of constraints to use for RQ2.
"""
function run_EUSolver(ben_module; constrained_space=2)
    # Settings
    name = "EUSolver"
    problem_grammar_pairs = get_all_problem_grammar_pairs(ben_module)
    if ben_module == PBE_SLIA_Track_2019
        problem_grammar_pairs = problem_grammar_pairs[1:100]
    end

    results_df = DataFrame(Problem = AbstractString[], Program = Any[], Effectivity = Int[], Time_in_s = Float64[])

    # EUSolver parameters
	n_predicates = 100
    sym_bool = ben_module == PBE_SLIA_Track_2019 ? :ntBool : :ntBool
	sym_start = :Start
    sym_constraint = :nothing

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
            add_benchmark_constraints(problem_grammar, ben_module; constrained_space=constrained_space)

            iterator = BFSIterator(problem_grammar, :Start; max_depth=max_depth, max_size=max_size)
            
            start_time = time_ns()
k_2019
                terminal_rules = collect(1:length(grammar.rules))[grammar.isterminal]
                in_rules = input_rules(gra
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

# for i in 0:2
#     println("Running constraint set $i.")
#     # run_probe(PBE_SLIA_Track_2019; constrained_space=i)
#     # run_EUSolver(PBE_SLIA_Track_2019; constrained_space=i)
# end

for i in 0:2
    run_EUSolver(PBE_BV_Track_2018; constrained_space=i)
    run_probe(PBE_BV_Track_2018; constrained_space=i)
end