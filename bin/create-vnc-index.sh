#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. >/dev/null 2>&1 && pwd )"

export TOKENFILE="${1:-/root/tokens.list}"
export DESKTOPFILE="${2:-$DIR/desktops.yaml}"
export INDEXFILE="${3:-$DIR/index.html}"

if ! rpm -qa |grep -q ruby ; then
    echo "Ruby is required for generating index.html file"
    exit 1
fi

if [ -f $TOKENFILE ] ; then
    tokenbup="$TOKENFILE-old"
    echo "$TOKENFILE already exists, moving to $tokenbup"
    mv -f $TOKENFILE $tokenbup
fi

if [ -f $DESKTOPFILE ] ; then
    desktopbup="$DESKTOPFILE-old"
    echo "$DESKTOPFILE already exists, moving to $desktopbup"
    mv -f $DESKTOPFILE $desktopbup
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
        echo "$CLUSTERNAME:" >> $DESKTOPFILE
        while IFS= read -r i ; do
            # Add to VNC file
            session=$(echo "$i" |awk '{print $2}')
            case $session in 
                "xterm"|"terminal")
                    TYPE="console"
                    ;;
                *)
                    TYPE="desktop"
                    ;;
            esac
            PORT=$(echo "$i" |awk '{print $6}')
            PASS=$(echo "$i" |awk '{print $8}')
            echo "$CLUSTERNAME-$TYPE: $IP:$PORT" >> $TOKENFILE
            echo "  $TYPE:" >> $DESKTOPFILE
            echo "    port: $PORT" >> $DESKTOPFILE
            echo "    pass: $PASS" >> $DESKTOPFILE
        done <<< "$DESKTOPS"
    fi
done

# Generate index.html (using ruby, yay)
ruby generate-index.rb

echo "The following files have been written:"
echo "- $TOKENFILE: For websockify server"
echo "- $DESKTOPFILE: For ruby script to create index.html of all the servers"
echo "- $INDEXFILE: A rendered index.html for connecting to servers"
