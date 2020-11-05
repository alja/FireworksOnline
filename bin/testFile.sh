#!/usr/bin/bash

# echo Testing $1

#. ~/cmsShow-8.1/external/root/bin/thisroot.sh 
#LD_LIBRARY_PATH=:$LD_LIBRARY_PATH:/home/vis/cmsShow-8.1/external/lib

export SHELLDIR=/home/vis/cmsShowLast
. $SHELLDIR/env.sh

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
  TTree *t = (TTree*)fp->Get("Events");
  if (t == 0) {
    printf("Tree %lld\n", t);
    gSystem->Exit(1);
  }
  if (t->GetEntries() == 0) {
    printf("No events\n");
    gSystem->Exit(1);
  }

  gSystem->Exit(0);
}
}
EOF

exit $?
