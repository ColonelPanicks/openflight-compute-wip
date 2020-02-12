#!/bin/bash

TOKENFILE="${1:-/root/tokens.list}"
YAMLFILE="${2:-./desktops.yaml}"
INDEXFILE="${3:-./index.html}"

if ! rpm -qa |grep -q ruby ; then
    echo "Ruby is required for generating index.html file"
    exit 1
fi

if [ -f $TOKENFILE ] ; then
    tokenbup="$TOKENFILE-old"
    echo "$TOKENFILE already exists, moving to $tokenbup"
    mv -f $TOKENFILE $tokenbup
fi

if [ -f $YAMLFILE ] ; then
    yamlbup="$YAMLFILE-old"
    echo "$YAMLFILE already exists, moving to $yamlbup"
    mv -f $YAMLFILE $yamlbup
fi

if [ -f $INDEXFILE ] ; then
    indexbup="$INDEXFILE-old"
    echo "$INDEXFILE already exists, moving to $indexbup"
    mv -f $INDEXFILE $indexbup
fi

for cluster in $(ls /opt/flight/clusters) ; do

    # Identify available VNC sessions
    IP=$(grep '^gateway1' /opt/flight/clusters/$cluster |sed 's/.*ansible_host=//g')
    CLUSTERNAME=$(echo "$cluster" |sed 's/-.*//g')
    DESKTOPS=$(ssh $IP "su - flight /opt/flight/bin/flight desktop list" |grep -v '^Last login' |tac)
    if [ ! -z "$DESKTOPS" ] ; then
        echo "$CLUSTERNAME:" >> $YAMLFILE
        while IFS= read -r i ; do
	    # Add to VNC file
            TYPE=$(echo "$i" |awk '{print $2}')
            PORT=$(echo "$i" |awk '{print $6}')
	    PASS=$(echo "$i" |awk '{print $8}')
            echo "$CLUSTERNAME-$TYPE: $IP:$PORT" >> $TOKENFILE
            echo "  $TYPE:" >> $YAMLFILE
            echo "    port: $PORT" >> $YAMLFILE
            echo "    pass: $PASS" >> $YAMLFILE
        done <<< "$DESKTOPS"
    fi
done

echo "The following files have been written:"
echo "- $TOKENFILE: For websockify server"
echo "- $YAMLFILE: For ruby script to create index.html of all the servers"
echo "- $INDEXFILE: A rendered index.html for connecting to servers"

# Generate index.html (using ruby, yay)
ruby generate-index.rb
