#!/bin/bash

subject="sub-01" # Enter subject ID
EXPERIMENT_TYPE=real_time #Options: real_time, mp2rage_seq, ground_truth
studyDataDir="/ptmp/aeroglu/piloting_May2025/${EXPERIMENT_TYPE}/project"

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
    3dTcat -prefix scan.nii ${in_file}
    echo "********** run the motion correction script ****************************************"
    ${curDir}/motioncorrect.sh scan.nii
    echo "********** Calculate the mean image of the motion-corrected file ****************************************"
    3dTstat -prefix scan_mc_mean.nii -mean scan_mc.nii

    cd ${cur_dir}
    mv ${tmpdir_mc}/scan_mc_mean.nii ${out_file}
    rm -rf ${tmpdir_mc}
}

import_fs() {
    mri_convert ${fs_dir}/mri/T1.mgz fs_T1.nii
    mri_convert ${fs_dir}/mri/brain.mgz fs_T1_brain.nii
    mri_convert ${fs_dir}/mri/brainmask.mgz fs_brainmask.nii
    mri_convert ${fs_dir}/mri/aseg.mgz aseg.nii
    fslmaths aseg.nii -sub 2 -abs -binv wm_left.nii
    fslmaths aseg.nii -sub 41 -abs -binv wm_right.nii  
    fslmaths wm_left.nii -add wm_right.nii -bin fs_T1_brain_wmseg.nii
    imrm aseg wm_left wm_right
}

import_epi() {
    source_path=$1
    target_basename=$2
    
    mc_and_average_scan ${source_path} ${target_basename}.nii

    json_path=$(dirname ${source_path})/$(basename ${source_path} .nii).json
    cp ${json_path} ${target_basename}.json
}

import_funcmean() {
    source_path=$1
    target_basename=$2
    json_path=$3

    cp ${source_path} ${target_basename}.nii
    cp ${json_path} ${target_basename}.json
}

import_reversePhase() {
    source_path=$1
    target_basename=$2

    mc_and_average_scan ${source_path} ${target_basename}.nii
    json_path=$(dirname ${source_path})/$(basename ${source_path} .nii).json
    cp ${json_path} ${target_basename}.json
}

get_and_prepare_data() {
    echo "***** import_slab *****only first run" 
    import_epi \
        ${studyDataDir}/${subject}/ses-2/func/${subject}_ses-2_task-retrocue_acq-highresslab_run-1_bold.nii \
        slab

    echo "***** import_reversePhase from fmap *****ses-2" 
    import_reversePhase \
        ${studyDataDir}/${subject}/ses-2/fmap/${subject}_ses-2_acq-highresslab_dir-pa_epi.nii \
        slab_dir-pa

    import_fs
}

