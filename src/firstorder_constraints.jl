using Dates
using Printf

# Adjust these imports to match your project layout.
using HerbCore
using HerbConstraints
using HerbSearch
using HerbGrammar

include("_thesis_helpers.jl")
include("_helper_functions.jl")

outdir = "data/first_order_symbolic_results/"

# ---------------------------------------------------------------------
# First-order constraint experiment setup
# ---------------------------------------------------------------------

robots = 1
arithmetic = 2
symbolic = 3
lists = 4
lists_grounded = 5

const FO_PARENT_RULES = [7, 8, 9]
const FO_CHILD_RULES  = [1, 2, 3, 10]

const ALL_FORBIDDEN_TRIPLES = [
    (p, l, r)
    for p in FO_PARENT_RULES
    for l in FO_CHILD_RULES
    for r in FO_CHILD_RULES
]

struct FOCase
    parents::Vector{Int}
    lefts::Vector{Int}
    rights::Vector{Int}
end

covered_cases(c::FOCase) =
    length(c.parents) * length(c.lefts) * length(c.rights)

has_first_order_constraint(c::FOCase) =
    covered_cases(c) > 0

grounded_constraints_needed(c::FOCase) =
    length(ALL_FORBIDDEN_TRIPLES) - covered_cases(c)

number_of_constraints(c::FOCase) =
    grounded_constraints_needed(c) + (has_first_order_constraint(c) ? 1 : 0)

domstring(xs) = isempty(xs) ? "{}" : "{" * join(xs, ",") * "}"

function case_name(c::FOCase)
    return "n$(number_of_constraints(c))_" *
           "covered$(covered_cases(c))_" *
           "p$(join(c.parents, "-"))_" *
           "l$(join(c.lefts, "-"))_" *
           "r$(join(c.rights, "-"))"
end

# ---------------------------------------------------------------------
# Constraint construction
# ---------------------------------------------------------------------

function first_order_forbidden(grammar, c::FOCase)
    return Forbidden(
        DomainRuleNode(grammar, c.parents, AbstractRuleNode[
            DomainRuleNode(grammar, c.lefts),
            DomainRuleNode(grammar, c.rights),
        ])
    )
end

function grounded_forbidden(parent_rule::Int, left_rule::Int, right_rule::Int)
    return Forbidden(
        RuleNode(parent_rule, AbstractRuleNode[
            RuleNode(left_rule),
            RuleNode(right_rule),
        ])
    )
end

function constraints_for_case(grammar, c::FOCase)
    constraints = Any[]

    if has_first_order_constraint(c)
        push!(constraints, first_order_forbidden(grammar, c))
    end

    ps = Set(c.parents)
    ls = Set(c.lefts)
    rs = Set(c.rights)

    for (p, l, r) in ALL_FORBIDDEN_TRIPLES
        covered_by_first_order =
            (p in ps) && (l in ls) && (r in rs)

        if !covered_by_first_order
            push!(constraints, grounded_forbidden(p, l, r))
        end
    end

    return constraints
end

# One representative for each achievable number of constraints.
# Includes the pure grounded case: 48 grounded constraints, no first-order one.
function representative_cases()
    by_nconstraints = Dict{Int, FOCase}()

    # Pure grounded baseline.
    grounded_only = FOCase(Int[], Int[], Int[])
    by_nconstraints[number_of_constraints(grounded_only)] = grounded_only

    for np in 1:length(FO_PARENT_RULES),
        nl in 1:length(FO_CHILD_RULES),
        nr in 1:length(FO_CHILD_RULES)

        c = FOCase(
            FO_PARENT_RULES[1:np],
            FO_CHILD_RULES[1:nl],
            FO_CHILD_RULES[1:nr],
        )

        n = number_of_constraints(c)

        # Keep one deterministic representative per constraint count.
        if !haskey(by_nconstraints, n)
            by_nconstraints[n] = c
        end
    end

    return [by_nconstraints[n] for n in sort(collect(keys(by_nconstraints)))]
end

