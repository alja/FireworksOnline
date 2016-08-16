import os.path, time, datetime, glob, sys
import re, json as json
from rrapi import RRApi, RRApiError
sys.argv.append( '-b' )
import ROOT
ROOT.gSystem.Load("libDataFormatsFWLite.so")
ROOT.AutoLibraryLoader.enable()

#these are global variables
minDuration = 30
nHours = 2
h_dmin_filecreate_firstevt = ROOT.TH1F("dmin_filecreate_firstevt", "deltaT(min) filecreate-firstevt", 60, 0, 60)
h_dmin_filemodify_firstevt = ROOT.TH1F("dmin_filemodify_firstevt", "deltaT(min) filemodify-firstevt", 60, 0, 60)
h_dmin_filecreate_lastevt = ROOT.TH1F("dmin_filecreate_lastevt", "deltaT(min) filecreate-lastevt", 60, 0, 60)
h_dmin_filemodify_lastevt = ROOT.TH1F("dmin_filemodify_lastevt", "deltaT(min) filemodify-lastevt", 60, 0, 60)
h_dmin_lastevt_firstevt = ROOT.TH1F("dmin_lastevt_firstevt", "deltaT(min) lastevt-firstevt", 60, 0, 60)
outtime = time.strftime('%Y-%m-%d-%H-%M-%S', time.gmtime())
# Default User app URL
URL  = "http://runregistry.web.cern.ch/runregistry/"

def formatted_date(t):
    return datetime.datetime.fromtimestamp(t)

def process_file(file):
    print 'process file: %s' % file
    logf = open('/home/vis/Fireworks/monitorFiles/testFiles.log', 'a')
    modifyfile = os.path.getmtime(file)
    createfile = os.path.getctime(file)
    firstevt = 0
    lastevt = 0
    myfile = ROOT.TFile.Open(file)
    mytree=myfile.Get('Events')
    mytree.SetBranchStatus("*",0)
    mytree.SetBranchStatus("EventAuxiliary",1)
    i = 0
    size = mytree.GetEntries()
    for event in mytree:
        #print event.EventAuxiliary.time().unixTime()
        if i==0: firstevt = event.EventAuxiliary.time().unixTime()
        i += 1
        if i==size: lastevt = event.EventAuxiliary.time().unixTime()
    if size>0:
        print 'file created on %s' % formatted_date(createfile)
        print 'file modified on %s' % formatted_date(modifyfile)
        print 'first event taken on %s' % formatted_date(firstevt)
        print 'last event taken on %s' % formatted_date(lastevt)
        logf.write('file %s created on %s, last modified on %s, first event taken on %s, last event taken on %s, delta(creat-first)=%f\n' % (file, formatted_date(createfile), formatted_date(modifyfile), formatted_date(firstevt), formatted_date(lastevt), float(createfile-firstevt)/60.))
        h_dmin_filecreate_firstevt.Fill(float(createfile-firstevt)/60.)
        h_dmin_filemodify_firstevt.Fill(float(modifyfile-firstevt)/60.)
        h_dmin_filecreate_lastevt.Fill(float(createfile-lastevt)/60.)
        h_dmin_filemodify_lastevt.Fill(float(modifyfile-lastevt)/60.)
        h_dmin_lastevt_firstevt.Fill(float(lastevt-firstevt)/60.)
    myfile.Close()
    logf.close()

