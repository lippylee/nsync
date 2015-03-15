#!/usr/bin/env perl -w

###
## Before running this script, make sure you have:
## /etc/nsyncexcludes.conf
## /usr/local/bin/nsyncverifybackup.sh
## /usr/local/bin/comparedisks.pl
## and /usr/local/etc/nsyncexclusions
###
 
use strict;
use Getopt::Long;
use File::Basename;
use Net::Syslog;
 
createFileSystemEntropy();
 
# This is the number of files that are allowed to be missing before the backup reports as failed
my $fileVerificationThreshold = 5;
 
my $backupfrom     = '/';						# / usually
my $backupto       = '/backup';						# change to backup location
my $sysloghost     = '127.0.0.1';					# where to syslog
my $syslogpriority = 'notice';						# syslog priority
my $syslogname     = 'backup';						# syslog name
my $syslogfacility = 'local6';						# syslog facility
my $logfile        = '/var/log/nsync.log';				# provide a local log
my $configfile     = '/etc/nsyncexcludes.conf';				# config file
my $attempts       = 5;							# total attempts
my $interval       = 15;						# minutes between attempts
 
my $version        = '0.4.6';
 
my $CHECKVER       = 0;
my $LISTEXCLUSIONS = 0;
my $DELETE         = 0;
my $SIMSUCCESS     = 0;
my $SIMFAIL        = 0;
my $STATICHOST     = "";
GetOptions(	'v'	=> \$CHECKVER,
		'l'	=> \$LISTEXCLUSIONS,
		'd'	=> \$DELETE,
		's'	=> \$SIMSUCCESS,
		'f'	=> \$SIMFAIL,,
		'h=s'	=> \$STATICHOST,	);
 
if ( $CHECKVER ) { print basename($0)." ".$version."\n"; exit 0; }
 
my @excludes;
hardExcludes();
readConfig();
 
if ( $LISTEXCLUSIONS ) {
  print join("\n",@excludes)."\n";
  exit 0;
}
 
my $tryseconds          = $interval * 60;
my $hostname;
if   ( $STATICHOST ) { $hostname = $STATICHOST;  }
else                 { $hostname = ` hostname `; }
chomp($hostname);
chomp( my $rsynccommandold = ` /usr/bin/which rsync | /usr/bin/head -1 ` );
print "Old rsync command: $rsynccommandold\n";
chomp( my $rsynccommand = "/usr/bin/rsync" );
 
my $successful = 0;
my $count      = 0;
 
my $syslog = Net::Syslog->new(
    SyslogHost => $sysloghost,
    Priority   => $syslogpriority,
    Name       => $syslogname,
    Facility   => $syslogfacility,
);
 
# Check to make sure the backup disk is mounted
my $backupdiskstatus = `/bin/df | /bin/grep 'backup'`;
if ( $backupdiskstatus !~ /backup/)
	{
	print "Backup disk is not mounted!\n";
	$syslog->send("$hostname: 0");
	exit 0;
	}
 
if    ( $SIMSUCCESS ) { $successful = 1;             }
elsif ( $SIMFAIL    ) { $count      = $attempts + 1; }
 
while( !$successful &&( $count <= $attempts) ) {
  if ( $count ) { sleep $tryseconds; }
  $successful = tryBackup();
  $count++;
}
 
# We'll ignore these error codes for now and rely on the response provided by the verify script
#if   ( $successful ) { $syslog->send("$hostname: 1"); }
#else                 { $syslog->send("$hostname: 0"); }
 
system("/usr/local/bin/nsyncverifybackup.sh $fileVerificationThreshold");
exit 0;
 
sub readConfig {
  if ( -f $configfile ) {
    open CONF, $configfile;
    while(<CONF>) {
      chomp( my $in = $_ );
      # Skip comments and blank lines
      if ( $in =~ /^#/ )    { next; }
      if ( $in =~ /^\s*$/ ) { next; }
      push(@excludes,$in);
    }
    close CONF;
  }
  else {
    print "No extra excludes found ($configfile)\n";
  }
}
 
sub hardExcludes {
  push(@excludes,'/backup/*');
  push(@excludes,'/proc/*');
  push(@excludes,'/tmp/*');
  push(@excludes,'/sys/*');
  push(@excludes,'/dev/*');
  push(@excludes,'/var/run/log');
}
 
sub logit {
  chomp( my $now  = ` date ` );
  chomp( my $line = shift );
  open  LOGF, ">>$logfile" or die "Couldn't open logfile $logfile for writing";
  print LOGF "$now\t$line\n";
  close LOGF;
}
 
sub tryBackup {
  my $backupcommand = " $rsynccommand -va";
  if ( $DELETE ) {
    $backupcommand .= " --delete";
  }
  if ( scalar @excludes ) {
    $backupcommand .= " --exclude '".join("' --exclude '",@excludes)."'";
  }
  $backupcommand   .= " $backupfrom $backupto ";
 
  print "$backupcommand\n";
  system($backupcommand);
 
 
  my $exit_value  = $? >> 8;
  my $dumped_core = $? & 128;
 
# Damn thing returns error even if just 1 file was missing, so ignore exit code
#  if ( $exit_value || $dumped_core ) { return 0; }
  if ( $dumped_core ) { return 0; }
 
  return 1;
}
 
sub createFileSystemEntropy {
	my $currentDate = time();
	if(! -d "/usr/backuptest")
		{
		system("mkdir /usr/backuptest");
		}
        if(! -d "/backuptest")
                {
                system("mkdir /backuptest");
                }
        if(! -d "/var/backuptest")
                {
                system("mkdir /var/backuptest");
                }
        if(! -d "/www/backuptest" && -d "/www")
                {
                system("mkdir /www/backuptest");
                }
 
	system("/bin/touch /usr/backuptest/$currentDate");
	system("/bin/touch /backuptest/$currentDate");
	system("/bin/touch /var/backuptest/$currentDate");
	if( -d "/www")
		{
		system("/bin/touch /www/backuptest/$currentDate");
		}
}
