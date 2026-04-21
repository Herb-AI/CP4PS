using CSV
using DataFrames
using Plots
using Statistics

pgfplotsx()

const DATA_DIR  = normpath(joinpath(@__DIR__, "..", "data"))
const PLOTS_DIR = normpath(joinpath(@__DIR__, "..", "plots"))

const SUMMARY_FILE = joinpath(DATA_DIR, "first_order_symbolic_results", "summary.tsv")

prop_formatter(x) = x == 0 ? "0" : "\$$(round(x / 1_000_000; digits=1)) \\times 10^6\$"

function read_firstorder_results(path::AbstractString)
    df = CSV.read(path, DataFrame; delim='\t', stripwhitespace=true)

    println("Columns found in $path:")
    println(names(df))

    required = [
        :number_of_constraints,
        :runtime_seconds,
        :propagation_calls,
    ]

    available = propertynames(df)

    for col in required
        col in available || error(
            "Missing column $col. Available columns are: $(available)"
        )
    end

    sort!(df, :number_of_constraints)
    return df
end


function safe_std(xs)
    ys = collect(skipmissing(Float64.(xs)))
    return length(ys) <= 1 ? 0.0 : std(ys)
end

function aggregate_results(df::DataFrame)
    gdf = groupby(df, :number_of_constraints)

    agg = combine(
        gdf,
        :runtime_seconds => mean => :runtime_mean,
        :runtime_seconds => safe_std => :runtime_std,
        :propagation_calls => mean => :propagation_mean,
        :propagation_calls => safe_std => :propagation_std,
        nrow => :runs,
    )

    sort!(agg, :number_of_constraints)
    return agg
end

const PROP_TICKS = 0:500_000:3_000_000

function plot_time_vs_constraints(df::DataFrame)
    max_time = maximum(Float64.(df.runtime_mean))

    plt = plot(
        Int.(df.number_of_constraints),
        Float64.(df.runtime_mean);
        xlabel = "Number of Constraints",
        ylabel = "Enumeration Time (s)",
        label = false,
        linewidth = 2,
        marker = false,
        ylim = (0, max_time * 1.05),
    )

    out = joinpath(PLOTS_DIR, "firstorder_time_vs_constraints.pdf")
    savefig(plt, out)
    println("Saved $out")
end
function plot_time_vs_propagation(df::DataFrame)
    sort!(df, :propagation_mean)

    max_time = maximum(Float64.(df.runtime_mean))

    plt = plot(
        Float64.(df.propagation_mean),
        Float64.(df.runtime_mean);
        xlabel = "Propagation Calls",
        ylabel = "Enumeration Time (s)",
        label = false,
        linewidth = 2,
        marker = false,
        ylim = (0, max_time * 1.05),
        xticks = PROP_TICKS,
        xformatter = prop_formatter,
    )

    out = joinpath(PLOTS_DIR, "firstorder_time_vs_propagation.pdf")
    savefig(plt, out)
    println("Saved $out")
end

function plot_propagation_vs_constraints(df::DataFrame)
    plt = plot(
        Int.(df.number_of_constraints),
        Float64.(df.propagation_mean);
        xlabel = "Number of Constraints",
        ylabel = "Propagation Calls",
        label = false,
        linewidth = 2,
        marker = false,
        ylim = (0, 3_000_000),
        yticks = PROP_TICKS,
        yformatter = prop_formatter,
    )

    out = joinpath(PLOTS_DIR, "firstorder_propagation_vs_constraints.pdf")
    savefig(plt, out)
    println("Saved $out")
end

function main()
    mkpath(PLOTS_DIR)

    raw = read_firstorder_results(SUMMARY_FILE)
    df = aggregate_results(raw)

    plot_time_vs_constraints(df)
    plot_propagation_vs_constraints(df)
    plot_time_vs_propagation(df)

    println("Done. Wrote first-order constraint plots to $PLOTS_DIR")
end

main()