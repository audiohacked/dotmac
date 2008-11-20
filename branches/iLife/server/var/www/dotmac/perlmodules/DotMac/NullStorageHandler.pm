package DotMac::NullStorageHandler;
  
  use strict;
  use warnings FATAL => 'all';
  
  use Apache2::Const -compile => qw(OK);
  
sub handler {
      my $r = shift;
  
      # skip ap_directory_walk stat() calls
      return Apache2::Const::OK;
}
1;
