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
Embperl
"
echo "Checking Perl Modules"
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
exit 1
else
	echo "Good::: All of the required perl modules are installed"
fi
echo
echo
echo "Checking for Commands"

REQUIRED_COMMANDS="
wget
curl
sqlite3
"

ERRORCOUNT=0
for X in ${REQUIRED_COMMANDS}; do
	which ${X} >/dev/null
	if [ $? != 0 ] ; then
		echo "Not Installed: ${X} "
		ERRORCOUNT=$(($ERRORCOUNT+1));
	else 
		echo "Installed: ${X}"
	fi
done
if [ ${ERRORCOUNT} != 0 ] ; then
	echo "Bad::: There are $ERRORCOUNT missing commands. dotMobile.us will not run correctly until this is fixed."
exit 1
else
	echo "Good::: All of the required commands are installed"
fi


