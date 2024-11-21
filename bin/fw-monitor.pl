#!/usr/bin/env perl 
#

use strict;

use File::Copy;
use Proc::Killfam;
use POSIX qw( WNOHANG );
use Net::Domain qw(hostname hostfqdn hostdomain domainname);

# Variables from config file:
use vars qw
  ($FW_ENABLED $FW_DISPLAY
  $FW_NEW_FILE_NOTIFICATION $FW_NOTIFY_NEW_FILE_TIMEOUT
  $FW_PORT $FW_LATEST_FILE $FW_DEBUG
  $FW_SCP_CMSSHOW_IMAGE_ENABLE $FW_SCP_DESKTOP_IMAGE_ENABLE
  $FW_TRANSFER_IMAGE_TIMEOUT
  $FW_SCP_TARGET $FW_SSH_PRIVATE_KEY $FW_MAIL_LIST);

my $cmsShow_pid = 0;
my $ssh_option  = "";

# get base directory
die("Can't start the fw-monitor.pl script without base directory argument.")
  unless ( @ARGV == 1 );
my $FW_DIR = $ARGV[0];
die("Can't read configuration at $FW_DIR/bin/fw-config.txt")
  unless ( -r "$FW_DIR/bin/fw-config.txt" );

###############################################################################
# FUNCTIONS
###############################################################################

sub fwQuit {
    my $msg = shift;

    print $msg;

    if ($cmsShow_pid) {
        killfam 'KILL', $cmsShow_pid;
    }

    exit;
}

sub debugPrint {
    my $message = shift;
    if ($FW_DEBUG) {
        my $currentTime = localtime();
        print("$currentTime $message");
    }
}

$SIG{TERM} = sub {
    fwQuit("kill child fw-cmsShow-command \n");
};

sub writeLineToFile {

    # Write a file with one line.

    my ( $line, $filename ) = @_;

    open F, ">$filename" or fwQuit "Can't write_line_to_file!";
    print F $line, "\n";
    close F;
}

sub readLineFromFile {

    # Returns the first line from file or "" if the file does not exist.
    # Dies if file can not be opened for reading.

    my $filename = shift;
    return "" unless -e $filename;
    open F, $filename or fwQuit("Can't read_line_from_file!");
    my $line = <F>;
    close F;
    chomp $line;
    print("$filename readLineFromFile >>>>>>> ", $line, "\n");
    return $line;
}

sub setMonitorLog {

    # remove old log files
    {
        my $wktime = time();
        my $maxAge = 1209600;
        my $DIR;
        opendir( DIR, "$FW_DIR/log/" );
        while ( my $file = readdir DIR ) {
            if ( "$file" =~ m/((?:monitor)|(?:cmsShow))\.\d+\.log/ ) {
                my $mtime = ( stat "$FW_DIR/log/$file" )[9];
                my $dif   = $wktime - $mtime;
                if ( $dif > $maxAge ) {
                    print( $wktime, " remove old log $file with age $dif \n" );
                    unlink "$FW_DIR/log/$file";
                }
            }
        }
    }

    # remove old symbolic lik
    if ( -l "${FW_DIR}/log/monitor.log" ) {
        unlink("${FW_DIR}/log/monitor.log");
    }

    # set log file
    my $mpid           = $$;
    my $monitorLogFile = "${FW_DIR}/log/monitor.${mpid}.log";
    if (1) {
        open STDOUT, '>>', $monitorLogFile
          or fwQuit "fw-monitor: Can't redirect STDOUT: $!";
        open STDERR, ">&STDOUT" or fwQuit "fw-monitor: Can't dump STDOUT: $!";
    }

    symlink( $monitorLogFile, "${FW_DIR}/log/monitor.log" );

    my $now = localtime();
    print("$now Starting fw-monitor with pid $$ \n");
}

sub notifyNewDataFile {
    my $fw_file = shift;
    print("LATEST_FILE $FW_LATEST_FILE\n");
    my $afsFileName = readLineFromFile("$FW_LATEST_FILE");

    my $ntime            = localtime();
    my $afsFileTimeStamp = localtime( ( stat $afsFileName )[9] );
    print(
"$ntime Check new file every $FW_NOTIFY_NEW_FILE_TIMEOUT seconds. Looking at $FW_LATEST_FILE.\nLatest reconstructed file $afsFileName updated at $afsFileTimeStamp.\n"
    );


print("3 test sufff");
  if ( $afsFileName =~ m/\.root$/o )
  {
    print("test suffix _OK\n");
  }

  print("comapre previous $$fw_file.....\n");
  if ( $afsFileName ne $$fw_file )
  {
    print("test new _OK\n");
  }

    if ( ( $afsFileName =~ m/\.root$/o ) && ( $$fw_file ne $afsFileName ) ) {
        printf("Notify new file $afsFileName \n");
        system(" echo $afsFileName | nc -4 -w 10 localhost $FW_PORT");
        $$fw_file = $afsFileName;
    }
}

