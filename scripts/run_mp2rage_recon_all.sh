#!/bin/bash -l

#SBATCH --job-name=mp2rage_recon
#SBATCH --partition=compute
#SBATCH --exclusive=user
#SBATCH --time=12:00:00
#SBATCH --mail-type=FAIL,TIME_LIMIT
#SBATCH --mail-user=your_email@example.com

# Set a custom temporary directory
export TMPDIR=/ptmp/aeroglu/tmp
mkdir -p $TMPDIR

# Define container and script paths
container=/home/rglz/containers/gfae.sif
MINICONDA_PATH=/opt/conda/bin/activate
script_path=/ptmp/aeroglu/piloting_May2025/libs/mp2rage_recon-all/code/mp2rage_recon-all_updated.py

# Log the start time
echo "Starting mp2rage_recon-all job at $(date)"

# Execute the Python script within the container and activate the Conda environment inside it
srun apptainer exec ${container} bash -c "
    source ${MINICONDA_PATH} && 
    python3 ${script_path}
"

# Move SLURM output to a dedicated directory
mkdir -p ${SLURM_SUBMIT_DIR}/SLURM_OUTPUT
mv ${SLURM_SUBMIT_DIR}/*.out ${SLURM_SUBMIT_DIR}/SLURM_OUTPUT/

# Log the end time
echo "Finished mp2rage_recon-all job at $(date)"

# Finish
exit 0

