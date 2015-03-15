#!/usr/bin/env perl
use strict;
use Net::Syslog;
 
my $logfile = "/var/log/nsyncbackupverification.log";
my $verificationThreshold = $ARGV[0];
 
if(!$verificationThreshold)
	{
	print "Please provide a minimum number of acceptably missing files on the command line.\n";
	exit;
	}
 
my $missingFiles = 0;
my $exclusionfile = "/usr/local/etc/nsyncexclusions";
my $nsyncconf = "/etc/nsyncexcludes.conf";
my @nsyncexclusions;
my $sysloghost     = '127.0.0.1';                                     # where to syslog
my $syslogpriority = 'notice';                                          # syslog priority
my $syslogname     = 'backup';                                          # syslog name
my $syslogfacility = 'local6';                                          # syslog facility
 
my $hostname;
$hostname = ` hostname `;
 
my $backupgood = 1;                                                     # We'll assume everything is good until we know other
 
# Setup syslog
my $syslog = Net::Syslog->new(  SyslogHost => $sysloghost,
                                Priority   => $syslogpriority,
                                Name       => $syslogname,
                                Facility   => $syslogfacility,  );
 
 
 
print "Backup verification started with a missing files threshold of $verificationThreshold.\n";
logit("Backup verification started with a missing files threshold of $verificationThreshold.");
 
open(EX,"<$rsyncconf");
while(my $thisexclusion = <EX>)
        {
        chomp($thisexclusion);
	# This line should fix the verification bug
        $thisexclusion =~ s/\*/.*/;
        $thisexclusion = "/backup" . $thisexclusion;
        push @nsyncexclusions, $thisexclusion;
        }
close(EX);
 
open(EX,"<$exclusionfile");
while(my $thisexclusion = <EX>)
        {
        chomp($thisexclusion);
        push @nsyncexclusions, $thisexclusion;
        }
close(EX);
 
push @nsyncexclusions, "/backup/dev";
 
open(ALLFILES,"find / -type \"file\"|");
 
my $numberOfFiles = 0;
 
while(my $thisline = <ALLFILES>)
	{
	unless($thisline =~ /^\/backup/)
		{
		$numberOfFiles++;
		if($numberOfFiles % 1000 == 0)
			{
			logit("Verified $numberOfFiles files");
			}
		chomp($thisline);
		my $backupfile = "/backup" . $thisline;
		if(! -f "$backupfile" && ! -d "$backupfile" && ! -l "$backupfile")
			{
			my $file_missing=1;
		        foreach(@nsyncexclusions)
                		{
                		if($backupfile =~ /$_/)
                        		{
                        		$file_missing=0;
                        		}
                		}
			if($file_missing)
				{
				$missingFiles++;
				print "File not found in backup: '$backupfile'\n";
				logit("File not found in backup: $backupfile");
				}
			}
		}
	}
close(ALLFILES);
 
if($missingFiles <= $verificationThreshold)
        {
        $syslog->send("$hostname: 1");
	print "Backup succeeded.\n";
	logit("Backup succeeded.");
        }
else
        {
        $syslog->send("$hostname: 0");
    	print "Backup Failed.\n";
	logit("Backup failed.");
    	}
exit;
 
sub logit {
	my $message = shift;
	my $date = `/bin/date`;
	chomp($date);
	system("echo \"[ $date ] $message\" >> $logfile");
}

