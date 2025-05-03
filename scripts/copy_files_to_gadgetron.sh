#!/bin/bash
#
# ==== SLURM job directives ====
#SBATCH --job-name=rsync_copy        # name of the job
#SBATCH --output=logs/rsync_%j.out   # stdout (%j = jobid)
#SBATCH --error=logs/rsync_%j.err    # stderr
#SBATCH --time=01:00:00              # max walltime (HH:MM:SS)
#SBATCH --ntasks=1                   # run a single task
#SBATCH --cpus-per-task=1            # with one CPU core
#SBATCH --mem=1G                     # and 1 GB RAM

# ==== (Optional) Load any modules you need ====
# module load rsync   # if your cluster provides rsync as a module

export RSYNC_RSH="ssh -i ~/.ssh/id_rsync_meduser"

# ==== Your rsync command ====
LOCAL_DIR="/ptmp/aeroglu/piloting_May2025"
REMOTE_USER="meduser"
REMOTE_HOST=10.41.60.157
REMOTE_DIR="/home/meduser/realTimefMRI"

rsync -avz \
  "$LOCAL_DIR" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

# ==== End of script ====


