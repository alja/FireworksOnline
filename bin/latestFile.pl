#!/bin/perl
use strict;

my $maxAgeSec = 6000000;
my $dir  = "/eventdisplay/";
my $lastFile = "/home/vis/Log/LastFile";
#my $lastFile = "LastFile";


if (@ARGV < 1) {
  print "usage: findLast.pl <dataDir> \n";
  exit 1;
}
else {
  $dir = shift(@ARGV);
}

# Only consider file if it has not been modified for longer than this
# number of seconds.
# !!!! MT, 2014-11-05:
# !!!! This (200) is a workaround for DAQ copying file in to NFS for hours.
my $minFileAge = 5;

sub readLineFromFile
{
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
    my $ref    = "/tmp/cmsShow-tmp.txt";
    system("touch -d \"-$maxAgeSec seconds\" $ref");
    my $lc=`find $dir -maxdepth 1 -mindepth 1 -name \\*.root -newer $ref `;
    my @candidates = split("\n",$lc);
    my $current_time = time;
    my %hash;
    foreach(@candidates) {
      my $cnd = $_;
      my $delta =  $current_time - (stat($cnd))[9];
      if ($delta > $minFileAge) {
#       print("candidate $_ ", (stat($cnd))[9] , " ", $delta, "\n");
        $hash{ $delta } = $cnd;
      }
    }
    if (%hash) {
      my @times = sort {$a<=>$b} keys %hash;
      my $latestt =  @times[0];
      my $latest = $hash{$latestt};

      ### MT 2014-11-07: Hack ... check if latest file can be opened by root
      if (system("/home/vis/testFile.sh $latest"))
      {
          print "Latest file '$latest' can not be opened by root, sleeping 5 seconds;\n";
          sleep 1;
          next;
      }

      # notify the latest file from the list if diferent from previous
      my $sp = readLineFromFile("$lastFile");
      # sort files by modification time
      if ($sp ne $latest ) {
        system("echo $hash{$latestt} > $lastFile");
        print localtime, " new LastFile = $latest\n";
      }
      else {
#       printf("No new file.\n");
      }

    }
    # sleep 1 second before checking new file
    sleep 1;
}
