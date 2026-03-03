using Plots
using Printf
pgfplotsx()

# ----------------------------
# Settings
# ----------------------------
x_max = 14
eps_rt = 1e-4

col_arith  = :red
col_lists  = :darkorange2
col_robots = :green
col_symb   = :gray40

# ----------------------------
# Helpers
# ----------------------------
sanitize_rt(x; eps=eps_rt) = (x === missing) ? missing : (x > 0 ? Float64(x) : eps)

function ratio_series(rt_check, rt_prop; eps=eps_rt)
    n = min(length(rt_check), length(rt_prop))
    ys = Vector{Union{Missing,Float64}}(undef, n)
    for i in 1:n
        a = sanitize_rt(rt_check[i]; eps=eps)
        b = sanitize_rt(rt_prop[i];  eps=eps)
        ys[i] = (a === missing || b === missing) ? missing : (a / b)
    end
    return ys
end

function plot_skipmissing!(p, xs, ys; label, color, lw=1.5)
    x = Int[]; y = Float64[]
    for (xi, yi) in zip(xs, ys)
        if yi !== missing
            push!(x, xi); push!(y, Float64(yi))
        end
    end
    plot!(p, x, y; label=label, color=color, lw=lw, marker=:none)
    return x, y
end

function add_last_dot_and_label!(p, x, y; color, xoff=0.35, yfac=1.10)
    scatter!(p, [x], [y]; label="", markercolor=color, markerstrokewidth=0, markersize=4)
    txt = @sprintf("%d", round(Int, y))
    annotate!(p, x + xoff, y * yfac, text(txt, 11, :left, color))
end

# ----------------------------
# Data (runtimes in seconds)
# ----------------------------

arith_size = 1:11
arith_rt_wo = [0.0, 0.0, 0.0, 0.0, 0.039, 0.039, 3.190, 3.852, 361.538, 357.280, 35048.885]
arith_rt_w  = [0.0, 0.0, 0.002, 0.002, 0.018, 0.018, 0.814, 0.819, 43.842, 45.778, 2592.975]

robots_size = 1:12
robots_rt_wo = [0.0, 0.0, 0.0, 0.0, 0.002, 0.017, 0.093, 0.492, 3.270, 23.728, 141.965, 844.853]
robots_rt_w  = [0.0, 0.0, 0.0, 0.002, 0.004, 0.022, 0.071, 0.209, 0.538, 1.306, 2.855, 6.794]

symb_size = 1:11
symb_rt_wo = [0.0, 0.0, 0.0, 0.001, 0.010, 0.072, 0.550, 4.469, 43.766, 377.454, 3213.797]
symb_rt_w  = [0.0, 0.0, 0.001, 0.002, 0.007, 0.020, 0.056, 0.146, 0.406, 1.143, 3.011]

lists_size = 1:14
lists_rt_wo = [0.0, 0.0, 0.0, 0.001, 0.002, 0.010, 0.036, 0.124, 0.513, 2.172, 8.963, 37.675, 150.302, 771.796]
lists_rt_w  = [0.0, 0.0, 0.001, 0.001, 0.003, 0.008, 0.018, 0.042, 0.092, 0.216, 0.580, 1.159, 3.010, 6.346]

# ----------------------------
# Ratios
# ----------------------------
arith_ratio  = ratio_series(arith_rt_wo,  arith_rt_w)
robots_ratio = ratio_series(robots_rt_wo, robots_rt_w)
symb_ratio   = ratio_series(symb_rt_wo,   symb_rt_w)
lists_ratio  = ratio_series(lists_rt_wo,  lists_rt_w)

# ----------------------------
# Plot
# ----------------------------
p = plot(
    # title  = "Runtime Ratio (no constraints / propagating)",
    xlabel = "Maximum number of AST nodes",
    ylabel = "Runtime ratio (no con./prop.)",
    xlims  = (0.6, x_max + 1.4),
    xticks = 1:x_max,
    yscale = :log10,
    ylims  = (5e-2, 1e4),          # <-- add margin under curves
    yticks = 10.0 .^ (-2:4),       # optional: include 10^-2 tick since we extended lower
    legend = :topleft,
    grid   = true,
    marker = :none,
    right_margin  = 26Plots.mm,
    left_margin   = 10Plots.mm,
    bottom_margin = 14Plots.mm,
    top_margin    = 8Plots.mm,
)

lw = 1.5
xR, yR = plot_skipmissing!(p, robots_size, robots_ratio; label="Robot Grammar",       color=col_robots, lw=lw)
xA, yA = plot_skipmissing!(p, arith_size,  arith_ratio;  label="Arithmetic Grammar", color=col_arith,  lw=lw)
xS, yS = plot_skipmissing!(p, symb_size,   symb_ratio;   label="Symbolic Grammar",   color=col_symb,   lw=lw)
xL, yL = plot_skipmissing!(p, lists_size,  lists_ratio;  label="List Grammar",       color=col_lists,  lw=lw)

# Last-point dots + labels (nudged right a bit more now that we have room)
add_last_dot_and_label!(p, xR[end], yR[end]; color=col_robots, xoff=0.35, yfac=1.12)
add_last_dot_and_label!(p, xA[end], yA[end]; color=col_arith,  xoff=0.35, yfac=1.12)
add_last_dot_and_label!(p, xS[end], yS[end]; color=col_symb,   xoff=0.35, yfac=1.12)
add_last_dot_and_label!(p, xL[end], yL[end]; color=col_lists,  xoff=0.35, yfac=1.12)

display(p)
savefig(p, "runtime_ratio_checking_vs_propagating.pdf")

