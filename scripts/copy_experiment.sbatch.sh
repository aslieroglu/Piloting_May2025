#!/bin/bash
#
# copy_experiment.sbatch.sh
#
# This Slurm batch script will:
#   1) Copy raw experiment data from iRODS to a local scratch (unless skipped)
#   2) Optionally convert DICOM archives to NIfTI (when requested)
#   3) Build a BIDS-like directory structure
#   4) Pull out the UNI and INV2 volumes into your subject/session anat folder
#
# USER INPUT:
#   Edit the hard-coded section below to set:
#     EXPERIMENT_NAME   (no default)
#     EXPERIMENT_TYPE   (mp2rage_seq | real_time | ground_truth)
#     SUBJECT_ID        (e.g. sub-01)
#     SES               (ses-1 or ses-2)
#
# SWITCHES:
#   --skip-copy     Skip the iRODS → local copy step
#   --convert       Enable DICOM → NIfTI conversion
#   --skip-anat     Skip copying UNI & INV2 into the anat folder
#
# USAGE:
#   sbatch copy_experiment.sbatch.sh [--skip-copy] [--convert] [--skip-anat]
#   e.g.
#     sbatch copy_experiment.sbatch.sh --convert
#     sbatch copy_experiment.sbatch.sh --skip-copy --skip-anat
#
#SBATCH --job-name=copy_experiment      # edit if you like
#SBATCH --output=%x_%j.out              # e.g. copy_experiment_12345.out
#SBATCH --error=%x_%j.err               # e.g. copy_experiment_12345.err
#SBATCH --partition=compute             # change to your cluster’s compute partition
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4               # adjust if you parallelize parts
#SBATCH --mem=64G                       # adjust based on data size
#SBATCH --time=02:00:00                 # HH:MM:SS, adjust as needed
#SBATCH --mail-type=END,FAIL            # notify on job end/fail
#SBATCH --mail-user=aeroglu@your.domain # change to your address

set -euo pipefail

# === USER INPUT (hard-code these—no defaults!) ===
EXPERIMENT_NAME="EYMO-62XQ"    # e.g. "MyStudy-123"
EXPERIMENT_TYPE="mp2rage_seq" # Options: mp2rage_seq, real_time, ground_truth
SUBJECT_ID="sub-01"            # e.g. sub-01
SES="ses-1"                    # e.g. ses-1 or ses-2

IRODS_BASE="/home/aeroglu/iRODS/mrdata/echtdata/studies/101/experiments"
DEST_BASE="/ptmp/aeroglu/piloting_May2025"
DEST_RAW="$DEST_BASE/$EXPERIMENT_TYPE/raw_data"
DEST_PROJECT="$DEST_BASE/$EXPERIMENT_TYPE/project"

# === SWITCH DEFAULTS ===
DO_COPY=true
DO_CONVERT=false
DO_ANAT_COPY=true

# === PARSE OPTIONS ===
usage() {
  echo "Usage: $0 [--skip-copy] [--convert] [--skip-anat]"
  echo
  echo "  --skip-copy   : do not copy from iRODS"
  echo "  --convert     : perform DICOM→NIfTI conversion"
  echo "  --skip-anat   : skip copying UNI & INV2"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-copy|--no-copy)
      DO_COPY=false; shift;;
    --convert)
      DO_CONVERT=true; shift;;
    --skip-anat)
      DO_ANAT_COPY=false; shift;;
    -h|--help)
      usage;;
    *)
      echo "ERROR: Unknown option '$1'"
      usage;;
  esac
done

# === STEP 1: COPY RAW DATA ===
if [[ "$DO_COPY" == true ]]; then
  echo "📁 Copying raw data from iRODS for $EXPERIMENT_NAME..."
  mkdir -p "$DEST_RAW/$EXPERIMENT_NAME"
  cp -r "$IRODS_BASE/$EXPERIMENT_NAME/"* "$DEST_RAW/$EXPERIMENT_NAME"
else
  echo "⚠️  Skipping iRODS copy (--skip-copy)"
fi

# === STEP 1.5: OPTIONAL DICOM→NIfTI ===
if [[ "$DO_CONVERT" == true ]]; then
  echo "🔄 Performing DICOM→NIfTI conversion..."
  module load dcm2niix
  NIFTI_OUT="$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI_converted"
  mkdir -p "$NIFTI_OUT"
  for tgz in "$DEST_RAW/$EXPERIMENT_NAME/DICOM_TGZ/"*.tgz; do
    base=$(basename "$tgz" .tgz)
    mkdir -p "$DEST_RAW/$EXPERIMENT_NAME/extracted_dicoms/$base"
    tar -xzf "$tgz" -C "$DEST_RAW/$EXPERIMENT_NAME/extracted_dicoms/$base"
    dcm2niix -z y -o "$NIFTI_OUT" -f "$base" \
      "$DEST_RAW/$EXPERIMENT_NAME/extracted_dicoms/$base"
  done
else
  echo "⚠️  Skipping DICOM→NIfTI conversion (no --convert)"
fi

# === STEP 2: BIDS STRUCTURE ===
echo "🔧 Building BIDS-like directory structure..."
mkdir -p "$DEST_PROJECT/$SUBJECT_ID/ses-1"/{anat,func,fmap}
if [[ "$EXPERIMENT_TYPE" == "real_time" ]]; then
  mkdir -p "$DEST_PROJECT/$SUBJECT_ID/ses-2"/{anat,func,fmap}
fi
echo "$EXPERIMENT_NAME" > "$DEST_PROJECT/$SUBJECT_ID/experiment_name.txt"

# === STEP 3: COPY UNI & INV2 ===
if [[ "$DO_ANAT_COPY" == true ]]; then
  echo "📂 Populating NIfTI files for $SUBJECT_ID / $SES..."
  UNI_NAME="*UNI_Images*"
  INV_NAME="*INV2*"

  # copy UNI
  cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/$UNI_NAME" \
     "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii.gz"
  zcat "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii.gz" \
       > "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii"

  # copy INV2
  cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/$INV_NAME" \
     "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_inv2.nii.gz"
  zcat "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_inv2.nii.gz" \
       > "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_inv2.nii"
else
  echo "⚠️  Skipping UNI & INV2 copy (--skip-anat)"
fi

echo "✅ Subject $SUBJECT_ID set up at: $DEST_PROJECT/$SUBJECT_ID"
