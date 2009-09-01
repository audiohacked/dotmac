package DotMobileAdmin::main;




use strict;
use warnings;
use CGI;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK HTTP_PAYMENT_REQUIRED);
use CGI::FastTemplate;
use HTML::Template;
use Embperl;
$DotMobileAdmin::locate::VERSION = '0.1';


sub handler {
	my $r = shift;
	$r->content_type('text/html');
	
#	my $tpl = new CGI::FastTemplate();
	$ENV{'HTML_TEMPLATE_ROOT'} = $r->dir_config('dotMacPerlmodulesPath')."/DotMobileAdmin/templates";
	my @idiskuserstat=stat($r->dir_config('dotMacPrivatePath')."/dotmac.pid");
    #print "<br />";
    
	our $lastrestart=scalar localtime($idiskuserstat[9]);
	my $tplpath = $r->dir_config('dotMacPerlmodulesPath')."/DotMobileAdmin/templates/";
#	$tpl->define( main => "main.tpl",
#				  users => "users.tpl" );
	
#	my $template = HTML::Template->new(filename => 'main.tpl');
	my $out;
	Embperl::Execute({inputfile => $tplpath.'main.tpl', output => \$out} );
	
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
