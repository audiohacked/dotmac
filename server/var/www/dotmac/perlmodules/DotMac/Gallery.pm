package DotMac::Gallery;

## Copyright (C) 2008 Walinsky
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

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);

# $DotMac::Gallery::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $dotMacCachePath = $r->dir_config('dotMacCachePath');
	$r->content_type("text/html");
	$r->sendfile("$dotMacCachePath/gallery.html");
	return Apache2::Const::OK;
	}

sub truthgetHandler {
	my $r = shift;
	my $data = '{"records" : [{}],"data" : {},"status" : 1}';
	$r->content_type("application/json");
	$r->print($data);
	return Apache2::Const::OK;
	}

1;
