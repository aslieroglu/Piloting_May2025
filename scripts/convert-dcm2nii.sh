#!/bin/bash
# converts dicoms to niftis and takes series number as first input (needs following format: 01)

#######################################
### Define folderName and series
#######################################
seriesNumber=$1 #first input
#seriesNumber=02

#folderName=$2
folderName=20240806.aardvark_sfassnacht.24.08.06_15_39_55_DST_1.3.12.2.1107.5.2.0.18951

#######################################
### Define other things - should not change
#######################################
sourceDir=/mnt/upload9t/USERS/RLorenz/realTimeExport/${folderName}
destDir=/home/meduser/realTimefMRI/data/${folderName}
seriesPattern=001_0000${seriesNumber}*.dcm

# Check if destDir exists, if not, create it
if [ ! -d ${destDir} ]; then
    mkdir -p ${destDir}
fi

# Check if tmpDir exists (we need this one due to dcm2niix command), if not, create it
if [ ! -d ${destDir}/tmp ]; then
    mkdir -p ${destDir}/tmp
fi

# Empty tmp folder - so we can explicitly convert one series
if [ "$(ls -A ${destDir}/tmp)" ]; then
    echo "****** cleaning up in tmp folder ******"
    rm ${destDir}/tmp/*
fi

cp ${sourceDir}/${seriesPattern} ${destDir}/tmp
chmod -R 755  ${destDir}/tmp #had problems with write protection

#run dcm2niix command
dcm2niix -o ${destDir} -f '%p_%s' ${destDir}/tmp 


