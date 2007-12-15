#file:DotMac/CommonCode.pm
#----------------------

## Copyright (C) 2007 Walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

package DotMac::CommonCode;
$DotMac::CommonCode::VERSION = '0.1';
use strict;
use warnings;

use CGI::Carp;
use DB_File;
use Encode;

sub readUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %database ) {
		$value = Encode::decode("utf-8" , $value);
		$attributes{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	return %attributes
	}

sub writeUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %attributes ) {
		$value = Encode::encode("utf-8" , $value);# encode them utf first; then print
		$database{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	}

sub recursiveMKdir
	{ my ($rootpath, $addpath) = @_;
	my $slash = '/';
	my $adddir;
	# taking off trailing slash
	if (rindex($addpath, $slash) == ((length $addpath)-1)){
		$addpath = substr $addpath, 0, ((length $addpath)-1);
		}
	# setup a loop checking for / and recursively test creating subdirs	
	until (length $addpath == 0) {
		# taking off leading slash
		if (index($addpath, $slash) == 0) {
			$addpath = substr $addpath, 1, length $addpath;
			}
		my $slashpos = index($addpath, $slash);
		if ($slashpos != -1) {
			$adddir = substr $addpath, 0, $slashpos;
			my $leftoverpath = substr $addpath, $slashpos + 1, length $addpath;
			}
		else
			{
			$adddir = $addpath;
			}
		if (!(-d $rootpath.$slash.$adddir))  {
			mkdir ($rootpath.$slash.$adddir, 0777) || die "sorry system is unable to create output directory $rootpath.$slash.$addpath";
			}
		$addpath = substr $addpath, length $adddir, length $addpath;
		$rootpath = $rootpath.$slash.$adddir;
		}
	}

sub authen_user{
	my ($r, $user, $sent_pw) = @_;
	if ($r->dir_config('dotMacDBType') eq 'file')
		{
		return authen_user_file($r, $user, $sent_pw);
		}
	elsif ($r->dir_config('dotMacDBType') eq 'SQL')
		{
		
		}
    }

sub authen_user_file{
	my ($r, $username, $password) = @_;
	carp $r->dir_config('dotMacUserDB');
	my @htfile = (	DBType => 'Text',
				DB     => $r->dir_config('dotMacUserDB'),
				Server => 'apache',
				Encrypt => 'MD5');
	my $user = new HTTPD::UserAdmin @htfile;
	# grab realm:hashedpassword from digest database
	my $info = $user->password($username);
	my($realm, $checksum) = split(":", $info);
	# generate realm:hashedpassword from supplied password
	my $digestpassword =$user->encrypt("$username:$realm:$password");
	if ($info eq $digestpassword) {
		return 1;
		}
	else {
		return 0;
		}
  
    }

sub authen_user_SQL{
      my ($r, $user, $sent_pw) = @_;
      return "Not implemented yet !";
    }

sub get_user_quota{
	my ($r, $user) = @_;
	my $dotMacUserDataPath = $r->dir_config('dotMacUserDataPath');
	my $dotMacUdataDBname = $r->dir_config('dotMacUdataDBname');
	my %userData = DotMac::CommonCode::readUserDB("$dotMacUserDataPath/$user/$dotMacUdataDBname", my %attributes);
	return $userData{'quota'};
	}

sub get_user_quota_used{
	my ($r, $user) = @_;
	my $home_dir = $r->dir_config('dotMaciDiskPath') . "/$user";
	my $quotaUsedBytes = `du -sk $home_dir`; chop($quotaUsedBytes);# query for usage in KiloBytes
	$quotaUsedBytes =~ s/^(\d+)(.*)/$1/;
	return $quotaUsedBytes;
	}


 sub dec2hex {
    # parameter passed to
    # the subfunction
    my $decnum = $_[0];
    # the final hex number
    
    #my $hexnum;
    #my $tempval;
    #initialize properly for not getting 'uninitialized value in concatenation (.) or string' error
    my $hexnum = '';
    my $tempval = '';
    
    while ($decnum != 0) {
		# get the remainder (modulus function)
		# by dividing by 16
		$tempval = $decnum % 16;
		# convert to the appropriate letter
		# if the value is greater than 9
		if ($tempval > 9) {
			$tempval = chr($tempval + 87); # 55 for uppercase
			}
		# 'concatenate' the number to 
		# what we have so far in what will
		# be the final variable
		$hexnum = $tempval . $hexnum ;
		# new actually divide by 16, and 
		# keep the integer value of the 
		# answer
		$decnum = int($decnum / 16); 
		# if we cant divide by 16, this is the
		# last step
		if ($decnum < 16) {
			# convert to letters again..
			if ($decnum > 9) {
				$decnum = chr($decnum + 87); # 55 for uppercase
				}
		
			# add this onto the final answer.. 
			# reset decnum variable to zero so loop
			# will exit
			$hexnum = $decnum . $hexnum; 
			$decnum = 0 
			}
		}
    return $hexnum;
    } # end sub

1;