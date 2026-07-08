using CSV, DataFrames
using DecisionTree

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

using ProgressBars

using HerbCore, HerbGrammar, HerbConstraints, HerbSearch, HerbSpecification, HerbInterpret
using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
using HerbBenchmarks.PBE_BV_Track_2018

# using Garden.Probe

# Run time parameters
max_time = 300
max_enums = 10^6
max_size = 10 
max_depth = 6 

# IO utils
const UNSOLVED_PROGRAM = "\$(Expr(:Start))"

function init_results_df()
    DataFrame(
        Problem     = String[],
        Program     = String[],
        Effectivity = Int[],
        Time_in_s   = Float64[],
    )
end

function load_results(results_file::AbstractString)
    if !isfile(results_file)
        return init_results_df()
    end

    df = CSV.read(results_file, DataFrame)

    required = [:Problem, :Program, :Effectivity, :Time_in_s]
    existing = propertynames(df)

    for col in required
        col in existing || error("Existing results file $results_file is missing column $col")
    end

    df = select(df, required)

    # If duplicates ever happened, keep the last occurrence
    reverse!(df)
    unique!(df, :Problem)
    reverse!(df)

    return df
end

function save_results_atomic(results_file::AbstractString, df::DataFrame)
    mkpath(dirname(results_file))
    tmp_file = results_file * ".tmp"
    CSV.write(tmp_file, df)
    mv(tmp_file, results_file; force=true)
end

program_to_string(expr) = isnothing(expr) ? UNSOLVED_PROGRAM : sprint(show, expr)

function checkpoint_result!(
    results_df::DataFrame,
    results_file::AbstractString,
    problem_name,
    expr,
    effectivity,
    elapsed_time_s,
)
    push!(results_df, (
        String(problem_name),
        program_to_string(expr),
        Int(effectivity),
        Float64(elapsed_time_s),
    ))

    save_results_atomic(results_file, results_df)
end

