import os
import shutil
import subprocess
import nibabel as nib
import numpy as np
from nipype.interfaces.freesurfer import ApplyVolTransform, ApplyMask
import sys
import anatomy




EXPERIMENT_TYPE="real_time" # Options are: mp2rage_seq, real_time, ground_truth 
SUBJECT_ID="sub-01"
SES="ses-1" #also might be ses-2 for real time

inv2_file=f"/ptmp/aeroglu/piloting_May2025/{EXPERIMENT_TYPE}/project/{SUBJECT_ID}/{SES}/anat/{SUBJECT_ID}_{SES}_inv2.nii"
uni_file=f"/ptmp/aeroglu/piloting_May2025/{EXPERIMENT_TYPE}/project/{SUBJECT_ID}/{SES}/anat/{SUBJECT_ID}_{SES}_uni.nii.gz"

anatomy.mp2rage_recon_all_updated(
    inv2_file=inv2_file,
    uni_file=uni_file,
    subject_name=SUBJECT_ID,
    output_fs_dir=f'/ptmp/aeroglu/piloting_May2025/real_time/project/derivatives/mprage_recon-all/{SUBJECT_ID}'
)