# This is the smaller sweep described explicitly in the text:
# {7,8,9}, then {7,8}, then {7}, then all grounded.
function parent_domain_sweep_cases()
    return FOCase[
        FOCase([7, 8, 9], FO_CHILD_RULES, FO_CHILD_RULES),
        FOCase([7, 8],    FO_CHILD_RULES, FO_CHILD_RULES),
        FOCase([7],       FO_CHILD_RULES, FO_CHILD_RULES),
        FOCase(Int[],     Int[],          Int[]),   # pure grounded
    ]
end

# ---------------------------------------------------------------------
# Result helpers
# ---------------------------------------------------------------------

function statistics_text(stats)
    try
        return sprint(io -> show(io, MIME"text/plain"(), stats))
    catch
        return sprint(show, stats)
    end
end

function stat_total(stats_as_text::AbstractString, token::AbstractString)
    total = 0
    for line in split(stats_as_text, '\n')
        if occursin(token, line)
            m = match(r"([0-9]+)\s*$", line)
            if m !== nothing
                total += parse(Int, m.captures[1])
            end
        end
    end
    return total
end

function write_summary_tsv(results, filename)
    headers = [
        :case,
        :repeat,
        :max_size,
        :number_of_constraints,
        :first_order_covered_cases,
        :grounded_constraints,
        :programs,
        :runtime_seconds,
        :search_nodes,
        :propagation_calls,
        :parent_domain,
        :left_domain,
        :right_domain,
    ]

    open(filename, "w") do io
        println(io, join(string.(headers), '\t'))

        for r in results
            println(io, join((string(getfield(r, h)) for h in headers), '\t'))
        end
    end
end

# ---------------------------------------------------------------------
# Main runner
# ---------------------------------------------------------------------

function run_first_order_symbolic_experiment(;
    cases = representative_cases(),
    repeats::Int = 1,
    max_size::Int = 8l
    make_grammar = () -> get_thesis_grammar(symbolic, 0),
    start_symbol = get_starting_symbol(symbolic),
    expected_programs = 1_358_656,
)
    mkpath(outdir)

    results = NamedTuple[]

    for rep in 1:repeats
        for c in cases
            grammar = make_grammar()

            constraints = constraints_for_case(grammar, c)
            for con in constraints
                addconstraint!(grammar, con)
            end

            solver = GenericSolver(
                grammar,
                start_symbol,
                with_statistics = true,
                use_uniformsolver = true,
            )

            iter = BFSIterator(
                solver = solver,
                max_size = max_size,
            )

            programs = 0
            runtime_seconds = @elapsed begin
                programs = length(iter)
            end

            stats = statistics_text(solver.statistics)
            search_nodes = get_search_nodes(solver)
            propagation_calls = stat_total(stats, " propagation")

            if expected_programs !== nothing && programs != expected_programs
                @warn "Unexpected program count" programs expected_programs c
            end

            result = (
                case = case_name(c),
                repeat = rep,
                max_size = max_size,
                number_of_constraints = length(constraints),
                first_order_covered_cases = covered_cases(c),
                grounded_constraints = grounded_constraints_needed(c),
                programs = programs,
                runtime_seconds = runtime_seconds,
                search_nodes = search_nodes,
                propagation_calls = propagation_calls,
                parent_domain = domstring(c.parents),
                left_domain = domstring(c.lefts),
                right_domain = domstring(c.rights),
            )

            push!(results, result)

            logfile = joinpath(outdir, "$(case_name(c))_rep$(rep).txt")
            open(logfile, "w") do io
                println(io, "max_size = $max_size")
                println(io, "number_of_constraints = $(length(constraints))")
                println(io, "first_order_covered_cases = $(covered_cases(c))")
                println(io, "grounded_constraints = $(grounded_constraints_needed(c))")
                println(io, "parent_domain = $(domstring(c.parents))")
                println(io, "left_domain = $(domstring(c.lefts))")
                println(io, "right_domain = $(domstring(c.rights))")
                println(io, "programs = $programs")
                println(io, "runtime_seconds = $runtime_seconds")
                println(io)
                println(io, stats)
                println(io)
                println(io, "SEARCHNODES: $search_nodes")
                println(io, "PROPAGATION_CALLS: $propagation_calls")
            end

            @info "finished case" result
        end
    end

    summary_file = joinpath(outdir, "summary.tsv")
    write_summary_tsv(results, summary_file)

    return results
end

results = run_first_order_symbolic_experiment()