# Herb utils
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

            # a op a is always redundant: bvand(a,a)=a, bvor(a,a)=a, bvxor(a,a)=0,
            # bvadd(a,a)=2a=smol(a) -- each already has a strictly shorter
            # equivalent elsewhere in the grammar.
            for rule_string in ["bvxor", "bvand", "bvor", "bvadd"]
                indices = find_rules(grammar, rule_string)
                if !isempty(indices)
                    RID_i = indices[1]
                    self_const = Forbidden(RuleNode(RID_i, [VarNode(:a), VarNode(:a)]))
                    addconstraint!(grammar, self_const)
                end
            end

            idx_not = find_rules(grammar, "bvnot")
            if !isempty(idx_not)
                RID_NOT = idx_not[1]
                no_double_not = Forbidden(RuleNode(RID_NOT, [RuleNode(RID_NOT, [VarNode(:a)])]))
                addconstraint!(grammar, no_double_not)

                # x op NOT(x) folds to a constant (0 for AND, all-ones for OR/XOR),
                # which is already directly expressible as a literal.
                for rule_string in ["bvand", "bvor", "bvxor"]
                    indices = find_rules(grammar, rule_string)
                    if !isempty(indices)
                        RID_i = indices[1]
                        addconstraint!(grammar, Forbidden(RuleNode(RID_i, [VarNode(:a), RuleNode(RID_NOT, [VarNode(:a)])])))
                        addconstraint!(grammar, Forbidden(RuleNode(RID_i, [RuleNode(RID_NOT, [VarNode(:a)]), VarNode(:a)])))
                    end
                end
            end

            # Boolean absorption: a AND (a OR b) = a, and a OR (a AND b) = a.
            idx_and = find_rules(grammar, "bvand")
            idx_or = find_rules(grammar, "bvor")
            if !isempty(idx_and) && !isempty(idx_or)
                RID_AND, RID_OR = idx_and[1], idx_or[1]
                addconstraint!(grammar, Forbidden(RuleNode(RID_AND, [VarNode(:a), RuleNode(RID_OR, [VarNode(:a), VarNode(:b)])])))
                addconstraint!(grammar, Forbidden(RuleNode(RID_AND, [RuleNode(RID_OR, [VarNode(:a), VarNode(:b)]), VarNode(:a)])))
                addconstraint!(grammar, Forbidden(RuleNode(RID_OR, [VarNode(:a), RuleNode(RID_AND, [VarNode(:a), VarNode(:b)])])))
                addconstraint!(grammar, Forbidden(RuleNode(RID_OR, [RuleNode(RID_AND, [VarNode(:a), VarNode(:b)]), VarNode(:a)])))
            end

            # Chained logical right-shifts commute: (x >> i) >> j == (x >> j) >> i.
            # Keep a single canonical nesting order per pair of distinct shift
            # amounts to avoid exploring both equivalent nestings.
            shift_rule_strings = ["ehad", "arba", "shesh"]
            shift_indices = [find_rules(grammar, s) for s in shift_rule_strings]
            for outer in 1:length(shift_rule_strings)
                for inner in (outer + 1):length(shift_rule_strings)
                    if !isempty(shift_indices[outer]) && !isempty(shift_indices[inner])
                        RID_outer = shift_indices[outer][1]
                        RID_inner = shift_indices[inner][1]
                        addconstraint!(grammar, Forbidden(RuleNode(RID_inner, [RuleNode(RID_outer, [VarNode(:a)])])))
                    end
                end
            end

            # im_cvc/if0_cvc: an Ordered constraint on the two branches is
            # unsound here (if(x,y,z) is not symmetric in y,z without negating
            # x). Instead:
            #  - a repeated branch makes the condition irrelevant (redundant), and
            #  - a literal 0/1 condition folds the whole conditional away.
            literal_indices = vcat(
                find_rules_exact(grammar, "0"),
                find_rules_exact(grammar, "1"),
            )
            for rule_string in ["im_cvc", "if0_cvc"]
                indices = find_rules(grammar, rule_string)
                if !isempty(indices)
                    RID_i = indices[1]
                    addconstraint!(grammar, Forbidden(RuleNode(RID_i, [VarNode(:x), VarNode(:y), VarNode(:y)])))
                    for lit in literal_indices
                        addconstraint!(grammar, Forbidden(RuleNode(RID_i, [RuleNode(lit), VarNode(:y), VarNode(:z)])))
                    end
                end
            end
        end

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
                # "Useful" diversity constraint (per the paper: "we forbid
                # using the same operator twice in a row"): forbid a rule from
                # appearing again *anywhere* below itself in the AST, not just
                # as an immediate child. ForbiddenSequence([i, i]) matches
                # along the whole ancestor-descendant path, with arbitrary
                # gaps in between (e.g. it forbids bvand(x, bvor(bvand(y,z),
                # w)), not just bvand(bvand(y,z), w)). This is strictly
                # stronger than -- and replaces -- forbidding only immediate
                # nesting, and removes a much larger part of the space at the
                # cost of completeness.
                all_op_rule_strings = [
                    "bvadd",
                    "bvsub",
                    "bvxor",
                    "bvand",
                    "bvor",
                    "bvshl",
                    "bvlshr",
                    "bvashr",
                    "bvnand",
                    "bvnor",
                    "bvneg",
                    "bvnot",
                    "ehad",
                    "arba",
                    "shesh",
                    "smol",
                    "im_cvc",
                    "if0_cvc",
                ]

                for rule_string in all_op_rule_strings
                    indices = find_rules(grammar, rule_string)
                    if !isempty(indices)
                        RID_i = indices[1]
                        addconstraint!(grammar, ForbiddenSequence([RID_i, RID_i]))
                    end
                end

                # Stronger diversity bias for the unary bit-twiddling ops:
                # ForbiddenSequence only blocks *vertical* repetition (an op
                # reappearing below itself). It misses horizontal reuse, e.g.
                # bvadd_cvc(ehad_cvc(a), ehad_cvc(b)), where the same op is
                # applied to two unrelated subtrees. Unique forbids the rule
                # from appearing more than once anywhere in the program.
                unique_rule_strings = ["ehad", "arba", "shesh", "smol", "bvnot"]
                for rule_string in unique_rule_strings
                    indices = find_rules(grammar, rule_string)
                    if !isempty(indices)
                        addconstraint!(grammar, Unique(indices[1]))
                    end
                end

                @show grammar.constraints
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

    results_dir = "data/$ben_module/"
    mkpath(results_dir)
    results_file = "$results_dir$(name)_$(constrained_space)_constraints_results.csv"

    results_df = load_results(results_file)
    completed = Set(String.(results_df.Problem))

    println("Resuming $name on $ben_module (constraint set $constrained_space).")
    println("Already completed $(length(completed)) problems.")
    println("Checkpoint file: $results_file")

    for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
        problem = p_g_pair.problem

        if String(problem.name) in completed
            continue
        end

        if length(problem.spec) > 100
            println("Skipping $(problem.name): spec too large ($(length(problem.spec)) examples).")
            continue
        end

        problem_grammar = deepcopy(p_g_pair.grammar)

        clearconstraints!(problem_grammar)
        add_benchmark_constraints(problem_grammar, ben_module; constrained_space=constrained_space)

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
        expr = isnothing(program) ? nothing : rulenode2expr(program, problem_grammar)

        checkpoint_result!(
            results_df,
            results_file,
            problem.name,
            expr,
            num_derivations,
            elapsed_time_s,
        )

        push!(completed, String(problem.name))
        GC.gc()
    end

    println("Finished. Results stored in $results_file")
end


