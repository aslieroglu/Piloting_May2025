# README

## Overview

This repository includes scripts for preparing and processing 9.4T MRI data in a BIDS-like structure on the `nyx` cluster. It supports copying raw data from iRODS, organizing it, and running a custom MP2RAGE reconstruction pipeline.

---

## 1. `copy_experiment.sbatch.sh`

### Purpose

- Copies raw MRI data from iRODS to the cluster
- Organizes it into a BIDS-like folder structure under `project/`
- Optionally extracts and converts DICOMs to NIfTI (disabled by default)
- Assigns subjects as `sub-01`, `sub-02`, etc., and avoids overwriting
- Stores the original experiment name in a `.txt` file

### Usage

1. - Update:

EXPERIMENT_NAME
EXPERIMENT_TYPE (Options are mp2rage_seq, real_time, ground_truth)
SUBJECT_ID
SES

IRODS_BASE
DEST_RAW
DEST_PROJECT

2. Run the script:

bash
./setup_subject_project.sh


## 2. `run_mp2rage_recon_all.sh`

### Purpose

- Runs mp2rage_recon-all_updated.py (MP2RAGE recon all)
- Uses Apptainer to launch a containerized environment
- Saves output in the anat/ folder of the BIDS structure

### Requirements
- inv2 file (obtained by splitting *_img.nii using fslsplit. note that it should be in .nii format)
- uni image
- Valid paths for container, Conda, and script

### Usage
- Update:

- EXPERIMENT_TYPE (Options are mp2rage_seq, real_time, ground_truth)
- SUBJECT_ID
- SES
- inv2_file
- uni_file


- Submit the script:
sbatch run_mp2rage_recon_all.sh


## 3. `copy_files_to_gadgetron.sh`
### Purpose
Copy the project folders to Gadgetron, so that we can continue with 2nd session analysis
rsync only transfers differences, can compress data in transit, and can resume interrupted copies

### Usage

- Edit:
LOCAL_DIR
REMOTE_USER
REMOTE_HOST
REMOTE_DIR


- Submit the script:
sbatch copy_files_to_gadgetron.sh
