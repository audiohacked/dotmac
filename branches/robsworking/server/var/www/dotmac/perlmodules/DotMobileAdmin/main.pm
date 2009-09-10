package DotMobileAdmin::main;




use strict;
use warnings;
use CGI;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK HTTP_PAYMENT_REQUIRED);
use Embperl;


sub handler {
	my $r = shift;
	$r->content_type('text/html');
	
	my $dotMacPID = $r->dir_config('dotMacPrivatePath')."/dotmac.pid";
	my $dotMacRealm = $r->dir_config('dotMacRealm');
	my @idiskuserstat=stat($r->dir_config('dotMacPrivatePath')."/dotmac.pid");
    #print "<br />";
    
	our $lastrestart=scalar localtime($idiskuserstat[9]);
	my $tplpath = $r->dir_config('dotMacPerlmodulesPath')."/DotMobileAdmin/templates/";

	my $out;
	my $dbadmin = DotMac::DotMacDB->new();
	my @onceusers = $dbadmin->list_users($dotMacRealm);
	my @idisksizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
	my @mailsizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
	my $onceuser;
	my %usagehash;
	foreach $onceuser (@onceusers){
		$usagehash{$onceuser}=getiDiskUsage($onceuser,$r->dir_config('dotMaciDiskPath'));
	}
	
	my $params = { blah => '1',
				  test => '2',
				  dbadmin => $dbadmin,
				  realm => $dotMacRealm,
				  idiskPath => $r->dir_config('dotMaciDiskPath'),
				  idisksizes => @idisksizes,
				  mailsizes => @mailsizes,
				  dotMacPid => $dotMacPID,
				  cgiparam => CGIparamToHash()};
				
    my $subtemplate;

	#Check to make sure m is an allowed value (and an existing template)
	my	$m=CGI::param('m');
	my	@valid_pages=qw/stats adduser server users test/;
	$m="users" if(not exists {map { $_ => 1 } @valid_pages}->{$m});
	
	
	Embperl::Execute({inputfile => $tplpath."$m.tpl",
					  param => [$params,5,6666],
					  output => \$subtemplate });

	Embperl::Execute({inputfile => $tplpath.'main.tpl',
					  param => [$params,$subtemplate],
					  output => \$out} );
					
					
	#, output => \$out
	$r->print($out);
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

1;