def testRunsFromRR(path, outpath):
    try:

        # Construct API object
        api = RRApi(URL, debug = True)

        #print api.tables('GLOBAL')
        #print api.columns('GLOBAL', 'runsummary')
        #coljson = api.columns('GLOBAL', 'runsummary')
        #for block in coljson:
        #    print block['name']
        ##print api.templates('GLOBAL', 'runsummary')
        ##print api.count('GLOBAL', 'runsummary')

        #find out the last run we cleaned up
        lastCleanedRun = 0
        for line in reversed(list(open("/home/vis/clearTempArea.log"))):
            if ('.root' in line):
                myline = line.rstrip() 
                #print(myline)
                #print(myline.rfind('run'))
                #print(myline.rfind('_ls'))
                lastCleanedRun = myline[myline.rfind('run')+3:myline.rfind('_ls')]
                #print(lastCleanedRun)
                break

        #Example queries
        #print api.data( workspace = 'GLOBAL', table = 'runsummary', template = 'csv', columns = ['number', 'events', 'lsCount', 'duration', 'startTime', 'stopTime', 'datasetExists'], filter = {'startTime': '>= 2015-04-17', 'duration': '>= 300', 'datasetExists': '= true'}, order = ['number asc'] )
        #myjson = api.data( workspace = 'GLOBAL', table = 'runsummary', template = 'json', columns = ['number', 'events', 'lsCount', 'duration', 'startTime', 'stopTime', 'datasetExists'], filter = {'startTime': '>= 2015-04-17', 'duration': '>= 300', 'datasetExists': '= true'}, order = ['number asc'] )

        print 'search for runs after '+str(lastCleanedRun)+' of at least '+str(minDuration)+' secs'
        print api.data( workspace = 'GLOBAL', table = 'runsummary', template = 'csv', columns = ['number', 'events', 'lsCount', 'duration', 'startTime', 'stopTime', 'datasetExists'], filter = {'number': '> '+lastCleanedRun, 'duration': '>= '+str(minDuration), 'datasetExists': '= true'}, order = ['number asc'] )
        myjson = api.data( workspace = 'GLOBAL', table = 'runsummary', template = 'json', columns = ['number', 'events', 'lsCount', 'duration', 'startTime', 'stopTime', 'datasetExists'], filter = {'number': '> '+lastCleanedRun, 'duration': '>= '+str(minDuration), 'datasetExists': '= true'}, order = ['number asc'] )

        #get what time is it now
        now = time.gmtime()
        print 'UTC time is '+time.strftime('%a %d-%m-%y %H:%M:%S', time.gmtime())
        tsnow = time.mktime(now)

        nruns = 0.
        foundruns = 0.
        nrunsNh = 0.
        foundrunsNh = 0.
        for block in myjson:
            print 'run: '+str(block['number'])+' startTime: '+str(block['startTime'])
            nruns = nruns+1.
            strun = time.strptime(block['startTime'], '%a %d-%m-%y %H:%M:%S')
            tsrun = time.mktime(strun)
            isRunLastNh = 0
            if (tsnow-tsrun < nHours*60*60): 
                nrunsNh = nrunsNh+1.
                isRunLastNh = 1
                print 'run in last '+str(nHours)+' hours!'
            for f in glob.glob(path):
                found = str(block['number']) in str(f)
                if found:
                    print 'found matching file: '+f
                    foundruns = foundruns+1.
                    if (isRunLastNh): foundrunsNh = foundrunsNh+1
                    break

        print 'efficiency = %f' % (foundruns/nruns)
        print 'efficiency last Nh = %f' % ((foundrunsNh/nrunsNh) if nrunsNh>0 else -1)

        c1 = ROOT.TCanvas()
        h_eff = ROOT.TH1F("h_eff", "efficiency (>=1 file for runs of >"+str(minDuration)+" sec)", 2, 0, 2)
        h_eff.GetXaxis().SetBinLabel(1,"all (%i runs)" % nruns)
        h_eff.GetXaxis().SetBinLabel(2,"last "+str(nHours)+" hours (%i runs)" % nrunsNh)
        h_eff.SetBinContent(1,(foundruns/nruns))
        h_eff.SetBinContent(2,((foundrunsNh/nrunsNh) if nrunsNh>0 else -1))        
        h_eff.Draw()
        h_eff.GetYaxis().SetRangeUser(0.,1.1)
        c1.SaveAs(outpath+"/h_eff-"+outtime+".png")

    except RRApiError, e:
        print e

def main():

    if (len(sys.argv)<4):
        print 'please specify the pattern and the output directory'
        print 'usage: python timeTest.py \'/path/*.root\'' 
    else:
        match = sys.argv[1]
        print 'processing files matching: %s' % match

        outdir = sys.argv[2]
        print 'saving images in: %s' % outdir

        for file in glob.glob(match):
            process_file(file)
    
        c1 = ROOT.TCanvas()
        ROOT.gStyle.SetOptStat(111111)
        h_dmin_filecreate_firstevt.Draw()
        c1.SaveAs(outdir+"/h_dmin_filecreate_firstevt-"+outtime+".png")
        h_dmin_filecreate_lastevt.Draw()
        c1.SaveAs(outdir+"/h_dmin_filecreate_lastevt-"+outtime+".png")
        h_dmin_lastevt_firstevt.Draw()
        c1.SaveAs(outdir+"/h_dmin_lastevt_firstevt-"+outtime+".png")

        ROOT.gStyle.SetOptStat(0)
        testRunsFromRR(match, outdir)

        olddir = os.getcwd()
        os.chdir(outdir)
        os.system("rm h_dmin_filecreate_firstevt.png")
        os.system("rm h_dmin_filecreate_lastevt.png")
        os.system("rm h_dmin_lastevt_firstevt.png")
        os.system("rm h_eff.png")
        os.system("ln -s h_dmin_filecreate_firstevt-"+outtime+".png h_dmin_filecreate_firstevt.png")
        os.system("ln -s h_dmin_filecreate_lastevt-"+outtime+".png h_dmin_filecreate_lastevt.png")
        os.system("ln -s h_dmin_lastevt_firstevt-"+outtime+".png h_dmin_lastevt_firstevt.png")
        os.system("ln -s h_eff-"+outtime+".png h_eff.png")
        os.system("scp h_dmin_filecreate_firstevt.png evtdisp@srv-c2c03-01--cms.cern.ch:images/")
        os.system("scp h_dmin_filecreate_lastevt.png evtdisp@srv-c2c03-01--cms.cern.ch:images/")
        os.system("scp h_dmin_lastevt_firstevt.png evtdisp@srv-c2c03-01--cms.cern.ch:images/")
        os.system("scp h_eff.png evtdisp@srv-c2c03-01--cms.cern.ch:images/")
        os.system("cp h_dmin_filecreate_firstevt.png /eventdisplayweb/images/")
        os.system("cp h_dmin_filecreate_lastevt.png /eventdisplayweb/images/")
        os.system("cp h_dmin_lastevt_firstevt.png /eventdisplayweb/images/")
        os.system("cp h_eff.png /eventdisplayweb/images/")
        os.chdir(olddir)

if __name__ == '__main__':
    main()
