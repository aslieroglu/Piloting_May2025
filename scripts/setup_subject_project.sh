#!/bin/bash

# === USER INPUT ===
EXPERIMENT_NAME="GXYA-JG6W"  # CHANGE
EXPERIMENT_TYPE="real_time" # Options are: mp2rage_seq, real_time, ground_truth 
SUBJECT_ID="sub-01"
SES="ses-1" #also might be ses-2 for real time

IRODS_BASE="/home/aeroglu/iRODS/mrdata/echtdata/studies/102/experiments"
DEST_RAW="/ptmp/aeroglu/piloting_May2025/$EXPERIMENT_TYPE/raw_data"
DEST_PROJECT="/ptmp/aeroglu/piloting_May2025/$EXPERIMENT_TYPE/project"


# === Step 1: Copy from iRODS to raw_data ===
echo "📁 Copying raw data from iRODS..."
mkdir -p "$DEST_RAW/$EXPERIMENT_NAME"
cp -r "$IRODS_BASE/$EXPERIMENT_NAME/"* "$DEST_RAW/$EXPERIMENT_NAME"

# === Step 1.5: (optional) Extract and convert DICOMs ===
# define your new NIfTI output dir
NIFTI_OUT="$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI_converted"
mkdir -p "$NIFTI_OUT"

echo " Extracting and converting DICOMs..."

for tgz in "$DEST_RAW/$EXPERIMENT_NAME/DICOM_TGZ/"*.tgz; do
    base=$(basename "$tgz" .tgz)
    # extract under extracted_dicoms/<base>
    mkdir -p "$DEST_RAW/$EXPERIMENT_NAME/extracted_dicoms/$base"
    tar -xzf "$tgz" -C "$DEST_RAW/$EXPERIMENT_NAME/extracted_dicoms/$base"

    # convert into your custom NIfTI folder
    dcm2niix -z y \
      -o "$NIFTI_OUT" \
      -f "$base" \
      "$DEST_RAW/$EXPERIMENT_NAME/extracted_dicoms/$base"
done

# === Step 2: Create BIDS-like project structure with ses-1 ===
# echo "Creating BIDS-like structure for $SUBJECT_ID..."

# always make session-1…
mkdir -p "$DEST_PROJECT/$SUBJECT_ID/ses-1"/{anat,func,fmap}
# …but only make session-2 if this is a real_time experiment
if [ "$EXPERIMENT_TYPE" = "real_time" ]; then
  mkdir -p "$DEST_PROJECT/$SUBJECT_ID/ses-2{anat,func,fmap}"
fi


# Save experiment name for traceability
echo "$EXPERIMENT_NAME" > "$DEST_PROJECT/$SUBJECT_ID/experiment_name.txt"

# === Step 3: Populate BIDS-like folders for ses-1 ===
# If there is no DICOM_NIFTI yet, use NIFTI_OUT="$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI_converted" folder.
# need to be modified 
# Only thing that does matter here to get inv2 and uni. 


UNI_NAME="152_db_MP2RAGE_0p75_UP_sag_2x2d1_MP2RAGE.nii" # CHANGE
INV_NAME="152_db_MP2RAGE_0p75_UP_sag_2x2d1_img.nii"  # CHANGE


cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/$UNI_NAME" \
   "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii.gz"
#zcat "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii.gz" > "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_uni.nii"


cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/$INV_NAME" \
   "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_invs.nii.gz"
#zcat "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_invs.nii.gz" > "$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_invs.nii"



## get inv2

# path to your 4D INV file
INV4D="$DEST_PROJECT/$SUBJECT_ID/$SES/anat/${SUBJECT_ID}_${SES}_invs.nii.gz"
cd "$DEST_PROJECT/$SUBJECT_ID/$SES/anat"

# split into volumes inv0000.nii.gz, inv0001.nii.gz, … in the same folder
fslsplit "$INV4D" "inv" -t

# rename the first two volumes there
mv "inv0000.nii.gz" "${SUBJECT_ID}_${SES}_inv1.nii.gz"
mv "inv0001.nii.gz" "${SUBJECT_ID}_${SES}_inv2.nii.gz"

gunzip -f "${SUBJECT_ID}_${SES}_inv2.nii.gz"
gunzip -f "${SUBJECT_ID}_${SES}_inv1.nii.gz"

# cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/"*bold_2000*.nii.gz \
#    "$DEST_PROJECT/$SUBJECT_ID/ses-1/func/${SUBJECT_ID}_ses-1_task-rest_bold.nii.gz"

# cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/"*bold_800*.nii.gz \
#    "$DEST_PROJECT/$SUBJECT_ID/ses-1/func/${SUBJECT_ID}_ses-1_task-fast_bold.nii.gz"

# cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/"*B0Mapping*.nii.gz \
#    "$DEST_PROJECT/$SUBJECT_ID/ses-1/fmap/${SUBJECT_ID}_ses-1_magnitude.nii.gz"

# cp "$DEST_RAW/$EXPERIMENT_NAME/DICOM_NIFTI/"*B0_Map*.nii.gz \
#    "$DEST_PROJECT/$SUBJECT_ID/ses-1/fmap/${SUBJECT_ID}_ses-1_phasediff.nii.gz"

echo "Subject $SUBJECT_ID set up at: $DEST_PROJECT/$SUBJECT_ID"


