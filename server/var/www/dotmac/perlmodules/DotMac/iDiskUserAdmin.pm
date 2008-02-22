#file:DotMac/iDiskUserAdmin.pm
#----------------------

## Copyright (C) 2007 Walinsky, Sean Nelson 
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
use DotMac::DotMacDB;
use Data::Dumper;
use CGI::Carp;

# retrieve var, set by PerlSetVar in httpd.conf:
# $foo = $r->dir_config('foo');
sub handler
	{
	my $r = shift;
	my $realm = $r->dir_config('dotMacRealm');
	#If you really want to use this, uncomment the following line - and comment-out the next one
	#Note: adapt your dotmac.conf in a way that this page _need_ a (secure) login!!!

	my $dbadmin = DotMac::DotMacDB->new();

	my @users = $dbadmin->list_users($realm);
	
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
			my $user_exists = 0;
			for (@users) { 
				$user_exists = 1 if ($_ eq $newuser);
			}
			if($user_exists)
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
			$dbadmin->add_user($user, $newpass, $realm);

			}
		if ($getset eq 'get') {
			&get_user ($r, $user);
			}
		elsif ($getset eq 'set') {
			&set_user ($r, $user);
			}
		}
	return Apache2::Const::OK;
	}

sub get_user {
	my ($r, $user) = @_;
	my $realm = $r->dir_config('dotMacRealm');

	my $dbadmin = DotMac::DotMacDB->new();

	my @users = $dbadmin->list_users($realm);
	
	# we already verified if we got sent here by ticking the list or by typing a username
	# a typed username might already exist though
	my $user_exists = 0;
	for (@users) { 
		$user_exists = 1 if ($_ eq $user);
	}
	if($user_exists)
		{
		print h3("edit user $user"),p;
		}
	else
		{
		print h3("create user $user"),p;
		}
	
	my ($defaultQuota, $defaultEmail) = $dbadmin->fetch_user_info($user, $realm);
		
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
                  -values=>[qw/0 1048576 2097152 5242880 10485760 15728640 20971520 104857600 157286400 209715200 419430400 524288000 629145600 734003200 786432000/],
                  -labels=>{'0'=>'-',                                                     
							'1048576'=>'1GB',                                                                       
							'2097152'=>'2GB',                                                                       
							'5242880'=>'5GB',                                                                       
							'10485760'=>'10GB',                                                                       
							'15728640'=>'15GB',                                                                       
							'20971520'=>'20GB',                                                                       
							'104857600'=>'100GB',                                                                       
							'157286400'=>'15G0B',                                                                       
							'209715200'=>'200GB',                                                                       
							'419430400'=>'400GB',                                                                       
							'524288000'=>'500GB',                                                                       
							'629145600'=>'600GB',                                                                       
							'734003200'=>'700GB',
							'786432000'=>'750GB'},
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
	my ($r, $user) = @_;
	my $quota = param('quota');
	my $email = param('email');
	my $realm = $r->dir_config('dotMacRealm');

	my $dbadmin = DotMac::DotMacDB->new();

	$dbadmin->update_user_info($user,$email,$quota,$realm);

	return get_user($r, $user);
	}

1;
