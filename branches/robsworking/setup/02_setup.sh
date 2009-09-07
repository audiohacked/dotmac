#!/bin/bash
use Cwd;

echo "----------------------------------------------"
echo "-Server Name Setup Script                    -"
echo "-dotMobile.us Project                        -"
echo "-http://dotmac.googlecode.com                -"
echo "----------------------------------------------"
echo
echo
echo "This script will ask you a series of questions about how your dotmac"
echo "server will be setup. If you can't answer them all, you may start from"
echo "the beginning. After this, you will need to run 03_configure_dotmac.conf"
echo "from this directory"
echo
echo
echo

if [ -e `pwd`/.setupdir ] ; then
echo "Good, you are running from the setup directory"
else
echo "Error: you are not in the correct directory. These scripts must be run"
echo "from the setup directory"
exit 1
fi
echo

if [ -f /etc/dotmobile.us/conf ]; then
. /etc/dotmobile.us/conf
echo "Found current Config file: reading in for defaults"
cp /etc/dotmobile.us/comf conf.old
echo "Copying current config file to conf.old"
fi

echo  
echo "Clearing Temp Local Config File"
echo > conf
OUTPUTVALS=""
OLDIFS=${IFS}
IFS="
"
QUESTIONS="
IPADDR|T|What is the primary IP address of this machine: 
LOCALIDISKNAME|T|What is the local name for idisk (ex: idisk.yourdomain.com):
LOCALPUBLISHNAME|T|What is the local name for the publish service (ex: publish.yourdomain.com):
LOCALGALLERYNAME|T|What is the local name for the gallery service (ex: gallery.yourdomain.com)
LOCALWWWMACNAME|T|What is the local name for the administrative scripts (can be the same as the idisk name)
LOCALWEBNAME|T|What is the name that your iWeb sites should be viewable from (ex: homepages.yourdomain.com)
GALLERYPROXYENABLE|B|Should we proxy to other users Gallery Sites
"

for x in ${QUESTIONS}; do 
KEY=`echo ${x} | awk -F '|' '{ print $1 }'`
TYPE=`echo ${x} | awk -F '|' '{ print $3 }'`

QUESTION=`echo ${x} | awk -F '|' '{ print $3 }'`

echo $QUESTION
if [ x${KEY} != "x" ]; then

	CURVAL=`eval echo -n "\\\$$KEY"`
	echo "Current value = $CURVAL"
	read ANSWER
	if [ x$ANSWER != "x" ]; then	
		echo ${KEY}=${ANSWER} >> conf
	else 
		echo ${KEY}=$CURVAL >> conf

	fi
else
	read ANSWER
	echo ${KEY}=${ANSWER} >> conf
fi
echo
done
IFS=${OLDIFS}
cat conf
