#!/bin/bash

echo "----------------------------------------------"
echo "-Hosts File Setup Script                     -"
echo "-dotMobile.us Project                        -"
echo "-http://dotmac.googlecode.com                -"
echo "----------------------------------------------"
echo
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

. conf.new


echo "###DotMac Hosts file changes" > hosts
echo "###Generated on `date`" >> hosts

echo "$IPADDR	idisk.mac.com idisk.mac.com. certinfo.me.com. certinfo.me.com. certmgmt.me.com certmgmt.me.com." >> hosts
echo "$IPADDR	lcs.mac.com lcs.mac.com. configuration.apple.com configuration.apple.com. m3.mac.com m3.mac.com." >>hosts
echo "$IPADDR	$LOCALIDISKNAME $LOCALIDISKNAME. $LOCALPUBLISHNAME $LOCALPUBLISHNAME." >> hosts
echo "$IPADDR	$LOCALGALLERYNAME $LOCALGALLERYNAME. ">>hosts
echo "" >>hosts
echo "" >>hosts

echo "###The following shouldn't be needed as of 10.6, but you can copy them in for safety" >> hosts
echo "$IPADDR   www.mac.com www.mac.com. publish.mac.com publish.mac.com. publish.me.com publish.me.com. gallery.mac.com gallery.mac.com. " >> hosts
echo "$IPADDR  gallery.me.com gallery.me.com. homepages.mac.com homepages.mac.com." >>hosts



echo
echo
echo
echo
echo "Hosts file created"
echo "The contents of the hosts file in this directory should be merged with the hosts file on each client machine that will use this service"
