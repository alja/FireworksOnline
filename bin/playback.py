#!/usr/bin/python

import random
import time
import os
import glob
import sys, getopt


# print("arg1= ", sys.argv[1])

print("Number of arguments= ", len(sys.argv))
directory_path = os.getcwd()

if len(sys.argv) == 2:
    directory_path = sys.argv[1]

suffix = ".root" 

files = glob.glob(f"{directory_path}/*{suffix}")

print(files)

'''
random_list = ["/data2/relval-samples/RelVallZTTGenSimReco.root", "/data2/relval-samples/RelValMuMureco.root", 
               "/data2/relval-samples/RelValTTBarReco.root", "/data2/relval-samples/RelValRecHitReco.root"];
'''

random_list = files
# Loop through the list using a while loop
print("\nUsing a while loop:")
while True :
    index = 0
    while index < len(random_list):
        filename = random_list[index];
        cmd = "echo " + filename + " > " + directory_path + "/LatestFile"
        print(cmd)
        os.system(cmd)
        index += 1
        time.sleep(5)