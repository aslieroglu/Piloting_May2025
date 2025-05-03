#!/bin/bash
subject="sub-01" # Enter subject ID
EXPERIMENT_TYPE=real_time #Options: real_time, mp2rage_seq, ground_truth
studyDataDir="/ptmp/aeroglu/piloting_May2025/${EXPERIMENT_TYPE}/project"

fulbrain_epi_location="${studyDataDir}/${subject}/ses-1/anat/${subject}_ses-1_acq-highresfullepi_T2starw.nii"
fullbrain_reverse_epi_location="${studyDataDir}/${subject}/ses-1/fmap/${subject}_ses-1_acq-highresfull_dir-pa_epi.nii"

curDir=$(pwd)

ref_anat_dir=${studyDataDir}/derivatives/ref_anat/${subject}
fs_dir=${studyDataDir}/derivatives/mprage_recon-all/${subject}/freesurfer

mc_and_average_scan() {
    in_file=$1
    out_file=$2

    tmpdir_mc=$(mktemp -d)
    cur_dir=$(pwd)
    cd ${tmpdir_mc}

    echo "********** Concatenate the input file ****************************************"
    # Concatenate the input file
    3dTcat -prefix scan.nii ${in_file}
    echo "********** run the motion correction script ****************************************"
    # Run the motion correction script
    ${curDir}/motioncorrect.sh scan.nii
    echo "********** Calculate the mean image of the motion-corrected file ****************************************"
    # Calculate the mean image of the motion-corrected file
    3dTstat -prefix scan_mc_mean.nii -mean scan_mc.nii

    # Return to the original directory
    cd ${cur_dir}

    # Move the result to the specified output file
    mv ${tmpdir_mc}/scan_mc_mean.nii ${out_file}
    # Clean up the temporary directory
    rm -rf ${tmpdir_mc}
}

import_fs() {
    # fs T1, brain, brainmask, aseg - assume already gradient distortion corrected
    mri_convert ${fs_dir}/mri/T1.mgz fs_T1.nii
    mri_convert ${fs_dir}/mri/brain.mgz fs_T1_brain.nii
    mri_convert ${fs_dir}/mri/brainmask.mgz fs_brainmask.nii
    mri_convert ${fs_dir}/mri/aseg.mgz aseg.nii
    fslmaths aseg.nii -sub  2 -abs -binv wm_left.nii
    fslmaths aseg.nii -sub 41 -abs -binv wm_right.nii  
    fslmaths wm_left.nii -add wm_right.nii -bin fs_T1_brain_wmseg.nii
    imrm aseg
    imrm wm_left
    imrm wm_right
}

import_epi() {
    source_path=$1
    target_basename=$2
    
    mc_and_average_scan ${source_path} ${target_basename}.nii
    # GDC removed here
    # gdc ${target_basename}.nii ${target_basename}_gdc

    json_path=$(dirname ${source_path})/$(basename ${source_path} .nii).json
    cp ${json_path} ${target_basename}.json
}

import_funcmean() {
    source_path=$1
    target_basename=$2
    json_path=$3

    cp ${source_path} ${target_basename}.nii
    # GDC removed here
    # gdc ${target_basename}.nii ${target_basename}_gdc

    cp ${json_path} ${target_basename}.json
}

import_reversePhase() {
    source_path=$1
    target_basename=$2

    mc_and_average_scan ${source_path} ${target_basename}.nii
    # GDC removed here
    # gdc ${target_basename}.nii ${target_basename}_gdc
    json_path=$(dirname ${source_path})/$(basename ${source_path} .nii).json
    cp ${json_path} ${target_basename}.json
}

run_epi_reg() {
    epi_base_dc=$1

    epi_reg --epi=${epi_base_dc} \
            --t1=fs_T1 \
            --t1brain=fs_T1_brain \
            --out=${epi_base_dc}_epi_reg \
            --wmseg=fs_T1_brain_wmseg \
            -v
}

get_and_prepare_data() {
    # get all needed data
    echo "***** import_fullBrain *****" 
    import_epi \
        ${fulbrain_epi_location} \
        fullbrain

    echo "***** import_reversePhase from fullBrain *****" 
    import_reversePhase \
        ${fullbrain_reverse_epi_location}\
        fullbrain_dir-pa

    # Import from FreeSurfer
    import_fs
}

run_topup_epi() {
    PhaseEncodeOne=$1
    PhaseEncodeTwo=$2

    fslmaths ${PhaseEncodeOne}.nii -abs -bin -dilD -Tmin ${PhaseEncodeOne}_mask.nii
    fslmaths ${PhaseEncodeTwo}.nii -abs -bin -dilD -Tmin ${PhaseEncodeTwo}_mask.nii

    fslmaths ${PhaseEncodeOne}_mask -mas ${PhaseEncodeTwo}_mask -ero -bin Mask
    
    fslmerge -t BothPhases ${PhaseEncodeOne} ${PhaseEncodeTwo}
    
    txtfname=acqparams.txt
    if [ -e $txtfname ] ; then
        rm $txtfname
    fi

    etl_PhaseEncodeOne=$(jq < "${PhaseEncodeOne%_*}.json" '.TotalReadoutTime')
    etl_PhaseEncodeTwo=$(jq < "${PhaseEncodeTwo%_*}.json" '.TotalReadoutTime')
    
    echo "0 -1 0 ${etl_PhaseEncodeOne}" > $txtfname
    echo "0 1 0 ${etl_PhaseEncodeTwo}" >> $txtfname

    echo "**** running topup"
    topup --imain=BothPhases --datain=$txtfname --config=b02b0.cnf --out=epi_Coefficents --iout=epi_Magnitudes --fout=epi_TopupField --dfout=epi_WarpField --rbmout=epi_MotionMatrix --jacout=epi_Jacobian -v
    applytopup --imain=${PhaseEncodeOne} --topup=epi_Coefficents --datain=$txtfname --inindex=1 --method=jac --out=${PhaseEncodeOne}_dc
    applytopup --imain=${PhaseEncodeTwo} --topup=epi_Coefficents --datain=$txtfname --inindex=2 --method=jac --out=${PhaseEncodeTwo}_dc
}

main() {
    mkdir -p ${ref_anat_dir}
    cd ${ref_anat_dir}

    echo "********** starting get_and_prepare_data ****************************************"
    get_and_prepare_data
    echo "********** starting to run topup ****************************************"
    run_topup_epi fullbrain fullbrain_dir-pa
    echo "********** starting epi reg ****************************************"
    run_epi_reg fullbrain_dc

    cd ${curDir}
}

main
