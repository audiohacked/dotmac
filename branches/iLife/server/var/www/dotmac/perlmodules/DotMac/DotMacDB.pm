## Copyright (C) 2007 Sean Nelson, Robert See
### This file is part of dotMac.
#
### dotMac is free software: you can redistribute it and/or modify
### it under the terms of the Affero GNU General Public License as published by
### the Free Software Foundation, either version 3 of the License, or
### (at your option) any later version.
#
### dotMac is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### Affero GNU General Public License for more details.
#
### You should have received a copy of the Affero GNU General Public License
### along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
#
#
package DotMac::DotMacDB;

use strict;
use CGI::Carp;
use Data::Dumper;
use Apache2::ServerUtil ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Log;

sub new {
	carp "new DotMacDB";
	my $self = shift;

    
	my $var_hash={@_};
  	my $srv_cfg;
  	my $s = Apache2::ServerUtil->server;
	
	
	if (exists $var_hash->{'cfg_array'}) {
		$srv_cfg = arraytohash($var_hash->{'cfg_array'});
	}else {
		$srv_cfg = $s->dir_config;
	}
	#carp Dumper($srv_cfg);
	my $db_provider = exists $srv_cfg->{'dotMacDBServType'} ? $srv_cfg->{'dotMacDBServType'} : "null";
	my $backend = "DotMac::DotMacDB::\L${db_provider}\E";
	#carp $backend;
	eval "require $backend"; # if $backend->can('new');

	my $this = bless {}, $self;
	$this->{backend} = $backend->new(($srv_cfg));
	#carp Dumper($this->{backend});
	return $this->{backend};
}


sub arraytohash {
	my ($array) = @_;
	my (%cfg_hash,$val);
	foreach $val (@$array) {
		$cfg_hash{$$val[0]} = $$val[1];
	}
	return \%cfg_hash;
}


1;