run_topup_epi() {
    PhaseEncodeOne=$1
    PhaseEncodeTwo=$2

    PhaseEncodeOne_json="${PhaseEncodeOne%_*}.json"
    PhaseEncodeTwo_json="${PhaseEncodeTwo%_*}.json"

    ped_PhaseEncodeOne=$(jq < $PhaseEncodeOne_json '.PhaseEncodingDirection')
    ped_PhaseEncodeTwo=$(jq < $PhaseEncodeTwo_json '.PhaseEncodingDirection')
    ped_PhaseEncodeOne=$(echo $ped_PhaseEncodeOne | tr -d '"')
    ped_PhaseEncodeTwo=$(echo $ped_PhaseEncodeTwo | tr -d '"')      

    fslmaths ${PhaseEncodeOne}.nii -abs -bin -dilD -Tmin ${PhaseEncodeOne}_mask.nii
    fslmaths ${PhaseEncodeTwo}.nii -abs -bin -dilD -Tmin ${PhaseEncodeTwo}_mask.nii

    fslmaths ${PhaseEncodeOne}_mask -mas ${PhaseEncodeTwo}_mask -ero -bin Mask
    fslmerge -t BothPhases ${PhaseEncodeOne} ${PhaseEncodeTwo}
    
    txtfname=acqparams.txt
    if [ -e $txtfname ] ; then
        rm $txtfname
    fi

    etl_PhaseEncodeOne=$(jq < $PhaseEncodeOne_json '.TotalReadoutTime')
    etl_PhaseEncodeTwo=$(jq < $PhaseEncodeTwo_json '.TotalReadoutTime')
    
    echo "0 -1 0 ${etl_PhaseEncodeOne}" > $txtfname
    echo "0 1 0 ${etl_PhaseEncodeTwo}" >> $txtfname

    numslice=`fslval BothPhases dim3`
    if [ ! $(($numslice % 2)) -eq "0" ] ; then
        echo "**** Padding in z by one slice"
        for Image in BothPhases Mask; do
            fslroi ${Image} slice 0 -1 0 -1 0 1 0 -1
            fslmaths slice -mul 0 slice
            fslmerge -z ${Image} ${Image} slice
            imrm slice
        done
    fi
    
    fslmaths BothPhases -abs -add 1 -mas Mask -dilM -dilM -dilM -dilM -dilM BothPhases

    echo "**** running topup"
    topup --imain=BothPhases --datain=$txtfname --config=b02b0.cnf --out=slab_Coefficents --iout=slab_Magnitudes --fout=slab_TopupField --dfout=slab_WarpField --rbmout=slab_MotionMatrix --jacout=slab_Jacobian -v 
    applytopup --imain=${PhaseEncodeOne} --topup=slab_Coefficents --datain=$txtfname --inindex=1 --method=jac --out=${PhaseEncodeOne}_dc
    applytopup --imain=${PhaseEncodeTwo} --topup=slab_Coefficents --datain=$txtfname --inindex=2 --method=jac --out=${PhaseEncodeTwo}_dc
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

reg_slab_to_fullbrain_ses1() {
    flirt -in slab_dc -ref fullbrain_dc \
          -out slab_dc_2_fullbrain_dc \
          -omat slab_dc_2_fullbrain_dc.mat
}

join_all_transforms() {
    echo "***** concatenate affines:fullbrain_ses-1_2_T1 and slab_2_fullbrain_ses-1"
    convert_xfm -omat slab_dc_2_fs_T1.mat \
                -concat \
                fullbrain_dc_epi_reg.mat  \
                slab_dc_2_fullbrain_dc.mat

    echo "***** adding warpfield from topup for slab and concatenated affine from step before"
    convertwarp --premat=slab_MotionMatrix_01.mat \
                --warp1=slab_WarpField_01 \
                --postmat=slab_dc_2_fs_T1.mat \
                --ref=fs_T1 \
                --out=slab_2_fs_T1_warpfield \
                --jacobian=slab_2_fs_T1.jac \
                --relout \
                --rel 

}

convert_to_ants() {

    # convert inverse warp to ants
    wb_command -convert-warpfield \
                 -from-fnirt $(imglob -extension slab_2_fs_T1_warpfield) \
                 slab.nii \
                 -to-itk slab_2_fs_T1_warp_ants.nii.gz
               
    # antsApplyTransforms -i fs_T1.nii \
    #                     -t fs_T1_2_slab_warp_ants.nii.gz \
    #                     -r slab.nii \
    #                     -n 'BSpline[5]' \
    #                     -o fs_t1_in-slab_viaants.nii 

    antsApplyTransforms -i slab.nii \
                        -t slab_2_fs_T1_warp_ants.nii.gz \
                        -r fs_T1.nii \
                        -n 'BSpline[5]' \
                        -o slab_in-fs_t1_viaants.nii 
}


main() {
    curDir=$(pwd)

    echo "********** Make outputdir ****************************************"
    mkdir -p ${ref_anat_dir}
    cd ${ref_anat_dir}

    echo "********** starting get_and_prepare_data ****************************************"
    get_and_prepare_data

    echo "********** starting topup on slab - other sessions ****************************************"
    run_topup_epi slab slab_dir-pa

    echo "********** run flirt slab2fullbrain ****************************************"
    reg_slab_to_fullbrain_ses1 

    echo "********** join all transforms ****************************************"
    join_all_transforms

    echo "********** convert to ants ****************************************"
    convert_to_ants

    cd ${curDir}
}

main
