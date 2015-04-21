#!/usr/bin/bash

# echo Testing $1

. ~/cmsShow-7.1/external/root/bin/thisroot.sh 
LD_LIBRARY_PATH=:$LD_LIBRARY_PATH:/home/vis/cmsShow-7.1/external/lib

# root.exe <<EOF
root.exe > /dev/null 2>&1 <<EOF
{
TFile *fp = TFile::Open("$1");

printf("Foo %lld\n", fp);

if (fp == 0)
{
printf("Foo %lld\n", fp);
  printf("WTF\n");
  gSystem->Exit(1);
}
else
{
  gSystem->Exit(0);
}
}
EOF

exit $?
