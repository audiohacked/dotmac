package DotMac::DMStatusLogger;

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
use Apache2::URI ();

use Apache2::Const -compile => qw(:methods DECLINED);
use APR::Const    -compile => qw(:error SUCCESS);
use CGI::Carp;
use DotMac::CommonCode;


sub handler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	carp $r->as_string();
	writeDeltaRecord($r) if (($r->method() eq "PUT") && ($r->header_in('Content-Length') > 0));
		
	if (($r->method() eq "DELETE") || ($r->method() eq "MOVE") || ($r->method() eq "MKCOL")) {
		writeDeltaRecord($r);
	}
}
	
sub writeDeltaRecord {
		my $r = shift;
		my $opcode="";
		my $source="";
		my $target="";
		my $user = $r->user();
		my $dbargs = {	AutoCommit => 1, 
						PrintError => 1};

	
		if ($r->method() eq "MOVE") { 
			$opcode="MOV";
			$source=$r->uri;
			$target=$r->headers_in->{'Destination'};
			$target =~ m|http[s]{0,1}://([a-zA-Z0-9\.]*)(/.*)|;
			$target = $2;		
		} elsif ($r->method() eq "PUT") {
			$opcode="PUT";
			$source=$r->uri;
		} elsif ($r->method() eq "DELETE") {
			$opcode="DEL";
			$source=$r->uri;
		} elsif ($r->method() eq "MKCOL") {
			$opcode="MKD";
			$source=$r->uri;
		} else {
			$r->log->info("writeDeltaRecord: unhandled opcode");
			return;
		}
		my $dmdb = DotMac::DotMacDB->new();
		$dmdb->write_delta_record($user, $opcode, $source, $target);
		return 1;

}

1;
