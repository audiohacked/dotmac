#file:DotMac/DMXWebdavMethods.pm
#--------------------------------
package DotMac::DMXWebdavMethods;

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => 'OK';
use CGI::Carp;
use DotMac::CommonCode;

sub handler
	{
	carp "DMMKPATH_handler active!";
	my $r = shift;
	my $rmethod = $r->method;
	my $user = $r->user;
	my $XWebdavMethod = $r->header_in('X-Webdav-Method');
	if ($XWebdavMethod eq 'DMMKPATH')
		{
		carp "DMMKPATH_handler DMMKPATH!";
		my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');
		DotMac::CommonCode::recursiveMKdir($dotMaciDiskPath, $r->uri);
		$r->content_type('text/plain');
		$r->print("");
		
		return Apache2::Const::OK;
		}
	}

1;