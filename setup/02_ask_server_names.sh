#!/bin/bash

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
exit 1;
fi
echo 
echo "Clearing Old Config File"
echo > conf
OUTPUTVALS=""
OLDIFS=${IFS}
IFS="
"
QUESTIONS="
IPADDR|What is the primary IP address of this machine: 
LOCALIDISKNAME|What is the local name for idisk (ex: idisk.yourdomain.com):
LOCALPUBLISHNAME|What is the local name for the publish service (ex: publish.yourdomain.com):
LOCALGALLERYNAME|What is the local name for the gallery service (ex: gallery.yourdomain.com)
LOCALWWWMACNAME|What is the local name for the administrative scripts (can be the same as the idisk name)
LOCALWEBNAME|What is the name that your iWeb sites should be viewable from (ex: homepages.yourdomain.com)
"

for x in ${QUESTIONS}; do 
KEY=`echo ${x} | awk -F '|' '{ print $1 }'`
QUESTION=`echo ${x} | awk -F '|' '{ print $2 }'`

echo $QUESTION
read ANSWER
echo ${KEY}=${ANSWER} >> conf

echo
done
IFS=${OLDIFS}
cat conf
