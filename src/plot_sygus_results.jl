
using CSV
using DataFrames
using Plots
pgfplotsx()

# Helper to pretty-print legend labels
function legend_label(synth, constraint_level)
    synth_label = synth == "probe" ? "Probe" : synth
    constraint_label = Dict(
        0 => "Without Constraints",
        1 => "Removing Redundancies (RR)",
        2 => "RR + Useful Constraints"
    )[constraint_level]
    return "$synth_label: $constraint_label"
end

# Custom line styles (longer dashes/dots)
custom_linestyles = Dict(
    0 => :dash,
    1 => :solid,#(line=:dash, dash=[10, 5]),
    2 => :solid#(line=:dot, dash=[2, 6])  # longer spacing for better visibility
)

function log10_ticks(n::Int)
    values = 10 .^ (0:n)
    labels = ["\$10^{$i}\$" for i in 0:n]
    return values, labels
end

function plot_cumulative_problems!(results_file, plot_label; color=:auto, linestyle=:solid)
    # column=:Effectivity
    column=:Time_in_s
    

    if !isfile(results_file)
        println("\tWarning: $(results_file) not found.")
        return
    else
        println("\tPlotting $results_file ...")
    end

    if occursin("probe_2", results_file)
        color = :goldenrod
    elseif occursin("EUSolver_2", results_file)
        color = :darkturquoise
    end

    df = CSV.read(results_file, DataFrame)
    # max_eff = maximum(df.Effectivity)
    max_time = maximum(df.Time_in_s)

    filter!(row -> row.Program != "\$(Expr(:Start))", df)
    sort!(df, :Effectivity)

    counts = combine(groupby(df, :Effectivity), nrow => :NumProblemsSolved)
    counts.Cumulative = cumsum(counts.NumProblemsSolved)

    final_y = last(counts.Cumulative)

    x = [1.0; counts.Effectivity; max_eff]
    y = [0; counts.Cumulative; final_y]

    # Handle either Symbol or Tuple form for linestyle
    kwargs = if isa(linestyle, NamedTuple)
        merge(linestyle, (; linewidth=2))
    else
        (linestyle=linestyle, linewidth=2)
    end

    plot!(x, y;
        label=plot_label,
        color=color,
        line=:steppost,
        kwargs...
    )
end

function plot_benchmark(ben_module)
    synthesizers = ["EUSolver", "probe"]
    constraint_levels = 0:2
    colors = Dict("EUSolver" => :cornflowerblue, "probe" => :tomato)

    # Use readable titles instead of full benchmark names
    title_map = Dict(
        "HerbBenchmarks.PBE_SLIA_Track_2019" => "SLIA",
        "HerbBenchmarks.PBE_BV_Track_2018"   => "BV"
    )
    title_str = get(title_map, ben_module, ben_module)

    n = title_str == "SLIA" ? 7 : 6
    xticks = log10_ticks(n)

    plt = plot(xscale=:log10,
               xlabel="Number of Programs Enumerated",
               ylabel="Cumulative Problems Solved",
               title=title_str,
               xlim=(0.8,10^n),
               xticks=xticks,
               legend=:bottomright)

    for synth in synthesizers
        for c in constraint_levels
            results_file = "data/$ben_module/$(synth)_$(c)_constraints_results.csv"
            label = legend_label(synth, c)
            plot_cumulative_problems!(results_file, label;
                color=colors[synth], linestyle=custom_linestyles[c])
        end
    end

    savefig(plt, "plots/$(title_str)_results_plot.pdf")
    println("Saved plot for $ben_module to plots/$(title_str)_results_plot.pdf")
end

function plot_cumulative_problems_time!(results_file, plot_label; color=:auto, linestyle=:solid)
    if !isfile(results_file)
        println("\tWarning: $(results_file) not found.")
        return
    else
        println("\tPlotting $results_file ...")
    end

    if occursin("probe_2", results_file)
        color = :goldenrod
    elseif occursin("EUSolver_2", results_file)
        color = :darkturquoise
    end

    df = CSV.read(results_file, DataFrame)

    # Remove unwanted placeholder program
    filter!(row -> row.Program != "\$(Expr(:Start))", df)

    # Sort by solving time instead of Effectivity
    sort!(df, :Time_in_s)

    # Count solved problems grouped by time
    counts = combine(groupby(df, :Time_in_s), nrow => :NumProblemsSolved)
    counts.Cumulative = cumsum(counts.NumProblemsSolved)

    final_y = last(counts.Cumulative)

    x = [0.0; counts.Time_in_s]
    y = [0; counts.Cumulative]

    # Handle either Symbol or Tuple form for linestyle
    kwargs = if isa(linestyle, NamedTuple)
        merge(linestyle, (; linewidth=2))
    else
        (linestyle=linestyle, linewidth=2)
    end

    plot!(x, y;
        xscale=:log10,
        label=plot_label,
        color=color,
        line=:steppost,
        kwargs...
    )
end

function plot_benchmark_time(ben_module)
    synthesizers = ["EUSolver", "probe"]
    constraint_levels = 0:2
    colors = Dict("EUSolver" => :cornflowerblue, "probe" => :tomato)

    title_map = Dict(
        "HerbBenchmarks.PBE_SLIA_Track_2019" => "SLIA",
        "HerbBenchmarks.PBE_BV_Track_2018"   => "BV"
    )
    title_str = get(title_map, ben_module, ben_module)

    plt = plot(xscale=:linear,  # now linear instead of log
               xlabel="Solving Time (s)",
               ylabel="Cumulative Problems Solved",
               title=title_str,
               legend=:bottomright)

    for synth in synthesizers
        for c in constraint_levels
            println("Plotting constraint: $c")
            results_file = "data/$ben_module/$(synth)_$(c)_constraints_results.csv"
            label = legend_label(synth, c)
            plot_cumulative_problems_time!(results_file, label;
                color=colors[synth], linestyle=custom_linestyles[c])
        end
    end

    savefig(plt, "plots/$(title_str)_time_results_plot.pdf")
    println("Saved plot for $ben_module to plots/$(title_str)_time_results_plot.pdf")
end

# Plot both benchmark sets
plot_benchmark_time("HerbBenchmarks.PBE_SLIA_Track_2019")
plot_benchmark_time("HerbBenchmarks.PBE_BV_Track_2018")


# Plot both benchmark sets
# plot_benchmark("HerbBenchmarks.PBE_SLIA_Track_2019")
# plot_benchmark("HerbBenchmarks.PBE_BV_Track_2018")

