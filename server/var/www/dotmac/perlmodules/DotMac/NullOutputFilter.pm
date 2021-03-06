package DotMac::NullOutputFilter;

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

use Apache2::Const -compile => qw(OK);
use Apache2::Log ();
use Apache2::RequestRec ();
use constant BUFF_LEN => 1024;

sub handler {
    my $f = shift;
    my $logging = $f->r->dir_config('LoggingTypes');

	  $logging =~ m/Sections/&&$f->r->log->info("In NullOutputFilter");
    while ($f->read(my $buffer, BUFF_LEN)) {
			$logging =~ m/OutputFilterDebug/&&$f->r->log->info($buffer);
      	}
	  $logging =~ m/OutputFilterDebug/&&$f->r->log->info("NullOutputFilter: ".$f->r->as_string());	
    return Apache2::Const::OK;
}

sub CaptureOutputFilter {
	my $f = shift;
	my $logging = $f->r->dir_config('LoggingTypes');
	my $content;
	$logging =~ m/Sections/&&$f->r->log->info("In CaptureOutputFilter");
	
	unless ($f->ctx) {
		$f->r->headers_out->unset('Content-Length');
		$f->ctx(1);
		}
	if ($f->r->pnotes('returndata')) {
		$content=$f->r->pnotes('returndata');
	}
	while ($f->read(my $buffer, BUFF_LEN)) {
		$logging =~ m/OutputFilterDebug/&&$f->r->log->info($buffer);
		$content=$content.$buffer;
	}
	#$logging =~ m/OutputFilterDebug/&&$f->r->log->info($f->r->as_string());
#	my $returndata;
#	if ($f->r->pnotes("returndata")){
# 		$returndata=$f->r->pnotes("returndata").$content;
# 	} else {
# 		$returndata=$content;
# 	}
	$f->r->pnotes('returndata',$content);
#	$f->seen_eos(1);
#	if ($f->seen_eos()){
#		$logging =~ m/OutputFilterDebug/&&$f->r->log->info("CaptureOutputFilter Return Data:". $content);
		#$f->remove;
#	}
	return Apache2::Const::OK;

}

1;
