package DotMac::DotMacDB;

use strict;
use CGI::Carp;

sub new {
	my ($self, @args) = @_;
	my $db_provider = exists $args{provider} ? $args{provider} : "mysql";

	my $backend = "DotMac::DotMacDB::\L${db_provider}\E";
	eval "require $backend" unless $backend->can('new');

	my $this = bless {}, $self;
	$this->{backend} = $class->new(@args);
	return $this;
}

sub fetch_apache_auth{
	my $self = shift;
	my ($user, $realm) = @_;

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->fetch_apache_auth($user, $realm);
}

sub authen_user{
	my $self = shift;
	my ($user, $sent_pw, $realm) = @_;

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->authen_user($user, $sent_pw, $realm);
}

sub get_user_quota{
	my $self = shift;
	my ($user, $realm) = @_;

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->get_user_quota($user, $realm);
}

sub list_users{
	my $self = shift;
	my ($realm) = @_;

	$realm ||= 'idisk.mac.com';

	return $self->{backend}->list_users($realm);
}
