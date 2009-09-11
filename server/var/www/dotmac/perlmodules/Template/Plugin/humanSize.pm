#============================================================= -*-Perl-*-
#
# Template::Plugin::humanSize
#============================================================================

package Template::Plugin::humanSize;

use strict;
use warnings;
use base 'Template::Plugin';

our $VERSION = 0.01;
our $JOINT   = '&amp;';


#------------------------------------------------------------------------
# new($context, $value)
#
# Constructor method which returns a sub-routine closure for constructing
# complex URL's from a base part and hash of additional parameters.
#------------------------------------------------------------------------

sub new {
    my ($class, $context, $value) = @_;
    return $value;
}


1;