###############################################################################
# MAIN
###############################################################################
{
    # check or save monitor PID
    my $monitor_pid_file = "$FW_DIR/log/monitor_pid";
    if ( -r $monitor_pid_file ) {
        my $oldPid = readLineFromFile($monitor_pid_file);
        if (   ( -r "/proc/$oldPid" )
            && ( readLineFromFile("/proc/$oldPid/cmdline") =~ m/fw-monitor/ ) )
        {
            exit 0;
        }
    }

    # write current PID
    writeLineToFile( $$, $monitor_pid_file );

    # setup env
    setMonitorLog();
    do "$FW_DIR/bin/fw-config.txt";
    my $cmsShow_cnt = 60;
    my $live_cnt    = 0;
    my $feeder_cnt  = 0;
    my $img_cnt     = 0;

    my $latest_screenshot;
    my $latest_data_file;

 # build maillist for current domain
    my $hname = domainname();
    my $mlist;
    {
        my $dname = hostdomain();
        foreach my $address ( split( /\s+/, $FW_MAIL_LIST ) ) {
            if ( $address =~ m/$dname/ ) {
                $mlist .= "${address} ";
            }
        }
    }

    while (1) {

        # print "Entering THE loop\n";

# check in case some has edited external config (e.g. call fireworksOnline --stop/start)
        do "$FW_DIR/bin/fw-config.txt";

        if ( $FW_ENABLED == 0 ) {
            fwQuit("event display was disabled. Exit ...\n");
        }
        else {
            {
                my $pid = waitpid( -1, WNOHANG );
                if ( $cmsShow_pid != 0 && $pid == $cmsShow_pid ) {
                    if ( $? != 0 ) {
                        printf(
"\nERROR: cmsShow exited unexpectedly! See $FW_DIR/log/cmsShow.${cmsShow_pid}.log  !\n"
                        );
                        my $msg =
"Look for details in $hname $FW_DIR/log/cmsShow.${cmsShow_pid}.log";
                        system(
" echo $msg | mail -s ${hname}::cmsShow-crash-report $mlist"
                        );
                    }
                    else {
                        print "\nINFO: cmsShow child process exit.\n";
                    }
                    $cmsShow_pid = 0;
                }
                elsif ( $pid == 0 ) {
                    debugPrint "waitpid -- processes still running\n";
                }
                elsif ( $pid == -1 ) {
                    debugPrint "waitpid error -- errno $!\n";
                }
                else {
                    debugPrint "waitpid reaped process $pid\n";
                }
            }

            if ( $cmsShow_pid == 0 && $cmsShow_cnt >= 60 ) {
                my $header = localtime();
                print(
                    "$header Fireworks was not running and will be started...\n"
                );
                if ( -l "$FW_DIR/log/cmsShow.log" ) {
                    unlink "$FW_DIR/log/cmsShow.log";
                }

                $ENV{FW_DIR}  = $FW_DIR;
                $ENV{FW_PORT} = $FW_PORT;

                my $afsFile         = readLineFromFile("$FW_LATEST_FILE");
                my $cmsShow_command = "$FW_DIR/bin/fw-cmsShow-command $afsFile";

                $cmsShow_pid = fork();
                if ( $cmsShow_pid == 0 ) {
                    exec($cmsShow_command)
                      or fwQuit "Failed to execute $cmsShow_command";
                }
                print(
"pid after fork [$cmsShow_pid]  ==========================================\n"
                );
                writeLineToFile( $cmsShow_pid, "$FW_DIR/log/cmsShow_pid" );
                $cmsShow_cnt = 0;
            }

            # system("ps --forest -o pid,tty,stat,time,cmd");

            # notify new files
            if ( $FW_NEW_FILE_NOTIFICATION
                && ( $feeder_cnt >= $FW_NOTIFY_NEW_FILE_TIMEOUT ) )
            {
                notifyNewDataFile( \$latest_data_file );
                $feeder_cnt = 0;
            }

            $cmsShow_cnt++;
            $live_cnt++;
            $feeder_cnt++;
            $img_cnt++;

            sleep 1;
        }
    }
}
