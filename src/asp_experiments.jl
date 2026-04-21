# asp_experiments.jl
using HerbCore
using HerbSearch: BFSASPIterator
using Clingo_jll

include("_thesis_helpers.jl")
include("_helper_functions.jl")

robots = 1
arithmetic = 2
symbolic = 3
lists = 4
lists_grounded = 5

# const GRAMMARS_4 = (robots, arithmetic, symbolic, lists)
const GRAMMARS_4 = (arithmetic, symbolic, lists)

function maybe_fsync(io::IO)
    Sys.isunix() || return
    try
        ccall(:fsync, Cint, (Cint,), Base.fd(io))
    catch
    end
    return
end


"""
Return the most recent run file for this prefix (highest run counter), or `nothing` if none exists.
Matches filenames created by `get_filename(prefix)`.
"""
function get_last_filename(prefix)::Union{String,Nothing}
    base = "data/" * prefix * "_run"
    count = 0
    while isfile(base * string(count) * ".txt")
        count += 1
    end
    return count == 0 ? nothing : (base * string(count - 1) * ".txt")
end

"""
A run is considered "successful enough to skip" if it has a header + at least 1 data row.
(So header-only files are treated as incomplete and will be resumed.)
"""
function is_successful_results_file(path::AbstractString)::Bool
    isfile(path) || return false
    try
        return countlines(path) > 1
    catch
        return false
    end
end

# Read the largest max_size already present (ignores header/blank lines)
function _last_done_max_size(path::AbstractString)::Int
    isfile(path) || return 0
    maxdone = 0
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        occursin("max_size", s) && continue
        startswith(s, "#") && continue
        fields = split(s, ',')
        ms = tryparse(Int, strip(fields[1]))
        ms === nothing && continue
        maxdone = max(maxdone, ms)
    end
    return maxdone
end

"""
Creates a filename for a new run by incrementing `_run<i>.txt` until it finds a free slot.
(Kept for compatibility.)
"""
function get_filename(prefix)
    name = "data/" * prefix * "_run"
    count = 0
    while isfile(name * string(count) * ".txt")
        count += 1
    end
    return name * string(count) * ".txt"
end

# ----------------------------
# Main experiment
# ----------------------------
function asp_bfs(
    grammartype,
    number_of_constraints::Int = typemax(Int);
    with_constraints::Bool = true,
    MAX_TIME = 600,
    max_size_limit::Int = 100,
    flush_each::Bool = true,
    fsync_each::Bool = false,   # best-effort durability; slower on network FS
)
    @assert grammartype in GRAMMARS_4

    name = "asp_bfs_grammar$(grammartype)"
    if !with_constraints
        name *= "_noconstr"
    end
    if number_of_constraints < typemax(Int)
        name *= "_constraints$(number_of_constraints)"
    end

    # Ensure output dir exists (get_filename/get_last_filename assume "data/")
    outdir = "data"
    isdir(outdir) || mkdir(outdir)

    # Decide which file to write:
    # - If the latest run file exists and already has data -> skip
    # - Else if the latest run file exists but is incomplete (e.g. header only) -> resume (append)
    # - Else create a new run file
    last = get_last_filename(name)

    if last !== nothing && is_successful_results_file(last)
        @info "Skipping $name: last run already has results" file=last
        return
    end

    outpath = if last !== nothing && isfile(last)
        @info "Resuming $name: last run file exists but incomplete" file=last
        last
    else
        newpath = get_filename(name)
        @info "Starting new run file" file=newpath
        newpath
    end

    # Determine resume point inside that chosen file
    file_nonempty = isfile(outpath) && filesize(outpath) > 0
    last_done = file_nonempty ? _last_done_max_size(outpath) : 0
    start_size = last_done + 1

    if start_size > max_size_limit
        @info "Skipping $name: already completed up to max_size=$last_done" file=outpath
        return
    elseif file_nonempty
        @info "Resuming $name from max_size=$start_size (last_done=$last_done)" file=outpath
    end

    open(outpath, file_nonempty ? "a" : "w") do file
        if !file_nonempty
            println(file, "max_size, programs, time")
            flush_each && flush(file)
            fsync_each && maybe_fsync(file)
        end

        for max_size ∈ start_size:max_size_limit
            println("[$name] max_size = $max_size")

            grammar = get_thesis_grammar(grammartype, number_of_constraints)
            if !with_constraints
                clearconstraints!(grammar)
            end

            start = get_starting_symbol(grammartype)
            iter  = BFSASPIterator(grammar, start; max_depth=max_size)

            programs = 0
            t = @elapsed begin
                for _ in iter
                    programs += 1
                end
            end

            println(file, "$max_size, $programs, $t")

            # Persist intermediate results
            flush_each && flush(file)
            fsync_each && maybe_fsync(file)

            if t > MAX_TIME
                @warn "Last experiment took $t seconds"
                break
            end
        end
    end
end

function asp_bfs_all(number_of_constraints::Int = typemax(Int); MAX_TIME = 600)
    for gtype in GRAMMARS_4
        asp_bfs(gtype, number_of_constraints; with_constraints=false, MAX_TIME=MAX_TIME)
        asp_bfs(gtype, number_of_constraints; with_constraints=true,  MAX_TIME=MAX_TIME)
    end
end

asp_bfs_all(MAX_TIME=600)