# conda activate /ptmp/aeroglu/python_envs/finn_env --> nyx

import os, sys
import nibabel as nib
import numpy as np
from layer_analysis import fs_surface_to_func

# 1. Get the absolute path to the directory containing this script
current_dir = os.path.dirname(os.path.abspath(__file__))

# 2. Go up one level to the project root
project_root = os.path.dirname(current_dir)

# 3. Build the path to your libs folder
libs_dir = os.path.join(project_root, 'libs')

# 4. Insert it at the front of sys.path so Python will look there first
sys.path.insert(0, libs_dir)

# 5. Now you can import your vdfs package
import vdfs.voxeldepths_from_surfaces as vdfs

sub_id="sub-03"

transforms=[os.path.join(
    project_root,
    "real_time",
    "project",
    "derivatives",
    "ref_anat",
    sub_id,
    "slab_2_fs_T1_warp_ants.nii.gz"
)]

fs_dir = os.path.join(
    project_root,
    "real_time",
    "project",
    "derivatives",
    "mprage_recon-all",
    sub_id,
    sub_id,
    "freesurfer"
)
print(fs_dir)

fs_surface_to_func(transforms, fs_dir, analysis_dir=None, is_inverse_transform_flags=[True], force=False)

surf_dir=os.path.join(
    fs_dir,
    "surf"
)
print(surf_dir)
### Left hemi surfaces

surf_white_lh_file=os.path.join(
    surf_dir,
    "lh.white"
)

area_white_lh_file=os.path.join(
    surf_dir,
    "lh.area"
)

surf_pial_lh_file=os.path.join(
    surf_dir,
    "lh.pial"
)

area_pial_lh_file=os.path.join(
    surf_dir,
    "lh.area.pial"
)


### Right hemi surfaces

surf_white_rh_file=os.path.join(
    surf_dir,
    "rh.white"
)

area_white_rh_file=os.path.join(
    surf_dir,
    "rh.area"
)

surf_pial_rh_file=os.path.join(
    surf_dir,
    "rh.pial"
)

area_pial_rh_file=os.path.join(
    surf_dir,
    "rh.area.pial"
)

volume_file="" #2nd session slab
depths_fname="depth_data"
columns_fname="column_data"

vdfs.process_voxeldepth_from_surfaces(surf_white_lh_file,area_white_lh_file,
                                      surf_pial_lh_file,area_pial_lh_file,
                                      surf_white_rh_file,area_white_rh_file,
                                      surf_pial_rh_file,area_pial_rh_file,
                                      volume_file,
                                      depths_fname,columns_fname,
                                      label_lh_fname=None,label_rh_fname=None,
                                      method='equivol',
                                      upsample_factor=None,n_jobs=32,force=False)


depth_nii = nib.load('depths.nii')
mask_data = np.logical_and(depth_data < 2/3, depth_data > 1/3)

## Convert to binary mask
# 1. Load your existing mask
mask_nii = nib.load('mask.nii.gz')

# 2. Extract the data array and threshold it
mask_data = mask_nii.get_fdata()
binary_data = (mask_data > 0).astype(np.uint8)

# 3. Create a new NIfTI image, preserving affine & header
binary_nii = nib.Nifti1Image(binary_data, mask_nii.affine, mask_nii.header)

# 4. Save it out
nib.save(binary_nii, 'mask_binary.nii.gz')