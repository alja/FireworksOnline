
#include "XrdCl/XrdClFile.hh"
#include "XrdCl/XrdClXRootDResponses.hh"
#include "XrdCl/XrdClStatus.hh"
#include "XrdCl/XrdClURL.hh"
#include "XProtocol/XProtocol.hh"
#include <string>
#include <vector>
#include <stdio.h>
#include <algorithm>

using namespace XrdCl;

// to compile
// g++ -std=c++11 -I $XRD/include/xrootd -l XrdCl latestFile.cc

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
   static std::string ext = ".jsn";
   for (DirectoryList::ConstIterator it = dls->Begin(); it != dls->End(); ++it)
   {
      const DirectoryList::ListEntry* le = *it;
      // printf("checking [%s] \n", le->GetName().c_str());
      std::string::size_type idx = le->GetName().find_last_of(ext);
      if(idx != std::string::npos) {
         // printf("found %s \n", le->GetName().c_str());
         latest_file = subDir + "/" +le->GetName().substr(0, idx- ext.size()+1) + ".root";
         return true;
      }      
   }
   return false;
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
          printf("root://eoscms.cern.ch/%s\n", lf.c_str());
          break;
       }
   }

}
