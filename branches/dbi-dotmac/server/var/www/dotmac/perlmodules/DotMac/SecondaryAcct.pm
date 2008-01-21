package DotMac::SecondaryAcct;

## Copyright (C) 2007 Walinsky, Robert See
## This file is part of dotMac. 

## dotMac is free software: you can redistribute it and/or modify
## it under the terms of the Affero GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## dotMac is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## Affero GNU General Public License for more details.

## You should have received a copy of the Affero GNU General Public License
## along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Log;

use Apache2::Const -compile => qw(OK HTTP_CREATED HTTP_NO_CONTENT HTTP_BAD_REQUEST DONE :log);
use APR::Const    -compile => qw(:error SUCCESS);
use CGI::Carp;
use DotMac::CommonCode;

#my %exts = (
#  cgi => ['perl-script',     \&cgi_handler],
#  pl  => ['modperl',         \&pl_handler ],
#  tt  => ['perl-script',     \&tt_handler ],
#  txt => ['default-handler', undef        ],
#);

sub handler {

	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	my $rmethod = $r->method;
	carp $r->as_string();
	my ($content,$buf);
	if ($rmethod eq "POST") {
		my $content_length = $r->header_in('Content-Length');
		if ($content_length > 0) {
			while ($r->read($buf, $content_length)) {
				$content .= $buf;
			}
		#	$logging =~ m/Body/&&
			$rlog->info("Content from POST: $content");
			$r->print("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>kDMRes
ult</name><value><struct></struct></value></member><member><name>kDMErrorCode</name><value><int>0</int></valu
e></member></struct></value></param></params></methodResponse>");
			return Apache2::Const::DONE;
		}

	}
}

1;
