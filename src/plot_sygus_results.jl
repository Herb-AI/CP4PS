
using CSV
using DataFrames
using Plots
pgfplotsx()


function plot_cumulative_problems!(results_file, plot_label; color=:auto, linestyle=:solid)
    if !isfile(results_file)
        println("\tWarning: $(results_file) not found.")
        return nothing
    else
        println("\tPlotting $results_file ...")
    end

    df = CSV.read(results_file, DataFrame)
    max_eff = maximum(df.Effectivity)

    filter!(row -> row.Program != "\$(Expr(:Start))", df)
    sort!(df, :Effectivity)

    # Count number of problems solved at each Effectivity
    counts = combine(groupby(df, :Effectivity), nrow => :NumProblemsSolved)
    counts.Cumulative = cumsum(counts.NumProblemsSolved)

    # Extend to max
    final_y = last(counts.Cumulative)

    # Add (0, 0) and (max_eff, final_y)
    x = [1.0; counts.Effectivity; max_eff]
    y = [0; counts.Cumulative; final_y]

    # Plot step-post
    plot!(x, y;
        label=plot_label,
        line=:steppost,
        color=color,
        linestyle=linestyle,
        linewidth=2,
    )
end


function plot_benchmark(ben_module)
    synthesizers = ["EUSolver", "probe"]
    constraint_levels = 0:2

    colors = Dict("EUSolver" => :cornflowerblue, "probe" => :tomato)
    linestyles = Dict(0 => :solid, 1 => :dash, 2 => :dot)

    # Start plot
    plt = plot(xscale=:log10, xlabel="Number of Programs Enumerated", ylabel="Cumulative Problems Solved",
               title=ben_module, legend=:bottomright)

    for synth in synthesizers
        for c in constraint_levels
            results_file = "data/$ben_module/$(synth)_$(c)_constraints_results.csv"
            label = "$synth, C$c"
            plot_cumulative_problems!(results_file, label;
                color=colors[synth], linestyle=linestyles[c])
        end
    end

    savefig(plt, "plots/$(ben_module)_results_plot.pdf")
    println("Saved plot for $ben_module to plots/$(ben_module)_results_plot.pdf")
end

plot_benchmark("HerbBenchmarks.PBE_SLIA_Track_2019")
plot_benchmark("HerbBenchmarks.PBE_BV_Track_2018")