using DataFrames
using Plots

pgfplotsx()

const DATA_DIR  = normpath(joinpath(@__DIR__, "..", "data"))
const PLOTS_DIR = normpath(joinpath(@__DIR__, "..", "plots"))

const GRAMMARS = Dict(
    1 => "robots",
    2 => "arithmetic",
    3 => "symbolic",
    4 => "lists",
)

# Consistent style for the three methods across all plots
# Chosen from the palette used in your earlier script
const METHODS = [
    (suffix = "constraints0_run0.txt",  label = "No Constraints",         color = :cornflowerblue, linestyle = :dash),
    (suffix = "retrospective_run0.txt", label = "Retrospective Checking", color = :darkturquoise,  linestyle = :dot),
    (suffix = "run0.txt",               label = "Propagation",            color = :goldenrod,      linestyle = :solid),
]

const TIME_CUTOFF = 600.0

function read_results(path::AbstractString)
    rows = Vector{NamedTuple{(:depth, :max_bank_size, :time), Tuple{Int, Int, Float64}}}()

    open(path, "r") do io
        for (i, line) in enumerate(eachline(io))
            s = strip(line)
            isempty(s) && continue

            parts = split(s, ",")
            length(parts) == 3 || error("Expected 3 comma-separated values in $path at line $i, got: $line")

            push!(rows, (
                depth = parse(Int, strip(parts[1])),
                max_bank_size = parse(Int, strip(parts[2])),
                time = parse(Float64, strip(parts[3])),
            ))
        end
    end

    df = DataFrame(rows)
    sort!(df, :depth)
    return df
end

results_file(grammar_id::Int, method_suffix::AbstractString) =
    joinpath(DATA_DIR, "bus_grammar$(grammar_id)_$(method_suffix)")

function grammar_depth_range(grammar_id::Int)
    depths = Int[]

    for method in METHODS
        file = results_file(grammar_id, method.suffix)
        if isfile(file)
            df = read_results(file)
            append!(depths, df.depth)
        end
    end

    isempty(depths) && error("No data files found for grammar $grammar_id")

    return minimum(depths):maximum(depths)
end

function plot_programs_vs_size(grammar_id::Int, grammar_name::AbstractString)
    x_ticks = collect(grammar_depth_range(grammar_id))

    plt = plot(
        xlabel = "Program Size",
        ylabel = "Number of Programs",
        # title = "$(uppercasefirst(grammar_name)): Programs vs Size",
        xscale = :identity,
        yscale = :log10,
        xticks = x_ticks,
        legend = :topleft,
        linewidth = 2,
        marker = :circle,
        markersize = 3,
    )

    for method in METHODS
        file = results_file(grammar_id, method.suffix)

        if !isfile(file)
            @warn "Missing file: $file"
            continue
        end

        df = read_results(file)

        plot!(
            plt,
            df.depth,
            Float64.(df.max_bank_size);
            label = method.label,
            color = method.color,
            linestyle = method.linestyle,
            linewidth = 2,
            marker = :circle,
            markersize = 3,
        )
    end

    out = joinpath(PLOTS_DIR, "$(grammar_name)_programs_vs_size.pdf")
    savefig(plt, out)
    println("Saved $out")
end

function plot_time_vs_size(grammar_id::Int, grammar_name::AbstractString)
    x_ticks = collect(grammar_depth_range(grammar_id))

    plt = plot(
        xlabel = "Program Size",
        ylabel = "Enumeration Time (s)",
        # title = "$(uppercasefirst(grammar_name)): Time vs Size",
        xscale = :identity,
        yscale = :log10,
        xticks = x_ticks,
        legend = :topleft,
        linewidth = 2,
        marker = :circle,
        markersize = 3,
    )

    for method in METHODS
        file = results_file(grammar_id, method.suffix)

        if !isfile(file)
            @warn "Missing file: $file"
            continue
        end

        df = read_results(file)

        plot!(
            plt,
            df.depth,
            df.time;
            label = method.label,
            color = method.color,
            linestyle = method.linestyle,
            linewidth = 2,
            marker = :circle,
            markersize = 3,
        )
    end

    hline!(
        plt,
        [TIME_CUTOFF];
        color = :red,
        linestyle = :dash,
        linewidth = 2,
        label = "Cut-off (600 s)",
    )

    out = joinpath(PLOTS_DIR, "$(grammar_name)_time_vs_size.pdf")
    savefig(plt, out)
    println("Saved $out")
end

function main()
    mkpath(PLOTS_DIR)

    for grammar_id in sort(collect(keys(GRAMMARS)))
        grammar_name = GRAMMARS[grammar_id]
        println("Plotting grammar $grammar_id ($grammar_name) ...")

        plot_programs_vs_size(grammar_id, grammar_name)
        plot_time_vs_size(grammar_id, grammar_name)
    end

    println("Done. Wrote plots to $PLOTS_DIR")
end

main()