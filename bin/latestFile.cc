
#include "XrdCl/XrdClFile.hh"
#include "XrdCl/XrdClXRootDResponses.hh"
#include "XrdCl/XrdClStatus.hh"
#include "XrdCl/XrdClURL.hh"
#include "XProtocol/XProtocol.hh"
#include <string>
#include <vector>
#include <stdio.h>
#include <algorithm>
#include <iostream>
//#include <fsteam>
#include "TFile.h"
#include "TTree.h"

#include <cstdio>

bool debug = false;
using namespace XrdCl;


typedef std::string      Str_t;
typedef std::list<Str_t> lStr_t;
typedef lStr_t::iterator lStr_i;

// to compile
// g++ -std=c++11 -g -lXrdCl -lTree -lRIO -lCore  -I/usr/include/xrootd -I/opt/root/include/ latestFile.cc -o latestEOSFile -L/opt/root/lib

std::string timeStampToHReadble(long  timestamp)
{
    const time_t rawtime = (const time_t)timestamp;

    struct tm * dt;
    char timestr[30];
    char buffer [30];

    dt = localtime(&rawtime);
    // use any strftime format spec here
    strftime(timestr, sizeof(timestr), "%m/%d %H::%M::%S",
	     dt);
    sprintf(buffer,"%s", timestr);
    std::string stdBuffer(buffer);
    return stdBuffer;
}

bool getLatestFileInSubdir(FileSystem& fileSystem, std::string& latest_file, std::string subDir)
{ 
   // lop run sub-dir and sort files by modification time
   DirectoryList* dls = 0;
   XRootDStatus status =  fileSystem.DirList(subDir, DirListFlags::Stat, dls);
   std::sort(dls->Begin(), dls->End(),  [](const DirectoryList::ListEntry* a, const  DirectoryList::ListEntry* b) -> bool
             {
                return a->GetStatInfo()->GetModTime() > b->GetStatInfo()->GetModTime(); 
             });

   // view complete list for high debug
   if (0 && debug) {
     printf("sorted files \n");
     for (DirectoryList::ConstIterator it = dls->Begin(); it != dls->End(); ++it)
       {
	 printf("%d ... %s modtime \n",  (*it)->GetStatInfo()->GetModTime(), (*it)->GetName().c_str());
       }
     printf("\n ");
   }
   
   // check the latest jsn file and then return root file
   std::string ext = ".jsn";
   for (DirectoryList::ConstIterator it = dls->Begin(); it != dls->End(); ++it)
   {
      const DirectoryList::ListEntry* le = *it;
      if (debug) printf("checking [%s] \n", le->GetName().c_str());
      size_t xxx = 0;
      if (le->GetName().size() > 4) {
         std::string xxx = le->GetName().substr(le->GetName().size()-ext.size());
         if(xxx == ext) {
            latest_file = "root://eoscms.cern.ch/" + subDir + "/" +le->GetName().substr(0, le->GetName().size()- ext.size()) + ".root";
            if (debug)
	      {
		std::string ht = timeStampToHReadble(le->GetStatInfo()->GetModTime());
		printf("found %s ---%s ------------------- \n", latest_file.c_str(), ht.c_str());
	      }
	    
	    FILE *dnull = fopen("/dev/null", "w");
	    FILE *def_stderr = stderr;
	    stderr = dnull;
	    TFile *newFile = TFile::Open(latest_file.c_str());
	    stderr = def_stderr;
	    fclose(dnull);
    
            if(!newFile) {
	       if (debug) printf("open failed\n");
               continue;

            }

            if (newFile->Get("Events"))
            {
               TTree *events = dynamic_cast<TTree*>(newFile->Get("Events"));
               if (debug) printf("NumEntries %d \n", events->GetEntries());
               if (events->GetEntries()) {
                  return true;
               }
            }
            if (debug) printf("No event tree \n");
            newFile->Close();
            delete newFile;

         }
      }
      return false;
   }
}


void next_arg_or_die(lStr_t& args, lStr_i& i, bool allow_single_minus=false)
{
  lStr_i j = i;
  if (++j == args.end() || ((*j)[0] == '-' && ! (*j == "-" && allow_single_minus)))
  {
    std::cerr <<"Error: option "<< *i <<" requires an argument.\n";
    exit(1);
  }
  i = j;
}

int main(int argc, char *argv[])
{
   std::string mUrl = "eoscms.cern.ch";
   std::string mTopDir = "/store/group/visualization";
   
   lStr_t mArgs;
   for (int i = 1; i < argc; ++i)
     mArgs.push_back(argv[i]);


   lStr_i i = mArgs.begin();   
   while (i != mArgs.end()){
     lStr_i start = i;

     if (*i == "-h" || *i == "-help" || *i == "--help" || *i == "-?")
       {
	 printf("Arguments:\n"
		"\n"
		"  --server <str>           xrootd server, default eoscms.cern.ch\n"
		"\n"
		"  --verbose        be more talkative (only for --cmsclientsim)\n"
		"\n"
		"  --dir <str>      top directory to files, default visualization\n"
		);
	 exit(0);
       }
      
     else if (*i == "--verbose")
       {
	 debug = true;
	 mArgs.erase(start, ++i);
       }
     
     else if (*i == "--server")
      {
         next_arg_or_die(mArgs, i);
	 mUrl=*i;
	 mArgs.erase(start, ++i);
       }
      else if (*i == "--dir")
      {
         next_arg_or_die(mArgs, i);
	 mTopDir=*i;
	 mArgs.erase(start, ++i);
	 printf("parse dir %s\n", mTopDir.c_str());
       }
      else
      {
         ++i;
      }
   }
  
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
       if (debug) printf("-------------------- check run %d \n", element );
       if (getLatestFileInSubdir(fileSystem, lf, subDir)) {
          printf("%s\n", lf.c_str());
          break;
       }
   }

}
