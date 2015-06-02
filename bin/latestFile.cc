
#include "XrdCl/XrdClFile.hh"
#include "XrdCl/XrdClXRootDResponses.hh"
#include "XrdCl/XrdClStatus.hh"
#include "XrdCl/XrdClURL.hh"
#include "XProtocol/XProtocol.hh"
#include <string>
#include <vector>
#include <stdio.h>
#include <algorithm>

#include "TFile.h"
#include "TTree.h"


using namespace XrdCl;

// to compile
// g++ -std=c++11 -g -lXrdCl -lTree -lRIO -lCore  -I/usr/include/xrootd -I/opt/root/include/ latestFile.cc -o latestEOSFile -L/opt/root/lib

bool getLatestFileInSubdir(FileSystem& fileSystem, std::string& latest_file, std::string subDir)
{ 
   // lop run sub-dir and sort files by modification time
   DirectoryList* dls = 0;
   XRootDStatus status =  fileSystem.DirList(subDir, DirListFlags::Stat, dls);
   std::sort(dls->Begin(), dls->End(),  [](const DirectoryList::ListEntry* a, const  DirectoryList::ListEntry* b) -> bool
             {
                return a->GetStatInfo()->GetModTime() > b->GetStatInfo()->GetModTime(); 
             });

   // check the latest jsn file and then return root file
   std::string ext = ".jsn";
   for (DirectoryList::ConstIterator it = dls->Begin(); it != dls->End(); ++it)
   {
      const DirectoryList::ListEntry* le = *it;
      // printf("checking [%s] \n", le->GetName().c_str());
      size_t xxx = 0;
      if (le->GetName().size() > 4) {
         std::string xxx = le->GetName().substr(le->GetName().size()-ext.size());
         if(xxx == ext) {
            latest_file = "root://eoscms.cern.ch/" + subDir + "/" +le->GetName().substr(0, le->GetName().size()- ext.size()) + ".root";
            //  printf("found %s ---------------------- \n", latest_file.c_str());
            TFile *newFile = TFile::Open(latest_file.c_str());
            if(!newFile) {
               // printf("open failed\n");
               continue;

            }

            if (newFile->Get("Events"))
            {
               TTree *events = dynamic_cast<TTree*>(newFile->Get("Events"));
               // printf("NumEntries %d \n", events->GetEntries());
               if (events->GetEntries()) {
                  return true;
               }
            }
            // printf("No event tree \n");
            newFile->Close();
            delete newFile;

         }
      }
      return false;
   }
}
int main(int argc, char *argv[])
{
   std::string mUrl = "eoscms.cern.ch";
   std::string mTopDir = "/store/group/visualization";
   FileSystem fileSystem(mUrl);

   // sort run directories
   DirectoryList* response = 0;
   XRootDStatus status =  fileSystem.DirList(mTopDir, DirListFlags::None, response);
   std::vector<int> runIds;
   for (DirectoryList::ConstIterator it = response->Begin(); it != response->End(); ++it)
   {
      const DirectoryList::ListEntry* le = *it; 
      if (le->GetName().size() > 3 && (strncmp( le->GetName().c_str(), "run", 3) == 0)) {
         const char* id = &le->GetName()[3];
         int iid = atoi(id);
         runIds.push_back(iid);
      }
   }
   std::sort(runIds.begin(), runIds.end(), std::greater<int>());


   // search for latestest closed file form the newest to the oldest run directory
   std::string lf;
   for (auto & element : runIds) {
       std::string subDir =  mTopDir + "/run";
       subDir += std::to_string(element);
       if (getLatestFileInSubdir(fileSystem, lf, subDir)) {
          //  printf("root://eoscms.cern.ch/%s\n", lf.c_str());
          printf("%s\n", lf.c_str());
          break;
       }
   }

}
