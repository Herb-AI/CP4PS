using CSV
using DataFrames
using Plots

pgfplotsx()

const DATA_DIR  = normpath(joinpath(@__DIR__, "..", "data"))
const PLOTS_DIR = normpath(joinpath(@__DIR__, "..", "plots"))
const TIME_CUTOFF = 600.0

const GRAMMARS = Dict(
    1 => "robots",
    2 => "arithmetic",
    3 => "symbolic",
    4 => "lists",
)

# Keep colors aligned with your earlier preferences
const METHODS = [
    (suffix = "noconstr_run0.txt", label = "No Constraints", color = :cornflowerblue, linestyle = :dash),
    (suffix = "run0.txt",          label = "Propagation",    color = :goldenrod,      linestyle = :solid),
]

results_file(grammar_id::Int, suffix::AbstractString) =
    joinpath(DATA_DIR, "asp_bfs_grammar$(grammar_id)_$(suffix)")

function read_asp_results(path::AbstractString)
    df = CSV.read(path, DataFrame; stripwhitespace=true)

    # Normalize in case CSV keeps names slightly differently
    rename!(df, Dict(
        names(df)[1] => :max_size,
        names(df)[2] => :programs,
        names(df)[3] => :time,
    ))

    sort!(df, :max_size)
    return df
end

function grammar_size_range(grammar_id::Int)
    sizes = Int[]

    for method in METHODS
        file = results_file(grammar_id, method.suffix)
        if isfile(file)
            df = read_asp_results(file)
            append!(sizes, Int.(df.max_size))
        end
    end

    isempty(sizes) && error("No ASP data files found for grammar $grammar_id")
    return minimum(sizes):maximum(sizes)
end

function plot_asp_time_vs_size(grammar_id::Int, grammar_name::AbstractString)
    x_ticks = collect(grammar_size_range(grammar_id))

    plt = plot(
        xlabel = "Program Size",
        ylabel = "Enumeration Time (s)",
        # title = "$(uppercasefirst(grammar_name)): ASP Time vs Size",
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

        df = read_asp_results(file)

        # log-scale y-axis needs strictly positive values
        positive = df.time .> 0
        df = df[positive, :]

        plot!(
            plt,
            Int.(df.max_size),
            Float64.(df.time);
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

    out = joinpath(PLOTS_DIR, "asp_$(grammar_name)_time_vs_size.pdf")
    savefig(plt, out)
    println("Saved $out")
end

function main()
    mkpath(PLOTS_DIR)

    for grammar_id in sort(collect(keys(GRAMMARS)))
        grammar_name = GRAMMARS[grammar_id]
        println("Plotting ASP grammar $grammar_id ($grammar_name) ...")
        plot_asp_time_vs_size(grammar_id, grammar_name)
    end

    println("Done. Wrote 4 ASP plots to $PLOTS_DIR")
end

main()