  package DotMac::NullOutputFilter;
  
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
  	  $logging =~ m/OutputFilterDebug/&&$f->r->log->info($f->r->as_string());	
      return Apache2::Const::OK;
  }
  1;