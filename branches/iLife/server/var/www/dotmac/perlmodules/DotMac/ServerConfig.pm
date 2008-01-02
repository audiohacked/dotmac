#file:DotMac/ServerConfig.pm
#-----------------------------
package DotMac::ServerConfig;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OR_ALL ITERATE);

use Apache2::CmdParms ();
use Apache2::Module ();
use Apache2::Directive ();

my @directives = (
  {
   name         => 'dotMacRootPath',
  },
  {
   name         => 'dotMacDBType',
  },
  {
   name         => 'dotMacUserDB',
  },
  {
   name         => 'dotMaciDiskRootPath',
  },
);
Apache2::Module::add(__PACKAGE__, \@directives);

1;