using Plots
using Printf
pgfplotsx()

# ----------------------------
# Data (Program space counts) up to AST size 11
# ----------------------------
max_n = 11
sizes = collect(1:max_n)

# Arithmetic
arith_wo = [11, 11, 374, 374, 24332, 24332, 2000867, 2000867, 184632701, 184632701, 18265184267]
arith_w  = [11, 11, 201, 201, 7798, 7798, 383688, 383688, 21192628, 21192628, 1254647849]

# Robots
robots_wo = [1, 7, 43, 259, 1555, 9331, 55987, 335923, 2015539, 12093923, 72559411]
robots_w  = [1, 7, 43, 133, 407, 1457, 4025, 11001, 29666, 67129, 161965]

# Lists
lists_wo = [1, 3, 13, 51, 217, 951, 4297, 19887, 93757, 448875, 2176261]
lists_w  = [1, 1, 6, 20, 31, 56, 206, 1026, 1656, 5381, 16006]

# ----------------------------
# Reduction (%) = 100 * (1 - with/without)
# ----------------------------
reduction_percent(with, without) = 100 .* (1 .- (with ./ without))

arith_red  = reduction_percent(arith_w,  arith_wo)
robots_red = reduction_percent(robots_w, robots_wo)
lists_red  = reduction_percent(lists_w,  lists_wo)

# Fixed colors (so dots + labels match)
col_arith  = :red
col_lists  = :darkorange2
col_robots = :green

# ----------------------------
# Plot
# ----------------------------
p = plot(
    # title  = "Program space reduction after applying constraints",
    xlabel = "Maximum number of AST nodes",
    ylabel = "Program Space Reduction (%)",
    xticks = 1:max_n,
    yticks = 0:20:100,
    xlims  = (0.6, max_n + 2.2),
    ylims  = (-5, 105),
    legend = :bottomright,
    lw     = 2.5,
    marker = :none,
    grid   = true,
    left_margin   = 10Plots.mm,
    right_margin  = 40Plots.mm,
    bottom_margin = 10Plots.mm,
    top_margin    = 8Plots.mm,
)

plot!(p, sizes, arith_red;  label="Arithmetic Grammar", color=col_arith)
plot!(p, sizes, lists_red;  label="List Grammar",       color=col_lists)
plot!(p, sizes, robots_red; label="Robot Grammar",      color=col_robots)

# Dot ONLY at the last point (size 11), same color as line, no outline
scatter!(p, [max_n], [arith_red[end]];  label="", markercolor=col_arith,  markerstrokewidth=0, markersize=4)
scatter!(p, [max_n], [lists_red[end]];  label="", markercolor=col_lists,  markerstrokewidth=0, markersize=4)
scatter!(p, [max_n], [robots_red[end]]; label="", markercolor=col_robots, markerstrokewidth=0, markersize=4)

# ----------------------------
# End-label block with GIVEN remaining-space values:
# remaining: Arithmetic 6.87%, Lists 0.74%, Robots 0.13%
# so reduction labels are: 100 - remaining
# ----------------------------
remaining_arith  = 6.87
remaining_lists  = 0.74
remaining_robots = 0.13

label_arith  = 100.0 - remaining_arith   # 93.13
label_lists  = 100.0 - remaining_lists   # 99.26
label_robots = 100.0 - remaining_robots  # 99.87

function end_label_block_colored!(plt, x_anchor, entries;
                                  x_offset=0.55, y_start=96.0, y_step=-7.0, fontsize=13)
    # entries: Vector of (value, color)
    for (i, (val, c)) in enumerate(entries)
        y = y_start + (i-1)*y_step
        txt = @sprintf("%.2f\\%%", val)   # <- produces \% for LaTeX
        annotate!(plt, x_anchor + x_offset, y, text(txt, fontsize, :left, c))
    end
end

end_label_block_colored!(
    p,
    max_n,
    [
        (label_arith,  col_arith),
        (label_lists,  col_lists),
        (label_robots, col_robots),
    ];
    x_offset=0.55,
    y_start=96.0,
    y_step=-7.0,
    fontsize=13
)


display(p)
savefig(p, "program_space_reduction.pdf")

