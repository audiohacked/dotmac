package DotMac::DotMacDB;

use strict;
use CGI::Carp;
use Data::Dumper;
#use DotMac::Utils::Rearrange;

sub new {
	carp "new DotMacDB";
	my $self = shift;

    
    my $var_hash={@_};
  	my $db_provider = exists $var_hash->{'provider'} ? $var_hash->{'provider'} : "mysql";
  	
	#my ($db_provider, @args) = rearrange(['provider'], @_);

	my $backend = "DotMac::DotMacDB::\L${db_provider}\E";
	#carp $backend;
	eval "require $backend"; # if $backend->can('new');

	my $this = bless {}, $self;
	$this->{backend} = $backend->new(@_);
	return $this;
}

sub fetch_apache_auth{
	carp "DotMacDB: fetch_apache_auth";
	my $self = shift;
	my ($user, $realm) = @_;


	$realm ||= 'idisk.mac.com';
	return $self->{backend}->fetch_apache_auth($user, $realm); # if $self->{backend}->can('fetch_apache_auth');
}

sub authen_user{
	carp "DotMacDB: authen_user";
	my $self = shift;
	my ($user, $sent_pw, $realm) = @_;

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->authen_user($user, $sent_pw, $realm);# if $self->{backend}->can('authen_user');
}

sub get_user_quota{
	my $self = shift;
	my ($user, $realm) = @_;

	carp "DotMacDB: get_user_quota";

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->get_user_quota($user, $realm);# if $self->{backend}->can('get_user_quota');
}

sub list_users{
	my $self = shift;
	my ($realm) = @_;

	carp "DotMacDB: list_users";

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->list_users($realm);# if $self->{backend}->can('list_users');
}

sub add_user{
	my $self = shift;
	my ($user, $newpass, $realm) = @_;

	carp "DotMacDB: add_user";

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->add_user($user, $newpass, $realm);# if $self->{backend}->can('list_users');
}

sub update_user_info{
	my $self = shift;
	my ($user, $email, $quota, $realm) = @_;
	
	carp "DotMacDB: update_user_info";

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->update_user_info($user, $email, $quota, $realm);# if $self->{backend}->can('list_users');
}

sub fetch_user_info{
	my $self = shift;
	my ($user, $realm) = @_;
	
	carp "DotMacDB: fetch_user_info";

	$realm ||= 'idisk.mac.com';
	return $self->{backend}->fetch_user_info($user, $realm);# if $self->{backend}->can('list_users');
}


sub rearrange {
    my($order,@param) = @_;
    return unless @param;
    my %param;

    if (ref $param[0] eq 'HASH') {
      %param = %{$param[0]};
    } else {
      return @param unless (defined($param[0]) && substr($param[0],0,1) eq '-');

      my $i;
      for ($i=0;$i<@param;$i+=2) {
        $param[$i]=~s/^\-//;     # get rid of initial - if present
        $param[$i]=~tr/a-z/A-Z/; # parameters are upper case
      }

      %param = @param;                # convert into associative array
    }

    my(@return_array);

    local($^W) = 0;
    my($key)='';
    foreach $key (@$order) {
        my($value);
        if (ref($key) eq 'ARRAY') {
            foreach (@$key) {
                last if defined($value);
                $value = $param{$_};
                delete $param{$_};
            }
        } else {
            $value = $param{$key};
            delete $param{$key};
        }
        push(@return_array,$value);
    }
    push (@return_array,{%param}) if %param;
    return @return_array;
}

1;
