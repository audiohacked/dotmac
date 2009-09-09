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
	
#	my $tpl = new CGI::FastTemplate();
	$ENV{'HTML_TEMPLATE_ROOT'} = $r->dir_config('dotMacPerlmodulesPath')."/DotMobileAdmin/templates";
	$ENV{'dotMacPID'} = $r->dir_config('dotMacPrivatePath')."/dotmac.pid";
	$ENV{'dotMacRealm'} = $r->dir_config('dotMacRealm');
	$ENV{'dotMaciDiskPath'} = 
	my @idiskuserstat=stat($r->dir_config('dotMacPrivatePath')."/dotmac.pid");
    #print "<br />";
    
	our $lastrestart=scalar localtime($idiskuserstat[9]);
	my $tplpath = $r->dir_config('dotMacPerlmodulesPath')."/DotMobileAdmin/templates/";

	my $out;
	my $params = { blah => '1',
				  test => '2',
				  dbconn => DotMac::DotMacDB->new(),
				  realm => $r->dir_config('dotMacRealm'),
				  idiskPath => $r->dir_config('dotMaciDiskPath') };
				
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
1;
