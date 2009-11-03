package DotMobileAdmin::main;




use strict;
use warnings;
use CGI;
use Template;
use Template::Constants qw( :debug );
use Data::Dumper;
use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK HTTP_PAYMENT_REQUIRED);


sub handler {
	my $r = shift;
	$r->content_type('text/html');

	my $dotMacPID = $r->dir_config('dotMacPrivatePath')."/dotmac.pid";
	my $dotMacRealm = $r->dir_config('dotMacRealm');

	my $tplpath = $r->dir_config('dotMacPerlmodulesPath')."/DotMobileAdmin/templates/";
	my $tt = Template->new({INCLUDE_PATH => $tplpath,
							DEBUG => DEBUG_PARSER | DEBUG_PROVIDER,
							EVAL_PERL => 1,
							INTERPOLATE => 1}) || die "$Template::ERROR\n";
	my $out;
	my $dbadmin = DotMac::DotMacDB->new();

	my @idisksizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
	my @mailsizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
	my $onceuser;
	my %usagehash;
	
	my @idiskuserstat=stat($dotMacPID);
	my $lastrestart=scalar localtime($idiskuserstat[9]);

	

	#Check to make sure m is an allowed value (and an existing template)
	my $m=CGI::param('m');
	my	@valid_pages=qw/stats adduser server users test/;
	$m="users" if(not exists {map { $_ => 1 } @valid_pages}->{$m});
	

	my $error;
	my $message;

	my $params=CGIparamToHash();
	my $hash=$params;
	if (($m eq "adduser")&&(CGI::param('createUser') eq 'Create User')) {
		if ($dbadmin->fetch_user_info($params->{'username'},$dotMacRealm)) {
			$error = "User Already Exists";
			$hash=$params;
		} else {
			$params->{'user'}= $params->{'username'};
			$dbadmin->add_user($params->{'username'},$params->{'password'},$dotMacRealm);
			$dbadmin->update_user_info($params,$dotMacRealm);
			if ($dbadmin->fetch_user_info($params->{'username'},$dotMacRealm)){

				$message = " User $params->{'username'} created";

			}
		}	
	} elsif ($m eq "users") {
		if (CGI::param('duid')) {
			$dbadmin->delete_user(CGI::param('duid'),$dotMacRealm);
		} elsif (CGI::param('saveUser') eq 'Save User') {
			if (CGI::param('passwd')) {
				if (CGI::param('passwd') eq CGI::param('passwdver')) {
					$dbadmin->change_password(CGI::param('user'),CGI::param('passwd'),$dotMacRealm);
					$dbadmin->update_user_info(CGIparamToHash(),$dotMacRealm);
				} else {
					$error="Passwords don't match";
				}
			} else {
				$dbadmin->update_user_info(CGIparamToHash(),$dotMacRealm);
			}



		}
		
		
	}
	my @onceusers = $dbadmin->list_users($dotMacRealm);
	foreach $onceuser (@onceusers){
		$usagehash{$onceuser}=getiDiskUsage($onceuser,$r->dir_config('dotMaciDiskPath'));
	}
	
	my $vals = { blah => '1',
				  test => '2',
				  dbadmin => $dbadmin,
				  realm => $dotMacRealm,
				  idiskPath => $r->dir_config('dotMaciDiskPath'),
				  idisksizes => \@idisksizes,
				  mailsizes => \@mailsizes,
				  dotMacPid => $dotMacPID,
				  cgiparam => CGIparamToHash(),
				  lastrestart => $lastrestart,
				  remote_user => $ENV{'REMOTE_USER'},
				  subtemplate => $m.'.tpl',
			      hash => $hash,
				  error => $error,
				  params => $params,
			      message => $message,
				  dbadmin => $dbadmin,
				  users => \@onceusers};

	$tt->process('main.tpl',$vals) || print $tt->error();;
					
	#, output => \$out
	#$r->print($out);
#	carp $$ref;
#	$r->print($template->output);
	return Apache2::Const::OK;
}

sub users {
	my $r=shift;
	my $tpl=shift;
	
	$tpl->parse(SUBPAGE	=> "users");
	$tpl->parse(CONTENT   => "main");
  
	my $ref = $tpl->fetch("CONTENT");
	return $$ref;
}

sub getiDiskUsage
{
   my $user = shift;
   my $idiskPath = shift;
   if(-d $idiskPath."/".$user){
		my $command = "/usr/bin/du -sh ".$idiskPath."/".$user;
        my $usage = `$command`;
   		$usage =~ /(^[0-9KMGkmg.]+).*/;
   		my $val = $1;
		return($val);
   }
   else{
           return('N/A');   
   }
}

sub CGIparamToHash
{
	my @arr = CGI::param();
	my $key;
	my %paramHash;
	foreach $key (@arr){
		$paramHash{$key} = CGI::param($key);
	}
	return \%paramHash;
}


sub humanFileSize
{
    my $size = shift;
	$size = $size * 1024;
    if ($size > 1099511627776)  #   TiB: 1024 GiB
    {
        return sprintf("%.2f TiB", $size / 1099511627776);
    }
    elsif ($size > 1073741824)  #   GiB: 1024 MiB
    {
        return sprintf("%.2f GiB", $size / 1073741824);
    }
    elsif ($size > 1048576)       #   MiB: 1024 KiB
    {
        return sprintf("%.2f MiB", $size / 1048576);
    }
    elsif ($size > 1024)            #   KiB: 1024 B
    {
        return sprintf("%.2f KiB", $size / 1024);
    }
    else                                    #   bytes
    {
        return sprintf("%.2f bytes", $size);
    }
}


1;
