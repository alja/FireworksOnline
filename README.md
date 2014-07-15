FireworksOnline
===============

Scripts for P5

fw-monitor.pl : check if cmsShow is running, 
                notifies new files to cmsShow via netcat,
                copies cmsShow screenshots and log files to scp target
                
fw-config.txt:       online event display variables. Not keep ';' at the end of lines!

fw-cmsShow-command: shell scrips which starts cmsShow

FireworksOnlineSystem: wrapper which sets FW_ENABLED in fw-config.txt and starts:
                      #fw-montor.pl <myonlinedir>
