#!/bin/bash

ERRORCOUNT=0

REQUIRED_MODS="
DBI
DBD::SQLite
Crypt::SSLeay
LWP::UserAgent
JSON
Apache::Session::File
DateTime
DateTime::Format::HTTP
POSIX
Compress::Zlib
Image::ExifTool
Imager
HTTPD::UserAdmin
MD5
XML::DOM
HTTP::DAV
XML::LibXML
"

for X in ${REQUIRED_MODS}; do
	perl -M${X} -e 1 2>/dev/null >/dev/null
	if [ $? != 0 ] ; then
		echo "Not Installed: ${X} "
		ERRORCOUNT=$(($ERRORCOUNT+1));
	else 
		echo "Installed: ${X}"
	fi
done
if [ ${ERRORCOUNT} != 0 ] ; then
	echo "Bad::: There are $ERRORCOUNT missing modules. dotMobile.us will not run correctly until this is fixed."
else
	echo "Good::: All of the required perl modules are installed"
fi

