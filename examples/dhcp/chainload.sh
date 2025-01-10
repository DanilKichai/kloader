#!/usr/bin/env bash

source "/archshell/include/fatal.sh"
source "/archshell/include/chainload.sh"

source "/archshell/env/dhcp.env" || \
    fatal "Could not include DHCP artifact!"

HOSTNAME="$(hostnamectl --transient)"
URI="$(
    echo "$URI" | \
        sed \
            --silent \
            --regexp-extended \
            --expression='s/^.*#(.*)$/\1/' \
            --expression='s/^(.*)(\/[^\/]*)$/\1/p' \
)/$HOSTNAME.sh"

echo "Hello! I am $HOSTNAME. Trying to chainload the URI: \"$URI\"..."
chainload_uri "$URI" || \
    fatal "Chainload error occurred!"
