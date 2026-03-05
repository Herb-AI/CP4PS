#!/bin/bash
#SBATCH --job-name=sygus_bv2018_eu_i0
#SBATCH --partition=compute-p1
#SBATCH --time=24:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=2G
#SBATCH --output=jobscripts/logs/%x_%j.out
#SBATCH --error=jobscripts/logs/%x_%j.err

set -euo pipefail
mkdir -p jobscripts/logs

module load julia

export JULIA_NUM_THREADS="${SLURM_CPUS_PER_TASK:-8}"

echo "Job: $SLURM_JOB_ID on $(hostname)"
echo "Start: $(date)"

julia --project=. --threads "$JULIA_NUM_THREADS" src/sygus_benchmark.jl EU BV2018 0

echo "End: $(date)"
