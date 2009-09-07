#!/usr/bin/perl


use Cwd;
use File::Copy;
use Data::Dumper;
use strict;

sub readQuestions {
### Read in the questions file so we know what to ask
### Question format is VARNAME,TYPE(T=Text,B=Bool),Default,Question
	my @questionsarr;
	open(QUESTIONS,getcwd()."/.questions");
	my $line;
	while ($line=<QUESTIONS>) {
		chomp $line;
		my @tmparr=split(/\|/,$line);
		push(@questionsarr,\@tmparr);
	}
	return \@questionsarr;
}


sub readConf {
		my $filetoread;
		my $line;
	if (-f "/etc/dotmobile.us/conf" ) {
		$filetoread="/etc/dotmobile.us/conf";
		print "Reading Config file from $filetoread\n";
	} elsif (-f getcwd()."/conf.new" ) {
		$filetoread=getcwd()."/conf.new";
		print "Reading Config file from $filetoread\n";		
	} else {
		print "No config file found, starting from scratch";
		return;
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

sub writeconf{
	my ($conf) = @_; 
	my $fileToWrite=getcwd()."/conf.new";
	open(CONF,">$fileToWrite");
	my $key;
	foreach $key (keys(%$conf)){
		print CONF $key."=".$conf->{$key}."\n";
	}
	close(CONF);
	print "Writing out config file\n\n";
}


print "----------------------------------------------\n";
print "-Server Config Setup Script                  -\n";
print "-dotMobile.us Project                        -\n";
print "-http://dotmac.googlecode.com                -\n";
print "----------------------------------------------\n";
print "\n";
print "\n";
print "This script will ask you a series of questions about how your dotmac\n";
print "server will be setup. If you can't answer them all, you may start from\n";
print "the beginning. After this, you will need to run 03_configure_dotmac.conf\n";
print "from this directory\n";

print "\n";
print "\n";

if (-e getcwd()."/.setupdir") {
	print "Good, you are running from the setup directory\n";
}else {
	print "Error: you are not in the correct directory. These must be run from the setup directory\n";
	exit(1);
}

print "Clearing Temp config file\n";
unlink (getcwd()."/conf.tmp");

my $questions=readQuestions();
my $currconf=readConf();

print "\n\nStarting to ask questions:\n\n";
my $question;
foreach $question (@$questions){
	print $question->[3]."\n";
	if ($currconf->{$question->[0]}) {
		print "Current Value=".$currconf->{$question->[0]}."\n\n";
	}
	my $response=<STDIN>;
	chomp $response;
	if ($response eq "") {
		$response = $currconf->{$question->[0]};
	}

	if ($question->[1] eq "B") {
		if ($response =~ /[Yy][Ee]?[Ss]?/){
			$response="YES";
		} elsif ($response =~ /[Nn][Oo]?/) {
			$response="NO";
		} else {
			print "\n\nIncorrect Value, try again:\n\n";
			redo;
		}
	}
	
	if ($response eq "") {
		"Incorrect Value, try again:\n\n";
		redo;
	}
	$currconf->{$question->[0]}=$response;
}
writeconf($currconf);
print "\n\nNOTE....\n";
print "You will need to copy conf.new to /etc/dotmobile.us/conf\n\n";


