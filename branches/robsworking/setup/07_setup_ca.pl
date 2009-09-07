#!/usr/bin/perl


sub readConf {
                my $filetoread;
                my $line;
        if (-f "/etc/dotmobile.us/conf" ) {
                $filetoread="/etc/dotmobile.us/conf";
                print "Reading Config file from $filetoread\n";
         } else {
                print "No config file found, Exiting... (Did you run setup/02_setup.pl ?)";
                exit(1);
        }
        open(CONF,"<$filetoread");
        my @tmparr;
        my $varhash={};
        while ($line=<CONF>){
                chomp($line);
                if ($line =~ /.*=.*/) {
                        @tmparr=split(/=/,$line);
                        $varhash->{@tmparr[0]}=@tmparr[1];
                }
        }
        return $varhash;
}

use strict;


my $conf=readConf();
my $root=$conf->{'DOTMOBILEROOT'};
my $certsdir=$root."/certs";



print "After this script finished you must chown the dotmacCA directory to your webserver user\n";
my $openssl='openssl';
my $CATOP="$certsdir/dotmacCA";
my $SSLEAY_CONFIG="$certsdir/dotmacssl.cnf";

my $DAYS="-days 365";      # 1 year
my $CADAYS="-days 10095";   # 3 years
my $REQ="$openssl req -config $SSLEAY_CONFIG";
my $CA="$openssl ca -config $SSLEAY_CONFIG";
my $VERIFY="$openssl verify";
my $X509="$openssl x509 -config $SSLEAY_CONFIG";
my $PKCS12="$openssl pkcs12 -config $SSLEAY_CONFIG";


my $CAKEY="cakey.pem";
my $CAREQ="careq.pem";
my $CACERT="cacert.pem";
my $DIRMODE="755";
my $NEW="1";
my $FILE;
my $RET;

if (-d $CATOP) {
	print "It appears you alredy have a CA setup, we won't overwrite it. If you want to create a new one, delete $CATOP first\n";
#	exit(1);
}

print "Rewriting dotmacssl.cnf to contain the correct path\n";
`perl -p -i -e "s|^dir.*|dir = $CATOP|" $SSLEAY_CONFIG `;

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

                    system ("$CA -create_serial " .
                        "-out ${CATOP}/$CACERT $CADAYS -batch " . 
                        "-keyfile ${CATOP}/private/$CAKEY -selfsign " .
                        "-extensions v3_ca " .
                        "-infiles ${CATOP}/$CAREQ ");
                    $RET=$?;
            
		 `cp ${CATOP}/$CACERT $root/idisk/dotMacCA.pem`

