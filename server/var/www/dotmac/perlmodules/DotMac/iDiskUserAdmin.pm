#file:DotMac/iDiskUserAdmin.pm
#----------------------

## Copyright (C) 2007 Walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

# TODO: move to perl module
# get global variables from httpd.conf (perlsetvar)
# - my $dbpath = "/var/www/userxml/$user/user.dat";
# - recursiveMKdir should be in DotMac::Commons - when we get to be a perl-module
package DotMac::iDiskUserAdmin;
$DotMac::iDiskUserAdmin::VERSION = '0.1';
use strict;
use warnings;

use Apache2::Const -compile => qw(:common :methods :http);
use HTTPD::UserAdmin;
use CGI qw/:standard/;
use DB_File;
use Encode;#use encoding "utf8";
use DotMac::CommonCode;
use Apache2::RequestRec ();
# retrieve var, set by PerlSetVar in httpd.conf:
# $foo = $r->dir_config('foo');
sub handler
	{
	my $r = shift;
	#use dotMacUserDB (perlsetvar from httpd.conf) for $dbFile
	#my $dotMacUserDB = $r->dir_config('dotMacUserDB');
	my $dbFile = '/var/www/idiskAdmin/foobar.passwd';
	
	my @htfile = (	DBType => 'Text',
					DB     => $dbFile,
					Server => 'apache',
					Encrypt => 'MD5');
	my $userAdmin = new HTTPD::UserAdmin @htfile;
	my @users = $userAdmin->list;
	@users = sort @users;
	print 	header,
			start_html('User management'),
			h1('User management'),
			start_form,
			hidden(-name=>'getset',
					-value=>'get',
					-override=>1),

			table({border=>1},
				TR	(			
					td(
						scrolling_list(-name=>'user',
							-override=>1,
							-values=>\@users,
							-size=>8,
							-onChange => 'this.form.submit()'),
						),
					td( h3("or: ")),
					td(
						
						table({border=>1},
						TR	(
							th({valign=>'TOP',align=>'RIGHT'},"New User"),
							td(textfield(-name=>'newuser', -value=>'', -override=>1, -size=>20)) #-maxlength=>number
							),
						TR	(
							th({valign=>'TOP',align=>'RIGHT'},"Password"),
							td(password_field(-name=>'newpass1', -value=>'', -override=>1, -size=>20)) #-maxlength=>number
							),
						TR	(
							th({valign=>'TOP',align=>'RIGHT'},"Confirm Password"),
							td(password_field(-name=>'newpass2', -value=>'', -override=>1, -size=>20)) #-maxlength=>number
							),
						TR	(
							th({valign=>'TOP',align=>'RIGHT'},"Create!"),
							td(submit(-value=>'yes please')) #-name=>'button_name'
							)
						),#end table
						)
					)
				),
			
			end_form,
			hr;
	
	if (param())
		{
		my $user	= param('user');
		my $getset	= param('getset');
		my $newuser	= param('newuser');
		if ($newuser) {
			#validate if newuser already exists, and then:
			if($userAdmin->exists($newuser))
				{
				print h3("User $newuser already exists"),p,"tick $newuser in the left box for editing";
				return Apache2::Const::OK;
				}
			unless (param('newpass1') eq param('newpass2'))
				{
				print h3("password mismatch");
				return Apache2::Const::OK;
				}
			unless (param('newpass1'))
				{
				print h3("password cannot be empty");
				return Apache2::Const::OK;
				}
			$user = $newuser;
			my $newpass = param('newpass1');
			$userAdmin->add($user, "$user:idisk.mac.com:$newpass")
			}
		if ($getset eq 'get') {
			&get_user ($r, $userAdmin, $user);
			}
		elsif ($getset eq 'set') {
			&set_user ($r, $userAdmin, $user);
			}
		}
	return Apache2::Const::OK;
	}

sub get_user {
	my ($r, $userAdmin, $user) = @_;
	# we already verified if we got sent here by ticking the list or by typing a username
	# a typed username might already exist though
	if($userAdmin->exists($user))
		{
		print h3("edit user $user"),p;
		}
	else
		{
		print h3("create user $user"),p;
		}
	my $dotMacUserDataPath = $r->dir_config('dotMacUserDataPath');
	my $dotMacUdataDBname = $r->dir_config('dotMacUdataDBname');
	unless (-d "$dotMacUserDataPath/$user")
		{
		DotMac::CommonCode::recursiveMKdir ($dotMacUserDataPath, $user);
		}
	my %userData = DotMac::CommonCode::readUserDB("$dotMacUserDataPath/$user/$dotMacUdataDBname", my %attributes);
	

	my $defaultQuota = '';
	if (exists($userData{'quota'})) {$defaultQuota = $userData{'quota'}}
	my $defaultEmail = '';
	if (exists($userData{'email'})) {$defaultEmail = $userData{'email'}}
	print start_form,
		hidden(-name=>'user',
				-value=>$user,
				-override=>1),
		hidden(-name=>'getset',
				-value=>'set',
				-override=>1),
		table({border=>1},
			TR	(
				th({valign=>'TOP',align=>'RIGHT'}, 'quota'),
				td	(popup_menu(-name=>'quota',
							-values=>[qw/0 1048576 2097152 5242880 10485760 15728640 20971520/],
							-labels=>{'0'=>'-',
									'1048576'=>'1GB',
									'2097152'=>'2GB',
									'5242880'=>'5GB',
									'10485760'=>'10GB',
									'15728640'=>'15GB',
									'20971520'=>'20GB'},
							-defaults=> $defaultQuota)
					)
				),
			TR	(
				th({valign=>'TOP',align=>'RIGHT'},"email"),
				td(textfield(-name=>'email', -default=>$defaultEmail, -size=>40)) #-maxlength=>number
				)
			),
		submit,
		end_form,
		hr;
	}

sub set_user {
	my ($r, $userAdmin, $user) = @_;
	my $dotMacUserDataPath = $r->dir_config('dotMacUserDataPath');
	my $dotMacUdataDBname = $r->dir_config('dotMacUdataDBname');
	unless (-d "$dotMacUserDataPath/$user")
		{
		DotMac::CommonCode::recursiveMKdir ($dotMacUserDataPath, $user);
		}
	my %userdata = ();
	$userdata{'quota'} = param('quota');
	$userdata{'email'} = param('email');
	DotMac::CommonCode::writeUserDB("$dotMacUserDataPath/$user/$dotMacUdataDBname", %userdata);
	return get_user($r, $userAdmin, $user);
	}

1;