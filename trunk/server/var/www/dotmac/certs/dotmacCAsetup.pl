#!/usr/bin/perl

use strict;

print "After this script finished you must chown the dotmacCA directory to your webserver user\n";
my $capassword="1234"; #great now I have to change the combination on my luggage
my $openssl='openssl';
my $SSLEAY_CONFIG="./dotmacssl.cnf";
my $DAYS="-days 365";      # 1 year
my $CADAYS="-days 10095";   # 3 years
my $REQ="$openssl req -config $SSLEAY_CONFIG";
my $CA="$openssl ca -config $SSLEAY_CONFIG";
my $VERIFY="$openssl verify";
my $X509="$openssl x509 -config $SSLEAY_CONFIG";
my $PKCS12="$openssl pkcs12 -config $SSLEAY_CONFIG";

my $CATOP="./dotmacCA";
my $CAKEY="cakey.pem";
my $CAREQ="careq.pem";
my $CACERT="cacert.pem";
my $DIRMODE="755";
my $NEW="1";
my $FILE;
my $RET;
umask(077);
          if ( "$NEW" || ! -f "${CATOP}/serial" ) {
                # create the directory hierarchy
                mkdir $CATOP;
                mkdir "${CATOP}/certs";
                mkdir "${CATOP}/crl";
                mkdir "${CATOP}/newcerts";
                mkdir "${CATOP}/private";
                open OUT, ">${CATOP}/index.txt";
                close OUT;
                open OUT, ">${CATOP}/crlnumber";
                print OUT "01\n";
                close OUT;
            }
                    print "Making CA certificate ...\n";
                    system ("$REQ -new -nodes -keyout " .
                        "${CATOP}/private/$CAKEY -out ${CATOP}/$CAREQ");

                    print ("$REQ -new -nodes -keyout " .
                        "${CATOP}/private/$CAKEY -out ${CATOP}/$CAREQ");
                    system ("$CA -create_serial " .
                        "-out ${CATOP}/$CACERT $CADAYS -batch " . 
                        "-keyfile ${CATOP}/private/$CAKEY -selfsign " .
                        "-extensions v3_ca " .
                        "-infiles ${CATOP}/$CAREQ ");
                    $RET=$?;
            
		 `cp ${CATOP}/$CACERT ../idisk/dotMacCA.pem`

