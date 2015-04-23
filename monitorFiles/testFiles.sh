#!/usr/bin/bash

source ~/cmsShow-7.1/external/root/bin/thisroot.sh 
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/vis/cmsShow-7.1/external/lib:/home/vis/cmsShow-7.1/lib
python /home/vis/Fireworks/monitorFiles/testFiles.py '/eventdisplay/run*/*.root' '/home/vis/Fireworks/monitorFiles/images'
find /home/vis/Fireworks/monitorFiles/images/*.png -mtime +10 -type f -delete
#find /home/vis/Fireworks/monitorFiles/images/*.png -mmin +240 -type f -delete
