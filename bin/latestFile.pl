#!/bin/perl
use strict;

my $maxAgeSec = 6000000;
my $dir       = "/eos/cms/store/group/visualization/run*";
my $lastFile  = "/home/fwdev/FireworksOnline/bin/LastFile";
my $testScript = "/home/fwdev/FireworksOnline/bin/testFile.sh";

#my $lastFile = "LastFile";

# Only consider file if it has not been modified for longer than this
# number of seconds.
# !!!! MT, 2014-11-05:
# !!!! This (200) is a workaround for DAQ copying file in to NFS for hours.
my $minFileAge = 10;

sub readLineFromFile {

    # Returns the first line from file or "" if the file does not exist.
    # Dies if file can not be opened for reading.
    my $filename = shift;
    return "" unless -e $filename;
    open F, $filename or die("Can't read_line_from_file!");
    my $line = <F>;
    close F;
    chomp $line;
    return $line;
}

while (1) {
    my $ref = "/tmp/cmsShow-tmp.txt";
    system("touch -d \"-$maxAgeSec seconds\" $ref");
    print("dir find ....", $dir , " \n");
    #my $lc = `k5start -q -f /home/viz/private/cmsvis.kt cmsvis -- find $dir -maxdepth 1 -mindepth 1 -name \\*.root -newer $ref `;
    my $lc=`k5start -q -f /home/fwdev/private/cmsvis.kt cmsvis -- authbind find $dir -maxdepth 1 -mindepth 1 -name \\*.root`;

   # print("______list ", $lc, "\n");
    my @candidates   = split( "\n", $lc );
    my $current_time = time;
    my %hash;

    foreach (@candidates) {
        my $cnd   = $_;
        my $delta = $current_time - ( stat($cnd) )[9];
        if ( $delta > $minFileAge ) {

           # print("candidate $_ ", (stat($cnd))[9] , " ", $delta, "\n");
            $hash{$delta} = $cnd;
        }
    }
    if (%hash) {
        my @times   = sort { $a <=> $b } keys %hash;
        my $latestt = @times[0];
        my $latest  = $hash{$latestt};
        print("latest candidate $latestt time, file path >>> $latest  \n");

        ### check if latest file can be opened by ROOT
        if ( system("k5start -q -f /home/fwdev/private/cmsvis.kt cmsvis -- $testScript $latest") ) {
            print "Latest file '$latest' can not be opened by root, sleeping 5 seconds;\n";
            sleep 1;
            next;
        }

        # notify the latest file from the list if diferent from previous
        my $sp = readLineFromFile("$lastFile");

        # sort files by modification time
        if ( $sp ne $latest ) {
            system("echo $hash{$latestt} > $lastFile");
            print("writing latest file in the bin/LatestFile $latestt");
            print localtime, " new LastFile = $latest\n";
        }
        else {
            #	printf("No new file.\n");
        }

    }

    # sleep 1 second before checking new file
    sleep 1;
}
