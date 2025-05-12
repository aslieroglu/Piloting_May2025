#!/bin/bash
#
# copy_experiment.sbatch.sh
#
# This Slurm batch script will:
#   1) Fetch raw experiment data from iRODS via python-irodsclient (unless skipped)
#   2) Optionally convert DICOM archives to NIfTI (when requested)
#   3) Build a BIDS-like directory structure
#   4) Pull out the UNI and INV2 volumes into your subject/session anat folder
#
# USER INPUT (hard-code these—no defaults!):
#   EXPERIMENT_NAME   (e.g. "KSVN-CXXX")
#   EXPERIMENT_TYPE   (mp2rage_seq | real_time | ground_truth)
#   SUBJECT_ID        (e.g. sub-01)
#   SES               (ses-1 or ses-2)
#
# SWITCHES:
#   --skip-copy     Skip the iRODS data fetch
#   --convert       Perform DICOM→NIfTI conversion
#   --skip-anat     Skip copying UNI & INV2
#
# USAGE:
#   sbatch copy_experiment.sbatch.sh [--skip-copy] [--convert] [--skip-anat]
#
#SBATCH --job-name=copy_experiment
#SBATCH --output=SLURM_OUTPUT/%x_%j.out
#SBATCH --error=SLURM_OUTPUT/%x_%j.err
#SBATCH --partition=compute
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=02:00:00

set -euo pipefail

CONTAINER="/home/rglz/containers/gfae.sif"
BIND="$HOME:$HOME"

# ─── Activate iRODS client env ───
source "$HOME/irods-env/bin/activate"

# ─── iRODS connection parameters ───
export IRODS_HOST="irods.mrdata.kyb.local"
export IRODS_PORT=1247
export IRODS_USER_NAME="aeroglu"
export IRODS_ZONE_NAME="MRDataZone"
export IRODS_PASSWORD="MDYxOTQxOGY2ZDY5YzY0MzFiOWYyNTRm"

# === USER INPUT ===
export EXPERIMENT_NAME="EYMO-62XQ"
export EXPERIMENT_TYPE="mp2rage_seq" # options are real_time, gorund_truth, mp2rage_seq
export SUBJECT_ID="sub-01"
export SES="ses-1"

export DEST_BASE="/ptmp/aeroglu/piloting_May2025"
export DEST_RAW="$DEST_BASE/$EXPERIMENT_TYPE/raw_data"
export DEST_PROJECT="$DEST_BASE/$EXPERIMENT_TYPE/project"

# === SWITCH DEFAULTS ===
DO_COPY=true
DO_CONVERT=false
DO_ANAT_COPY=true

# === PARSE OPTIONS ===
usage(){
  echo "Usage: $0 [--skip-copy] [--convert] [--skip-anat]"
  exit 1
}
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-copy)  DO_COPY=false; shift;;
    --convert)    DO_CONVERT=true;  shift;;
    --skip-anat)  DO_ANAT_COPY=false;shift;;
    -h|--help)    usage;;
    *)            echo "Unknown option $1"; usage;;
  esac
done

# === STEP 1: FETCH RAW DATA via python-irodsclient ===
if [[ "$DO_COPY" == true ]]; then
  echo "📁 Fetching raw data from iRODS for $EXPERIMENT_NAME via python-irodsclient…"
  mkdir -p "$DEST_RAW/$EXPERIMENT_NAME"

  singularity exec \
    "$CONTAINER" \
    bash -lc '
      # inside the container now
      source "$HOME/irods-env/bin/activate"
      python3 - << "PYCODE"
import os
from irods.session import iRODSSession

exp = os.environ["EXPERIMENT_NAME"]
dst = os.path.join(os.environ["DEST_RAW"], exp)
coll_path = f"/mrdata/echtdata/studies/101/experiments/{exp}"

# gather connection info from environment
host = os.environ["IRODS_HOST"]
port = int(os.environ["IRODS_PORT"])
user = os.environ["IRODS_USER_NAME"]
password = os.environ["IRODS_PASSWORD"]
zone = os.environ["IRODS_ZONE_NAME"]

# explicitly construct the session
sess = iRODSSession(
    irods_host=host,
    irods_port=port,
    irods_user_name=user,
    irods_password=password,
    irods_zone_name=zone,
)

def fetch_collection(c, local_dir):
    for d in c.data_objects:
        print("→ Fetching", d.path)
        sess.data_objects.get(d.path, local_dir)
    for sub in c.subcollections:
        sub_local = os.path.join(local_dir, os.path.basename(sub.path))
        os.makedirs(sub_local, exist_ok=True)
        fetch_collection(sub, sub_local)

root = sess.collections.get(coll_path)
fetch_collection(root, dst)
PYCODE
    '
else
  echo "⚠️  Skipping data fetch (--skip-copy)"
fi

# === STEP 1.5: OPTIONAL DICOM→NIfTI ===
if [[ "$DO_CONVERT" == true ]]; then
  echo "🔄 Converting DICOM→NIfTI…"
  # adjust if dcm2niix is also in your container or module
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
  echo "⚠️  Skipping DICOM→NIfTI conversion"
fi

# === STEP 2: BIDS STRUCTURE ===
echo "🔧 Building BIDS-like directory structure…"
mkdir -p "$DEST_PROJECT/$SUBJECT_ID/ses-1"/{anat,func,fmap}
if [[ "$EXPERIMENT_TYPE" == "real_time" ]]; then
  mkdir -p "$DEST_PROJECT/$SUBJECT_ID/ses-2"/{anat,func,fmap}
fi
echo "$EXPERIMENT_NAME" > "$DEST_PROJECT/$SUBJECT_ID/experiment_name.txt"

# === STEP 3: COPY UNI & INV2 ===
if [[ "$DO_ANAT_COPY" == true ]]; then
  echo "📂 Populating UNI & INV2 for $SUBJECT_ID / $SES…"
  UNI_GLOB="*UNI_Images*"
  INV_GLOB="*INV2*"

  cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/$UNI_GLOB" \
     "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii.gz"
  zcat "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii.gz" \
       > "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii"

  cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/$INV_GLOB" \
     "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_inv2.nii.gz"
  zcat "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_inv2.nii.gz" \
       > "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_inv2.nii"
else
  echo "⚠️  Skipping UNI & INV2 copy (--skip-anat)"
fi

echo "✅ Done! Subject $SUBJECT_ID available at $DEST_PROJECT/$SUBJECT_ID"
