using CSV
using DataFrames
using Plots
pgfplotsx()

# Define column names
column_names = [:depth, :max_bank_size, :time]

# Load the data from the files without headers and assign column names
data_bottom_up = CSV.read("_/data/bus_grammar4_retrospective_run0.txt", DataFrame; header=false)
rename!(data_bottom_up, column_names)

data_uniform = CSV.read("_/data/bus_grammar4_run1.txt", DataFrame; header=false)
rename!(data_uniform, column_names)

# Replace 0 values with 1 in the max_bank_size column for both datasets
data_bottom_up.max_bank_size .= ifelse.((data_bottom_up.max_bank_size .== 0), 1, data_bottom_up.max_bank_size)
data_uniform.max_bank_size .= ifelse.((data_uniform.max_bank_size .== 0), 1, data_uniform.max_bank_size)

ytick_values = [10^i for i in 0:5]

# Create the plot
plot(
    data_bottom_up.depth, data_bottom_up.max_bank_size,
    label = "Standard Bottom-Up Search",
    xlabel = "Program depth",
    ylabel = "Max Bank Size",
    title = "Max Bank Size over Depth",
    yscale = :log10,
    legend = :topleft,
    ylim = (1, 2*10^5),
    yticks = ytick_values
)

# Add the second dataset to the plot
plot!(
    data_uniform.depth, data_uniform.max_bank_size,
    label = "Using Uniform Trees"
)

# Annotate the final points with their values
last_depth_bu = data_bottom_up.depth[end]
last_max_bank_size_bu = data_bottom_up.max_bank_size[end]
println(last_max_bank_size_bu)
annotate!(last_depth_bu, last_max_bank_size_bu, text("$last_max_bank_size_bu", 6, :right))

last_depth_ut = data_uniform.depth[end]
last_max_bank_size_ut = data_uniform.max_bank_size[end]
println(last_max_bank_size_ut)
annotate!(last_depth_ut, last_max_bank_size_ut, text("$last_max_bank_size_ut", 6, :right))


savefig("plots/bottom_up_search_bank_size.png")