"""
constrained_space denotes which set of constraints to use for RQ2.
"""
function run_EUSolver(ben_module; constrained_space=2)
    name = "EUSolver"

    problem_grammar_pairs = get_all_problem_grammar_pairs(ben_module)
    if ben_module == PBE_SLIA_Track_2019
        problem_grammar_pairs = problem_grammar_pairs[1:100]
    end

    n_predicates = 100
    sym_bool = :ntBool
    sym_start = :Start
    sym_constraint = :nothing

    results_dir = "data/$ben_module/"
    mkpath(results_dir)
    results_file = "$results_dir$(name)_$(constrained_space)_constraints_results.csv"

    results_df = load_results(results_file)
    completed = Set(String.(results_df.Problem))

    println("Resuming $name on $ben_module (constraint set $constrained_space).")
    println("Already completed $(length(completed)) problems.")
    println("Checkpoint file: $results_file")

    for (i, p_g_pair) in ProgressBar(enumerate(problem_grammar_pairs))
        problem = p_g_pair.problem

        if String(problem.name) in completed
            continue
        end

        problem_grammar = deepcopy(p_g_pair.grammar)

        idx_ifelse = findfirst(r -> r == :($sym_bool ? $sym_start : $sym_start), problem_grammar.rules)

        if isnothing(idx_ifelse)
            if ben_module == PBE_BV_Track_2018
                add_rule!(problem_grammar, :($sym_bool = Start == UInt(0)))
            end
            add_rule!(problem_grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
        end

        clearconstraints!(problem_grammar)
        add_benchmark_constraints(problem_grammar, ben_module; constrained_space=constrained_space)

        iterator = BFSIterator(problem_grammar, :Start; max_depth=max_depth, max_size=max_size)

        # Build the fast generated interpreter (HerbInterpret.make_interpreter)
        # once per problem and hand it to divide_and_conquer explicitly, the
        # same way run_probe does. This is substantially faster on BV than
        # falling back to rulenode2expr + execute_on_input per candidate.
        interp = HerbInterpret.make_interpreter(
            problem_grammar;
            target_module = ben_module,
            cache_module  = ben_module,
        )

        start_time = time_ns()

        # `mod` must be the module the grammar's functions (e.g. ehad_cvc,
        # bvadd_cvc) are defined in. Without it, divide_and_conquer defaults
        # to `Main`, every interpretation throws UndefVarError, and decide()
        # silently swallows it (allow_errors=true), so nothing is ever found.
        program, num_derivations = divide_and_conquer(
            problem,
            iterator,
            sym_bool,
            sym_start,
            sym_constraint,
            n_predicates,
            max_time,
            max_enums,
            ben_module;
            interp = interp,
        )

        elapsed_time_s = (time_ns() - start_time) / 1e9
        expr = isnothing(program) ? nothing : rulenode2expr(program, problem_grammar)

        checkpoint_result!(
            results_df,
            results_file,
            problem.name,
            expr,
            num_derivations,
            elapsed_time_s,
        )

        push!(completed, String(problem.name))
        GC.gc()
    end

    println("Finished. Results stored in $results_file")
end


# for i in 0:2
#     println("Running constraint set $i.")
#     # run_probe(PBE_SLIA_Track_2019; constrained_space=i)
#     # run_EUSolver(PBE_SLIA_Track_2019; constrained_space=i)
# end

# for i in 0:2
#     run_EUSolver(PBE_BV_Track_2018; constrained_space=i)
#     run_probe(PBE_BV_Track_2018; constrained_space=i)
# end

if abspath(PROGRAM_FILE) == @__FILE__
    using HerbBenchmarks

    function resolve_benchmark(s::AbstractString)::Module
        sU = uppercase(String(s))

        # Friendly aliases
        if sU in ("BV2018", "PBE_BV_TRACK_2018")
            return HerbBenchmarks.PBE_BV_Track_2018
        elseif sU in ("SLIA2019", "PBE_SLIA_TRACK_2019")
            return HerbBenchmarks.PBE_SLIA_Track_2019
        end

        # Otherwise: allow passing the module name directly, e.g. "PBE_BV_Track_2018"
        sym = Symbol(s)
        if isdefined(HerbBenchmarks, sym)
            m = getfield(HerbBenchmarks, sym)
            if m isa Module
                return m
            end
        end
        error("Unknown benchmark '$s'. Use BV2018, SLIA2019, or a HerbBenchmarks module name.")
    end

    # usage:
    #   julia --project=. src/sygus_benchmark.jl EU BV2018 0
    #   julia --project=. src/sygus_benchmark.jl PROBE SLIA2019 2
    if length(ARGS) < 3
        error("Usage: julia --project=. src/sygus_benchmark.jl (EU|PROBE) (BV2018|SLIA2019|ModuleName) <0|1|2>")
    end

    mode  = uppercase(ARGS[1])
    bench = ARGS[2]
    i     = parse(Int, ARGS[3])

    ben_module = resolve_benchmark(bench)

    if mode == "EU"
        run_EUSolver(ben_module; constrained_space=i)
    elseif mode == "PROBE"
        run_probe(ben_module; constrained_space=i)
    else
        error("Unknown mode '$mode'. Use EU or PROBE.")
    end
end