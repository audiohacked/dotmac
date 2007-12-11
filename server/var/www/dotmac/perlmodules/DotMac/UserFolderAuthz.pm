#file:DotMac/UserFolderAuthz.pm
#------------------------------------
package DotMac::UserFolderAuthz;

use strict;
use warnings;

use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED DECLINED);


# TODO: give a 200 OK if just HEAD request
# was it a HEAD request?
# $status = $r->header_only();

sub handler {
	my $r = shift;
#	carp $r->as_string();
	my $user = $r->user;
	if ($user) {
		# check for either /user/...anystring... or /user
		if(($r->uri =~ m/^\/$user\//) or ($r->uri eq "/$user"))
			{
			return Apache2::Const::OK;
			}
		elsif ($r->uri eq "/osxSharedSecret") #Leopard contacts us here WITH username/password
			{
			return Apache2::Const::OK;
			}
		#we might wanna throw in a elsif here, for checking public folders
		}
	elsif ($r->uri =~ m/^\/locate/)
		{
		return Apache2::Const::OK;
		}
	
	$r->note_basic_auth_failure;
	return Apache2::Const::HTTP_UNAUTHORIZED;
}

1;

#			my $location = $r->location();
#			my $directory = join '/', ('', $r->document_root, $user);
#			carp "location $location; directory $directory";
#			$r->add_config(["<Directory $directory>",
#							'AuthType Digest',
#							'AuthName idisk.mac.com',
#							'AuthDigestProvider file',
#							'AuthUserFile /etc/httpd/auth/webdav/iDiskUsers',
#							'Dav on',
#							'DavDepthInfinity on',
#							'DAVSATMaxAreaSize 1024000',
#							'Options All +Indexes',
#							'<Limit GET HEAD OPTIONS PUT POST COPY PROPFIND DELETE LOCK MKCOL MOVE PROPPATCH UNLOCK ACL>',
#								"Require user $user",
#							'</Limit>',
#							'</Directory>'
#							], -1);