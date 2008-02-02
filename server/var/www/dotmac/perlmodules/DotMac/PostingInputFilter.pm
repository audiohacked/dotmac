package DotMac::PostingInputFilter;
  
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
  
use Apache2::Filter;
  
use Apache2::Const -compile => qw(OK DONE DECLINED);
use Apache2::Log ();
use Apache2::RequestRec ();
use constant BUFF_LEN => 8000;
use Data::Dumper;
  
sub handler {
	my $f = shift;
	my $buffer;
	my $logging = $f->r->dir_config('LoggingTypes');
	my $data = $f->r->pnotes('postdata');
	unless ($f->ctx) {
		$f->r->headers_in->unset('Content-Length');
		$f->ctx(1);
	}
	while ($f->read(my $buffer, BUFF_LEN)) {
	}
	$logging =~ m/Sections/&&$f->r->log->info("In PostingInputFilter "); #.$f->r->as_string()." ".Dumper($f->r->pnotes));
	$f->print($data);
	$f->print("");
	#$f->r->headers_in->{'Content-Length'}=length($data);
	#$logging =~ m/InputFilterDebug/&&
	$logging =~ m/SubreqDebug/&&$f->r->log->info("Posting Input Filter Data: $data");
	#$f->seen_eos(1);
	return Apache2::Const::OK;
}


1;
