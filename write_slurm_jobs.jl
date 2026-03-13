# write_slurm_jobs.jl
import Base.Filesystem: mkpath

const OUTDIR = joinpath("jobscripts", "slurm")
const LOGDIR = joinpath("jobscripts", "logs")

const PARTITION   = "compute-p1"
const DEFAULT_TIME = "24:00:00"
const BV_TIME      = "48:00:00"
const CPUS        = 8
const MEM_PER_CPU = "2G"  # => 16G total for 8 CPUs

mkpath(OUTDIR)
mkpath(LOGDIR)

function write_job(path::String, jobname::String, cmd::String; time::String=DEFAULT_TIME)
    open(path, "w") do io
        print(io, """
        #!/bin/bash
        #SBATCH --job-name=$jobname
        #SBATCH --partition=$PARTITION
        #SBATCH --time=$time
        #SBATCH --ntasks=1
        #SBATCH --cpus-per-task=$CPUS
        #SBATCH --mem-per-cpu=$MEM_PER_CPU
        #SBATCH --output=$LOGDIR/%x_%j.out
        #SBATCH --error=$LOGDIR/%x_%j.err

        set -euo pipefail
        mkdir -p $LOGDIR

        module load julia

        export JULIA_NUM_THREADS="\${SLURM_CPUS_PER_TASK:-$CPUS}"

        echo "Job: \$SLURM_JOB_ID on \$(hostname)"
        echo "Start: \$(date)"

        $cmd

        echo "End: \$(date)"
        """)
    end
    run(`chmod +x $path`)
end

# --- 1) Plain scripts ---
write_job(joinpath(OUTDIR, "experiments.sh"),
          "cp4ps_experiments",
          """julia --project=. --threads "\$JULIA_NUM_THREADS" src/experiments.jl""")

write_job(joinpath(OUTDIR, "asp_experiments.sh"),
          "cp4ps_asp",
          """julia --project=. --threads "\$JULIA_NUM_THREADS" src/asp_experiments.jl""")

# --- 2) SyGuS scripts: (EU/PROBE) × (BV2018/SLIA2019) × i=0..2 ---
benchmarks = [
    ("BV2018",   "sygus_bv2018"),
    ("SLIA2019", "sygus_slia2019"),
]

modes = [
    ("EU",    "eu"),
    ("PROBE", "probe"),
]

for (bench_arg, bench_tag) in benchmarks
    for (mode_arg, mode_tag) in modes
        for i in 0:2
            jobname = "$(bench_tag)_$(mode_tag)_i$(i)"
            path    = joinpath(OUTDIR, "$(jobname).sh")
            cmd     = """julia --project=. --threads "\$JULIA_NUM_THREADS" src/sygus_benchmark.jl $mode_arg $bench_arg $i"""

            job_time = bench_arg == "BV2018" ? BV_TIME : DEFAULT_TIME

            write_job(path, jobname, cmd; time=job_time)
        end
    end
end

println("Wrote job scripts to: $OUTDIR/")
println("Logs will go to: $LOGDIR/")
println("Submit one: sbatch jobscripts/slurm/experiments.sh")
println("Submit all: sbatch jobscripts/slurm/*.sh")