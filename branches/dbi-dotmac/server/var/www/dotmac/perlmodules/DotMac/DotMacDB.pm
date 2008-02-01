package DotMac::DotMacDB;

use strict;
use CGI::Carp;
use Data::Dumper;
#use DotMac::Utils::Rearrange;
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
