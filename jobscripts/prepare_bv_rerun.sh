#!/bin/bash
# Run this once on the login node before (re-)submitting
# sygus_bv2018_{eu,probe}_i{1,2}.sh.
#
# run_probe/run_EUSolver in src/sygus_benchmark.jl checkpoint by `Problem`
# name already present in the results CSV and skip anything found there.
# Since the constrained_space=1 and constrained_space=2 BV constraints
# changed (fixed unsound im_cvc/if0_cvc ordering, added bvadd/bvnot/absorption
# redundancy removal, replaced the ad hoc adjacency forbids with
# ForbiddenSequence + Unique), the old i1/i2 result files for BV no longer
# reflect what add_benchmark_constraints produces. Leaving them in place would
# make a rerun silently report the stale results instead of recomputing them.
# constrained_space=0 is untouched (add_benchmark_constraints adds nothing
# there), so those files are left alone.

set -euo pipefail
cd "$(dirname "$0")/.."

DATA_DIR="data/HerbBenchmarks.PBE_BV_Track_2018"
BACKUP_DIR="data/backup/bv2018_pre_useful_constraints_rerun_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

for f in probe_1 probe_2 EUSolver_1 EUSolver_2; do
    for suffix in "_constraints_results.csv" "_constraints_results_verified.csv"; do
        src="$DATA_DIR/${f}${suffix}"
        if [ -f "$src" ]; then
            mv "$src" "$BACKUP_DIR/"
            echo "Moved $src -> $BACKUP_DIR/"
        fi
    done
done

echo "Done. Old BV constrained_space=1/2 results backed up to $BACKUP_DIR"
echo "Now submit: sbatch jobscripts/slurm/sygus_bv2018_eu_i1.sh"
echo "            sbatch jobscripts/slurm/sygus_bv2018_eu_i2.sh"
echo "            sbatch jobscripts/slurm/sygus_bv2018_probe_i1.sh"
echo "            sbatch jobscripts/slurm/sygus_bv2018_probe_i2.sh"
