#!/usr/bin/perl

sub readConf {
                my $filetoread;
                my $line;
        if (-f "/etc/dotmobile.us/conf" ) {
                $filetoread="/etc/dotmobile.us/conf";
                print "Reading Config file from $filetoread\n";
         } else {
                print "No config file found, Exiting... (Did you run setup/02_setup.pl ?)";
                exit(1);
        }
        open(CONF,"<$filetoread");
        my @tmparr;
        my $varhash={};
        while ($line=<CONF>){
                chomp($line);
                if ($line =~ /.*=.*/) {
                        @tmparr=split(/=/,$line);
                        $varhash->{@tmparr[0]}=@tmparr[1];
                }
        }
        return $varhash;
}

use strict;


my $conf=readConf();

open(PASSWORD,"</etc/passwd");

	print "Scanning password file for what appears to be the user apache runs as\n";

my @possibilities;
my $line;
my @fields;
while($line=<PASSWORD>) {

	chomp $line;
	@fields=split(/:/,$line);
	if ($fields[0] =~ /^apache(.*)/) {
		push(@possibilities,$fields[0]);

	} elsif ($fields[0] =~ /^www-data(.*)/) {
		push(@possibilities,$fields[0]);

	} elsif ($fields[0] =~ /^httpd(.*)/) {
		push(@possibilities,$fields[0]);
	}

}

print "Found ".scalar @possibilities." possibilities\n";
my $possibility;
foreach $possibility (@possibilities) {
	print "$possibility\n";
}
my $choice;
my $input;
if (scalar @possibilities ==1 ) {
	print "Since we only found one possibility, do you want to use that one ? (Y/N)\n";
	$input = <STDIN>;
	if ($input =~ /[Yy][Ee]?[Ss]?/) {
		$choice = $possibilities[0] 
	} else {
		print "Please input the account that apache run as: \n";
		$choice = <STDIN>;
	}
} elsif (scalar @possibilities > 1){
	print "We found more than one option, please choose which one you would like to use ?\n ";
	$choice = <STDIN>;
} else { ### Less than one choice  
	print "We didn't find any of the usual users. If you are sure apache is correctly installed, please type which user you want to use\n";
	$choice = <STDIN>;
}

chomp $choice;

print "Using $choice as user account for dotMobile.us ownership\n";


my $root=$conf->{'DOTMOBILEROOT'};

my @dirToApache = qw/idisk cache private userxml locks configuration certs/;

my $dirName;
foreach $dirName (@dirToApache) {
	print "Changing ownership of $root/$dirName to $choice recursively\n";
	`chown -R $choice $root/$dirName`;
}

print "Finding .svn directories from the idisk directory\n";
my $output=`find $root/idisk -type d -name .svn -exec ls -R \{\} \\\;`;	
print "The following .svn directories should be removed from the idisk tree so that they aren't included in syncing\n";
print $output;
print "\nDo you want to do this (Y/N)\n";
$input=<STDIN>;
if ($input =~ /[Yy][Ee]?[Ss]?/) {
	$output=`find $root/idisk -type d -name .svn -exec rm -r \{\} \\\;`;	
	print "\nDONE\n";
}
