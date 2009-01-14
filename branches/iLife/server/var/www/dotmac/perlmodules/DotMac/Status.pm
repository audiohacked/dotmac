#file:DotMac/Status.pm
#----------------------

## Copyright (C) 2007 Walinsky, Robert See
## This file is part of dotMac. 

## dotMac is free software: you can redistribute it and/or modify
## it under the terms of the Affero GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## dotMac is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## Affero GNU General Public License for more details.

## You should have received a copy of the Affero GNU General Public License
## along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

## TODO:
## put the xml parsing/processing in a sub
## enable a debug mode (globally for al dotmac perl modules)
## verify if the timestamps we send are correct; is it always _current time_ that we need to provide?


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

use CGI::Carp;

use DotMac::CommonCode;
use Time::HiRes;
use Data::Dumper;
$DotMac::Status::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	
	my $start = [ Time::HiRes::gettimeofday( ) ];
	my $answer = "";
	my $my_data = "";
	# we should check if it's a post message
	my $length=$r->headers_in->{'Content-Length'};
	if ($r->method() eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $length)) {
			$my_data .= $buf;
			}
		}
	$logging =~ m/StatusPost/&&$rlog->info("Content from Status POST: $my_data");

	my $parser = XML::LibXML->new();
	
	my $xmldata = $parser->parse_string($my_data);
	my $xc = XML::LibXML::XPathContext->new($xmldata);
### Figure out what we need to do
	my $methodNameNode=$xc->findnodes("//methodCall/methodName");

	my $methodName=$methodNameNode->string_value();
### Parse the parameters into an array.
	my $userNameNode=$xc->findnodes("//methodCall/params/param/value/string");
	
	my @valarr;
	while (my $nodehold = $userNameNode->shift()) {
	        push(@valarr,$nodehold->string_value());
	}
### Verify the username (1st parameter) against what was passed in 
	if ($valarr[0] ne $r->user ){
		$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>";
		$rlog->info("Username passed in method doesn't match authenticated user: ".$r->user);
	} elsif ($methodName eq "status.rootFolders") {
		$answer = rootfolders($r,\@valarr);
	} elsif ($methodName eq "status.timestamp") {
		$answer = timestamp($r,\@valarr);
	} elsif ($methodName eq "status.options") {
		$answer = options($r,\@valarr);
	} elsif ($methodName eq "status.query") {
		$answer = statquery($r,\@valarr);			
			#$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>clientIsCurrent</value></member><member><name>timestamp</name><value>$HexTimeStamp</value></member><member><name>resultType</name><value>Query</value></member></struct></value></param></params></methodResponse>";
	} else {
			## string we don't know what to do with
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>";
			$rlog->info("don't know how to handle string: $my_data");
	}
	
	# set up HTML page
	# print "Content-Type: text/xml\n\n";
	$r->content_type('text/xml');
	$r->headers_out->{'Content-Length'}=length $answer;
	$r->headers_out->{'X-dmUser'}="status";
	$r->headers_out->{'Server'}="AppleDotMacServer-1B5608";
	$r->headers_out->{'x-responding-server'}="idiskng017";
	$r->print($answer);

	return Apache2::Const::OK;
}

sub statquery {
	my($r, $valarr)=@_;
	carp Dumper($valarr);
#	$r->log("blah1".dumper($valarr));
	my $queryts=hex($valarr->[2])/1000;
	carp $queryts;
	my $TimeStamp = time();
	my $paddedTimestamp = $TimeStamp * 1000;
	my $HexTimeStamp = DotMac::CommonCode::dec2hex($paddedTimestamp);
	my $datarecords=DotMac::CommonCode::returnDeltaRecords($r, $queryts);
	my $str="Blah : ".Dumper($datarecords);
	#$r->log->info($str);
	my $begin = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>changeInformation</name><value><array><data>";


my $middle;
my @array=@$datarecords;
while (my $record = shift(@array)) {
	$middle=$middle."<struct>";
	my $ts=$$record[4]*1000;
	my $username = $$record[0];
	$$record[2] =~ m/^\/$username(.*)/;
	my $source = $1;
	$middle=$middle."<member><name>timestamp</name><value>".$ts."</value></member>";
	$middle=$middle."<member><name>source</name><value>".$source."</value></member>";
	$middle=$middle."<member><name>opcode</name><value>".$$record[1]."</value></member>";
	if ($$record[1] eq "MOV") {
		$$record[3] =~ m/^\/$username(.*)/;
		my $dest = $1;
		$middle=$middle."<member><name>target</name><value>".$dest."</value></member>";
	}
	$middle=$middle."</struct>";
}

                                        
 my $end= "</data></array></value></member><member><name>resultCode</name><value>changeInformation</value></member><member><name>timestamp</name><value>$HexTimeStamp</value></member><member><name>resultType</name><value>Query</value></member></struct></value></param></params></methodResponse>";

		return $begin.$middle.$end;
}

sub timestamp {
	my $TimeStamp = time();
	my $paddedTimestamp = $TimeStamp * 1000 - 1000;
	my $HexTimeStamp = DotMac::CommonCode::dec2hex($paddedTimestamp);
	my $answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>Success</value></member><member><name>timestamp</name><value>$HexTimeStamp</value></member><member><name>resultType</name><value>Timestamp</value></member></struct></value></param></params></methodResponse>";
	return $answer;
}

sub rootfolders {
	my $TimeStamp = time();
	my $paddedTimestamp = $TimeStamp * 1000;
	my $HexTimeStamp = DotMac::CommonCode::dec2hex($paddedTimestamp);
	my $answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
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
		<member><name>timestamp</name><value>$HexTimeStamp</value></member>
		<member><name>resultType</name><value>rootFolders</value></member>
	</struct></value>
</param></params>
</methodResponse>";
	return $answer;
}
sub options {
		my $TimeStamp = time();
		my $paddedTimestamp = $TimeStamp * 1000;
		my $HexTimeStamp = DotMac::CommonCode::dec2hex($paddedTimestamp);
		my $answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
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
	return $answer;
}

1;
