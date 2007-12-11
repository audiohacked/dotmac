#file:DotMac/Status.pm
#----------------------

## Copyright (C) 2007 walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

## TODO:
## put the xml parsing/processing in a sub
## enable a debug mode (globally for al dotmac perl modules)
## verify if the timestamps we send are correct; is it always _current time_ that we need to provide


##  <methodCall>
##    <methodName>status.rootFolders</methodName>
##    <params>
##      <param>
##          <value>
##            <string>waling</string>
##          </value>
##      </param>
##    </params>
##  </methodCall>

##  <methodCall>
##    <methodName>status.timestamp</methodName>
##    <params>
##      <param>
##          <value>
##            <string>waling</string>
##          </value>
##      </param>
##    </params>
##  </methodCall>

##  <methodCall>
##    <methodName>status.options</methodName>
##    <params>
##      <param>
##          <value>
##            <string>waling</string>
##          </value>
##      </param>
##    </params>
##  </methodCall>

##  <methodCall>
##    <methodName>status.query</methodName>
##    <params>
##      <param>
##          <value>
##            <string>waling</string>
##          </value>
##      </param>
##      <param>
##          <value>
##            <string>GUID</string>
##          </value>
##      </param>
##      <param>
##          <value>
##            <string>112d99bda88</string>
##          </value>
##      </param>
##    </params>
##  </methodCall>
##gives: <?xml version="1.0" encoding="ISO-8859-1"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>clientIsCurrent</value></member><member><name>timestamp</name><value>112d99bda88</value></member><member><name>resultType</name><value>Query</value></member></struct></value></param></params></methodResponse>

package DotMac::Status;

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK);

$DotMac::Status::VERSION = '0.1';

use XML::DOM;
use CGI::Carp; # for neat logging to the error log

