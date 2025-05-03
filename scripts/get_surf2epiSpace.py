import sys
import os
import numpy as np
import matplotlib.pyplot as plt

# Add library path
sys.path.append("/ptmp/aeroglu/fmri-analysis/library/")
import layer_analysis as analysis
import voxeldepths_from_surfaces as vdfs

# conda activate /ptmp/aeroglu/python_envs/finn_env

# =============================================================================
# Constants and configuration
# =============================================================================
FS_LICENSE_PATH = "/ptmp/aeroglu/license.txt"
FS_DIR = "/ptmp/aeroglu/derivatives_pilot_sub-2/mprage_recon-all/sub-02/freesurfer"
DATA_DIR = "/ptmp/aeroglu/data/20240806.aardvark_sfassnacht.24.08.06_15_39_55_DST_1.3.12.2.1107.5.2.0.18951"

# Set environment variable
os.environ["FS_LICENSE"] = FS_LICENSE_PATH

# =============================================================================
# Helper functions
# =============================================================================
def get_analysis_params(analysis_dir: str, data_dir: str):
    """
    Returns the reference anatomical directory, analysis identifier, and a list 
    containing the path to the tstat file based on the analysis folder and modality.

    Expected analysis_dir names:
      "analysis_s004", "analysis_s014", "analysis_s015", "analysis_s016", "analysis_s017"

    Mapping:
      - analysis_s004 and analysis_s017: modality bold
      - analysis_s014 and analysis_s015: modality bssfp
      - analysis_s016: modality vaso
    """
    # Construct the reference anatomical directory path
    ref_anat_dir = os.path.join(data_dir, analysis_dir, 'ref_anat')
    analysis_short = analysis_dir

    # Extract the analysis number from the analysis directory name (e.g., "s004")
    analysis_number = analysis_dir.split('_')[-1]

    # Determine the modality based on analysis number; combine bold cases
    if analysis_number in ['s004', 's017']:
        modality = 'bold'
    elif analysis_number in ['s014', 's015']:
        modality = 'bssfp'
    elif analysis_number == 's016':
        modality = 'vaso'
    else:
        raise ValueError(f"Unknown analysis number: {analysis_number}")

    # Construct the tstat filename and full path
    tstat_filename = f"{analysis_number}_{modality}_tstat.nii"
    data_list = [os.path.join(data_dir, analysis_dir, tstat_filename)]
    
    return ref_anat_dir, analysis_short, data_list

def get_fs_to_func_reg(ref_anat_dir: str):
    """
    Constructs and returns the list of file paths for freesurfer to functional
    registration.
    """
    filenames = [
        "fs_t1_in-func.nii", #t1w --> fix
        "fs_to_func_0GenericAffine.mat",
        "fs_to_func_1Warp.nii.gz",
        "fs_to_func_1InverseWarp.nii.gz",
    ]
    return [os.path.join(ref_anat_dir, fname) for fname in filenames]

def get_area_files(fs_dir: str):
    """
    Returns a dictionary mapping hemisphere and surface type to their respective
    area file paths.
    """
    return {
        ("lh", "white"): os.path.join(fs_dir, "surf", "lh.area"),
        ("rh", "white"): os.path.join(fs_dir, "surf", "rh.area"),
        ("lh", "pial"): os.path.join(fs_dir, "surf", "lh.area.pial"),
        ("rh", "pial"): os.path.join(fs_dir, "surf", "rh.area.pial")
    }

def process_vdfs(ref_anat_dir: str, fs_dir: str, area_files: dict, methods=["equivol", "equidist"], n_jobs=8):
    """
    Processes voxel depths from surfaces for each method.
    """
    for method in methods:
        vdfs.process_dc_voxeldepth_from_surfaces(
            os.path.join(ref_anat_dir, "lh.white_converted.transformed.gii"),
            area_files[("lh", "white")],
            os.path.join(ref_anat_dir, "lh.pial_converted.transformed.gii"),
            area_files[("lh", "pial")],
            os.path.join(ref_anat_dir, "rh.white_converted.transformed.gii"),
            area_files[("rh", "white")],
            os.path.join(ref_anat_dir, "rh.pial_converted.transformed.gii"),
            area_files[("rh", "pial")],
            os.path.join(ref_anat_dir, "fs_t1_in-func.nii"),
            os.path.join(ref_anat_dir, f"vdfs_depths_{method}.nii"),
            os.path.join(ref_anat_dir, f"vdfs_columns_{method}.nii"),
            method=method,
            upsample_factor=None,
            n_jobs=n_jobs,
            force=True,
        )

def plot_and_save_profiles(data_list, roi_path, depths, ref_anat_dir, filename, n_profiles=12):
    """
    Plots the profiles and saves the figure to a file.
    """
    analysis.plot_profiles(data_list, roi_path, depths, n_profiles, colors=None, labels=None)
    output_path = os.path.join(ref_anat_dir, filename)
    plt.savefig(output_path)
    plt.clf()

# =============================================================================
# Main processing function
# =============================================================================
def main():
    # Analysis list: update or extend as needed
    #analysis_list = ["analysis_s004", "analysis_s014", "analysis_s015", "analysis_s016", "analysis_s017"]
    analysis_list = ["analysis_s016"]

    # For now, you might only run one modality (e.g., vaso for analysis_s016),
    # but the code supports multiple modalities.
    
    area_files = get_area_files(FS_DIR)
    
    for analysis_dir in analysis_list:
        # Get the parameters for this analysis directory
        ref_anat_dir, analysis_short, data_list = get_analysis_params(analysis_dir, DATA_DIR)
        
        # ---------------------------------------------------------------------
        # # 2. Transform freesurfer surface to EPI space using library functions
        # fs_to_func_reg = get_fs_to_func_reg(ref_anat_dir)
        # analysis.fs_surface_to_func_legacy(fs_to_func_reg, FS_DIR, analysis_dir=ref_anat_dir, force=True)
        # fs_rim = analysis.import_fs_ribbon_to_func(FS_DIR, ref_anat_dir, force=True)
        # # ---------------------------------------------------------------------
        
        # # Calculate voxel depths from surfaces
        #process_vdfs(ref_anat_dir, FS_DIR, area_files)
        
        # Define file paths for depths and regions of interest (ROIs)
        depths_path = os.path.join(ref_anat_dir, 'vdfs_depths_equivol.nii')
        # # Example ROI file names, assuming they are built using the analysis number
        analysis_number = analysis_dir.split('_')[-1]
        roi_left = '/ptmp/aeroglu/pilot_data/ROIs/sub-02/V1_rois/s016_bold_V1_L_roi.nii'
        roi_right = '/ptmp/aeroglu/pilot_data/ROIs/sub-02/V1_rois/s016_bold_V1_R_roi.nii'
        
        # Plot and save the profiles for left and right ROIs
        plot_and_save_profiles(data_list, roi_left, depths_path, ref_anat_dir, 's016_bold_V1_L_profile_vdfs_depths.png')
        plot_and_save_profiles(data_list, roi_right, depths_path, ref_anat_dir, 's016_bold_V1_R_profile_vdfs_depths.png')

if __name__ == "__main__":
    main()