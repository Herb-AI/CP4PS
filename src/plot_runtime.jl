using Plots
pgfplotsx()

# ----------------------------
# Data (runtimes in seconds)
# ----------------------------

# Arithmetic (sizes 1..11)
arith_size = 1:11
arith_rt_wo = [0.0, 0.0, 0.0, 0.0, 0.039, 0.039, 3.190, 3.852, 361.538, 357.280, 35048.885]
arith_rt_w  = [0.0, 0.0, 0.001, 0.001, 0.018, 0.018, 0.814, 0.819, 43.842, 45.778, 2592.975]

# Robots (sizes 1..21)  -- Without-constraints runtime is (*) from 13..21 => missing
robots_size = 1:21
robots_rt_wo = Union{Missing,Float64}[
    0.0, 0.0, 0.0, 0.0, 0.002, 0.017, 0.093, 0.492, 3.270, 23.728, 141.965, 844.853,
    missing, missing, missing, missing, missing, missing, missing, missing, missing
]
robots_rt_w = [
    0.0, 0.0, 0.0, 0.002, 0.004, 0.022, 0.071, 0.209, 0.538, 1.306, 2.855, 6.794,
    12.288, 23.051, 42.535, 69.516, 96.197, 182.691, 296.374, 447.164, 681.843
]

# Symbolic (sizes 1..16) -- Without-constraints runtime is '-' from 12..16 => missing
symb_size = 1:16
symb_rt_wo = Union{Missing,Float64}[
    0.0, 0.0, 0.001, 0.001, 0.010, 0.072, 0.550, 4.469, 43.766, 377.454, 3213.797,
    missing, missing, missing, missing, missing
]
symb_rt_w = [0.0, 0.0, 0.001, 0.002, 0.007, 0.020, 0.056, 0.146, 0.406, 1.143, 3.011, 8.752, 24.491, 71.632, 210.122, 653.034]

# Lists (sizes 1..19) -- Without-constraints runtime is '-' from 16..19 => missing
lists_size = 1:19
lists_rt_wo = Union{Missing,Float64}[
    0.0, 0.0, 0.0, 0.001, 0.002, 0.010, 0.036, 0.124, 0.513, 2.172, 8.963, 37.675, 150.302, 771.796, 3629.086,
    missing, missing, missing, missing
]
lists_rt_w = [0.0, 0.0, 0.001, 0.001, 0.003, 0.008, 0.018, 0.042, 0.092, 0.216, 0.580, 1.159, 3.010, 6.346, 15.498, 36.277, 89.173, 250.183, 652.133]


sanitize_for_log10(ys; eps=1e-4) = Union{Missing,Float64}[
    (y === missing) ? missing : (Float64(y) > 0 ? Float64(y) : eps)
    for y in ys
]

function decade_ticks_and_lims(ys...; y_min=1e-4)
    vals = Float64[]
    for v in ys, y in v
        if y !== missing
            yy = Float64(y)
            if yy > 0
                push!(vals, yy)
            end
        end
    end
    ymax = isempty(vals) ? 1.0 : maximum(vals)

    e1 = floor(Int, log10(y_min))           # <- fixed lower decade at 10^-4
    e2 = ceil(Int,  log10(ymax))
    ticks = 10.0 .^ (e1:e2)
    lims  = (10.0^e1, 10.0^e2)              # <- y-axis starts at 10^-4
    return ticks, lims
end

function add_series_skipmissing!(p, xs, ys; label)
    x = Int[]; y = Float64[]
    for (xi, yi) in zip(xs, ys)
        if yi !== missing
            push!(x, xi); push!(y, Float64(yi))
        end
    end
    plot!(p, x, y; label=label)  # no markers
end

function runtime_plot(xs, rt_wo, rt_w; title="", eps=1e-4, y_min=1e-4)
    rt_wo2 = sanitize_for_log10(rt_wo; eps=eps)
    rt_w2  = sanitize_for_log10(rt_w;  eps=eps)

    yt, yl = decade_ticks_and_lims(rt_wo2, rt_w2; y_min=y_min)

    p = plot(
        xlabel="Maximum number of AST nodes",
        ylabel="Runtime (s)",
        title=title,
        legend=:topleft,
        yscale=:log10,
        yticks=yt,
        ylims=yl,
        xticks=minimum(xs):1:maximum(xs),
        lw=2,
        marker=:none,
        markersize=0,
        # optional: a little x padding so the first/last points aren't glued to the frame
        xlims=(minimum(xs)-0.5, maximum(xs)+0.5),
    )

    add_series_skipmissing!(p, xs, rt_wo2; label="Plain Enumeration")
    add_series_skipmissing!(p, xs, rt_w2;  label="Constrained Enumeration")
    return p
end



# --- make plots ------------------------------------------------------
p_arith  = runtime_plot(arith_size,  arith_rt_wo,  arith_rt_w;  title="Arithmetic Grammar", eps=1e-3)
p_robots = runtime_plot(robots_size, robots_rt_wo, robots_rt_w; title="Robots Grammar",     eps=1e-3)
p_symb   = runtime_plot(symb_size,   symb_rt_wo,   symb_rt_w;   title="Symbolic Grammar",   eps=1e-3)
p_lists  = runtime_plot(lists_size,  lists_rt_wo,  lists_rt_w;  title="Lists Grammar",      eps=1e-3)

p_all = plot(
    p_arith, p_robots, p_symb, p_lists;
    layout = Plots.grid(2, 2, hgap=12, vgap=10),  # increase these numbers
    size   = (900, 650),
)
display(p_all)

# --- save PDFs -------------------------------------------------------
savefig(p_arith,  "runtime_arithmetic.pdf")
savefig(p_robots, "runtime_robots.pdf")
savefig(p_symb,   "runtime_symbolic.pdf")
savefig(p_lists,  "runtime_lists.pdf")
savefig(p_all,    "runtime_all_grammars.pdf")