sub handler {
	my $r = shift;
	
	my $TimeStamp = time();
	my $paddedTimestamp = $TimeStamp * 1000;
	my $HexTimeStamp = dec2hex($paddedTimestamp);
	
	use Time::HiRes;
	my $start = [ Time::HiRes::gettimeofday( ) ];
	my $answer = "";
	my $my_data = "";
	# we should check if it's a post message
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		read(STDIN, $my_data, $ENV{'CONTENT_LENGTH'});
		}
	# instantiate parser
	my $xp = new XML::DOM::Parser();
	# parse and create tree
	my $doc = $xp->parse($my_data);
	# get root node
	my $root = $doc->getDocumentElement();
	my $strings = $root->getElementsByTagName("methodName");
	my $n = $strings->getLength;
	for (my $i = 0; $i < $n; $i++)
	 {
		my $string = $strings->item ($i)->getFirstChild()->getData;
		if ($string eq "status.rootFolders") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
			<methodResponse>
			<params><param>
				<value><struct>
					<member><name>resultCode</name><value>Success</value></member>
					<member><name>rootDirectory</name><value><array><data>
						<value><struct>
							<member><name>folderName</name><value>/Documents</value></member>
							<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Movies</value></member>
							<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Music</value></member>
							<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Pictures</value></member>
							<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Public</value></member>
							<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Sites</value></member>
							<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Backup</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Library</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Software</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Shared</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Groups</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/.Groups</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/.FileSync</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/.fseventsd</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Calendars</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
						<value><struct>
							<member><name>folderName</name><value>/Web</value></member>
							<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
						</struct></value>
					</data></array></value></member>
				<member><name>rootFolders</name><value><array><data>
					<value><struct>
						<member><name>folderName</name><value>/Documents</value></member>
						<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Movies</value></member>
						<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Music</value></member>
						<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Pictures</value></member>
						<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Public</value></member>
						<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member><
					/struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Sites</value></member>
						<member><name>ignoreChildren</name><value><boolean>0</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Backup</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Library</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Software</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Shared</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Groups</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/.Groups</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/.FileSync</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/.fseventsd</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Calendars</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
					<value><struct>
						<member><name>folderName</name><value>/Web</value></member>
						<member><name>ignoreChildren</name><value><boolean>1</boolean></value></member>
					</struct></value>
				</data></array></value></member>
				<member><name>timestamp</name><value>$HexTimeStamp</value></member>
				<member><name>resultType</name><value>rootFolders</value></member>
			</struct></value>
		</param></params>
		</methodResponse>";
			}
		elsif ($string eq "status.timestamp") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>Success</value></member><member><name>timestamp</name><value>$HexTimeStamp</value></member><member><name>resultType</name><value>Timestamp</value></member></struct></value></param></params></methodResponse>";
			}
		elsif ($string eq "status.options") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
	<methodResponse>
		<params>
			<param>
				<value>
					<struct>
						<member>
							<name>presumeStaleAfterDays</name>
							<value><int>30</int></value>
						</member>
						<member>
							<name>minimumQueryInterval</name>
							<value><int>36000</int></value>
						</member>
						<member>
							<name>optionsValidityPeriod</name>
							<value><int>600</int></value>
						</member>
						<member>
							<name>resultCode</name>
							<value>Success</value>
						</member>
						<member>
							<name>fullScanMinimum</name>
							<value><int>86400</int></value>
						</member>
						<member>
							<name>Options</name>
							<value>
								<struct>
									<member>
										<name>presumeStaleAfterDays</name>
										<value><int>30</int></value>
									</member>
									<member>
										<name>minimumQueryInterval</name>
										<value><int>36000</int></value>
									</member>
									<member>
										<name>optionsValidityPeriod</name>
										<value><int>600</int></value>
									</member>
									<member>
										<name>fullScanMinimum</name>
										<value><int>86400</int></value>
									</member>
									<member>
										<name>firstWait</name>
										<value><int>5</int></value>
									</member>
									<member>
										<name>refreshWait</name>
										<value><int>2</int></value>
									</member>
								</struct>
							</value>
						</member>
						<member>
							<name>timestamp</name>
							<value>$HexTimeStamp</value>
						</member>
						<member>
							<name>firstWait</name>
							<value><int>5</int></value>
						</member>
						<member>
							<name>refreshWait</name>
							<value><int>2</int></value>
						</member>
						<member>
							<name>resultType</name>
							<value>Options</value>
						</member>
					</struct>
				</value>
			</param>
		</params>
	</methodResponse>";
			}
		elsif ($string eq "status.query") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>clientIsCurrent</value></member><member><name>timestamp</name><value>$HexTimeStamp</value></member><member><name>resultType</name><value>Query</value></member></struct></value></param></params></methodResponse>";
			}
		else {
			## string we don't know what to do with
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>";
			carp "don't know how to handle string: $string";
			}
	 }
	# set up HTML page
	# print "Content-Type: text/xml\n\n";
	$r->content_type('text/xml');
	
	print $answer;

##	debug level logging
	carp $r->as_string(); # the http request
	carp $my_data; # the post data
	carp $answer; # the answer we sent to the client

	return Apache2::Const::OK;
}


 sub dec2hex {
    # parameter passed to
    # the subfunction
    my $decnum = $_[0];
    # the final hex number
    
    #my $hexnum;
    #my $tempval;
    #initialize properly for not getting 'uninitialized value in concatenation (.) or string' error
    my $hexnum = '';
    my $tempval = '';
    
    while ($decnum != 0) {
		# get the remainder (modulus function)
		# by dividing by 16
		$tempval = $decnum % 16;
		# convert to the appropriate letter
		# if the value is greater than 9
		if ($tempval > 9) {
			$tempval = chr($tempval + 87); # 55 for uppercase
			}
		# 'concatenate' the number to 
		# what we have so far in what will
		# be the final variable
		$hexnum = $tempval . $hexnum ;
		# new actually divide by 16, and 
		# keep the integer value of the 
		# answer
		$decnum = int($decnum / 16); 
		# if we cant divide by 16, this is the
		# last step
		if ($decnum < 16) {
			# convert to letters again..
			if ($decnum > 9) {
				$decnum = chr($decnum + 87); # 55 for uppercase
				}
		
			# add this onto the final answer.. 
			# reset decnum variable to zero so loop
			# will exit
			$hexnum = $decnum . $hexnum; 
			$decnum = 0 
			}
		}
    return $hexnum;
    } # end sub


1;