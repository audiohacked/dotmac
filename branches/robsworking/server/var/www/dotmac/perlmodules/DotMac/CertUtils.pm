#file:DotMac/CertUtils.pm
#----------------------

## Copyright (C) 2009 Rob See
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

package DotMac::CertUtils;

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK HTTP_PAYMENT_REQUIRED);

$DotMac::locate::VERSION = '0.1';

#use XML::DOM;
use CGI::Carp; # for neat logging to the error log

sub handler {
	my $r = shift;
	my $content = "Account Error: Account IDisk Inactive";
	carp 'CertUtils got hit'; # the post data
	$r->content_type('text/plain');
#	$r->content_length(length($content));
#	$r->send_http_header;
	if ($r->uri eq "/signing") { $r->print(signing($r));}
	if ($r->uri eq "/archive") { $r->print(archive($r));}
#	$r->custom_response(Apache2::Const::HTTP_PAYMENT_REQUIRED,$content);	

	# none existent users:
#	print ('Account Error: Nonexistent');
	# return Apache2::Const::HTTP_PAYMENT_REQUIRED; # does this give me the spinning pizza of death ?
	return Apache2::Const::OK;
}

sub signing {
		my $r = shift;
		my $logging = $r->dir_config('LoggingTypes');
		my $rlog = $r->log;

		#my $start = [ Time::HiRes::gettimeofday( ) ];
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
		$logging =~ m/CertUtilsPost/&&$rlog->info("Content from Status POST: $my_data");
	
		my $parser = XML::LibXML->new();

		my $xmldata = $parser->parse_string($my_data);
		my $xc = XML::LibXML::XPathContext->new($xmldata);
	### Figure out what we need to do
		my $methodNameNode=$xc->findnodes("//methodCall/methodName");

		my $methodName=$methodNameNode->string_value();
		$logging =~ m/CertUtils/&&$rlog->info($methodNameNode->string_value());
	### Parse the parameters into an array.
		my $userNameNode=$xc->findnodes("//methodCall/params/param/value/string");
			my @valarr;
		while (my $nodehold = $userNameNode->shift()) {
		        push(@valarr,$nodehold->string_value());
				$logging =~ m/CertUtils/&&$rlog->info($nodehold->string_value());
		}
		if ($methodName eq 'sign.dmSharedServices' && $valarr[0] eq 'issue'){
			$rlog->info("Time to Sign the Cert");
			my $csrdir=$r->dir_config('dotMacCertsPath')."/csrs";
			my $csrfile=$csrdir."/".$r->user()."-".time().".csr";
			$rlog->info("Storing to $csrfile");
			open(CSR,">$csrfile");
			print CSR $valarr[1];
			close(CSR);
			chdir($r->dir_config('dotMacCertsPath'));
			my $username=$r->user();
			my $subject="/C=US/O=dotMobile.us/OU=me.com/CN=$username/description=MobileMe Sharing Certificate";
			system("openssl ca -config dotmacssl.cnf -in $csrfile -notext -batch -subj \"$subject\" -out dmSharedServices/$username.crt");
			my $timestamp=time();
			return "
<?xml version=\"1.0\"?>
<methodResponse>
	<params>
		<param>
			<value>
				<struct>
					<member>
						<name>resultCode</name>
						<value>SuccessQueued</value>
					</member>
					<member>
						<name>timestamp</name>
						<value>$timestamp</value>
					</member>
					<member>
						<name>resultBody</name>
						<value>20</value>
					</member>
				</struct>
			</value>
		</param>
	</params>
</methodResponse>
";
		}
		
	}

	sub archive {
			my $r = shift;
			my $logging = $r->dir_config('LoggingTypes');
			my $rlog = $r->log;

			#my $start = [ Time::HiRes::gettimeofday( ) ];
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
			$logging =~ m/CertUtilsPost/&&$rlog->info("Content from Archive POST: $my_data");

			my $parser = XML::LibXML->new();

			my $xmldata = $parser->parse_string($my_data);
			my $xc = XML::LibXML::XPathContext->new($xmldata);
		### Figure out what we need to do
			my $methodNameNode=$xc->findnodes("//methodCall/methodName");

			my $methodName=$methodNameNode->string_value();
			$logging =~ m/CertUtils/&&$rlog->info($methodNameNode->string_value());
		### Parse the parameters into an array.
			my $userNameNode=$xc->findnodes("//methodCall/params/param/value/string");
				my @valarr;
			while (my $nodehold = $userNameNode->shift()) {
			        push(@valarr,$nodehold->string_value());
					$logging =~ m/CertUtils/&&$rlog->info($nodehold->string_value());
			}
			if ($methodName eq 'archive.save'){
				$rlog->info("Time to Save the PKCS12File");
				my $pkcs12dir=$r->dir_config('dotMacCertsPath')."/pkcs12";
				my $pkcs12file=$pkcs12dir."/".$r->user().".pkcs12";
				$rlog->info("Storing to $pkcs12file");
				open(PKCS12,">$pkcs12file");
				print PKCS12 $valarr[1];
				close(PKCS12);
				chdir($r->dir_config('dotMacCertsPath'));
				my $timestamp=time();
				return "
	<?xml version=\"1.0\"?>
	<methodResponse>
		<params>
			<param>
				<value>
					<struct>
						<member>
							<name>resultCode</name>
							<value>Success</value>
						</member>
						<member>
							<name>resultBody</name>
							<value>20</value>
						</member>
					</struct>
				</value>
			</param>
		</params>
	</methodResponse>
	";
			} elsif ($methodName eq 'archive.remove') {
				$rlog->info("Time to Save the PKCS12File");
				my $pkcs12dir=$r->dir_config('dotMacCertsPath')."/pkcs12";
				my $pkcs12file=$pkcs12dir."/".$r->user().".pkcs12";
				unlink($pkcs12file);
							return "
				<?xml version=\"1.0\"?>
				<methodResponse>
					<params>
						<param>
							<value>
								<struct>
									<member>
										<name>resultCode</name>
										<value>Success</value>
									</member>
									<member>
										<name>resultBody</name>
										<value>20</value>
									</member>
								</struct>
							</value>
						</param>
					</params>
				</methodResponse>
				";
			}

		}
1;
