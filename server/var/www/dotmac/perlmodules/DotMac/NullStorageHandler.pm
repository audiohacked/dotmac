#we shouldn't need this
#http://perl.apache.org/docs/2.0/api/Apache2/RequestRec.html#C_filename_

#upon successfully proxying we can update the file's stat record like:
#$r->finfo(APR::Finfo::stat($filename, APR::Const::FINFO_NORM, $r->pool));
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
