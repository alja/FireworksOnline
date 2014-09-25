#!/bin/perl
use strict;

my $maxAgeSec = 60000;
my $dir  = "/eventdisplay/";
my $lastFile = "/tmp/Log/LastFile";

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
    my $lc=`find $dir -maxdepth 1 -mindepth 1 -name \*.root -newer $ref `; 
    my @candidates = split("\n",$lc);

    my $current_time = time;
    my %hash;
    foreach(@candidates) {
      my $cnd = $_;
      my $delta =  $current_time - (stat($cnd))[9];
      if ($delta > 1) {
	print("candidate $_ ", (stat($cnd))[9] , " ", $delta, "\n");
	$hash{ $delta } = $cnd;
      }
    }

    if (%hash) {
      my @times = sort {$a<=>$b} keys %hash;
      my $latestt =  @times[-1];
      my $latest = $hash{$latestt};

      # notify the latest file from the list if diferent from previous
      my $sp = readLineFromFile("$lastFile");
      # sort files by modification time

      if ($sp ne $latest ) {
        system("echo $hash{$latestt} > $lastFile");
	print "LastFile = $latest\n";
      }
      else {
	printf("No new file.\n");
      }

    }
    # sleep 1 second before checking new file
    sleep 1;
}
