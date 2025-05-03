import sys
sys.path.append('/ptmp/aeroglu/fmri-analysis/library')
from layer_analysis import surftransform_fs
import os
import SimpleITK as sitk

# ----- Input Arguments -----
# sub = sys.argv[1]
# ses = sys.argv[2]
seq = "3dbssfp"  # fixed for bssfp

# ----- Directory Setup -----
fs_dir = "/ptmp/aeroglu/derivatives_pilot_sub-2/mprage_recon-all/sub-02/freesurfer"
output_dir = "/ptmp/aeroglu/data/20240806.aardvark_sfassnacht.24.08.06_15_39_55_DST_1.3.12.2.1107.5.2.0.18951/analysis_s015/ref_anat"
volume = "/ptmp/aeroglu/data/20240806.aardvark_sfassnacht.24.08.06_15_39_55_DST_1.3.12.2.1107.5.2.0.18951/anaylsis_s015/s015_bssfp_mean.nii"

os.makedirs(output_dir, exist_ok=True)

# ----- Affine Transformation (Slab to Anatomical) -----
transmat =  "/ptmp/aeroglu/data/20240806.aardvark_sfassnacht.24.08.06_15_39_55_DST_1.3.12.2.1107.5.2.0.18951/analysis_s015/s015_func2ana_finest1.txt"



def fs_surface_to_func(fs_to_func_reg, fs_dir, analysis_dir=None, force=True):
    """
    Transforms freesurfer surfaces to functional space using ANTs transfrom.
    :param fs_to_func_reg:
    :param fs_dir:
    :param analysis_dir:
    :param force:
    :return:
    """
    if analysis_dir is None:
        analysis_dir = os.path.join(fs_dir, "surf")
    transform_0_lin = fs_to_func_reg
    print("transform_0_lin:", transform_0_lin, "Type:", type(transform_0_lin))
    #transform_1_inversewarp = fs_to_func_reg[3]
    invert_transform_flags = [False]
    surf_trans_files = dict()
    for hemi in ["lh", "rh"]:
        for surf_type in ["white", "pial"]:
            surf = os.path.join(fs_dir, "surf", hemi + "." + surf_type)
            surf_trans = os.path.join(analysis_dir, hemi + "." + surf_type + "_func")
            if not os.path.isfile(surf_trans) or force:
                surf_trans_files[hemi, surf_type] = surftransform_fs(
                    surf,
                    [transform_0_lin],
                    invert_transform_flags,
                    out_file=surf_trans,
                )
            else:
                surf_trans_files[hemi, surf_type] = surf_trans
    return surf_trans_files

# ----- Run surface transformation -----
fs_surface_to_func(fs_to_func_reg  = transmat, analysis_dir=output_dir, fs_dir=fs_dir)

print("Surface-to-functional transformation for bSSFP completed.")