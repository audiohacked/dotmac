#file:DotMac/PublicFolderAccess.pm
#------------------------------------
package DotMac::PublicFolderAccess;

use strict;
use warnings;

use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED DECLINED);


sub handler {
	my $r = shift;
	# obviously we _do_ need to do some checking here
	return Apache2::Const::OK;
}

1;
