#!/bin/bash

# Ensure we have core files
ulimit -c unlimited

# Remove ipv6 entries from /etc/hosts
cat /etc/hosts | sed '/^::1/ d' > /tmp/hosts
echo "y" |  cp -f /tmp/hosts /etc/hosts

# TODO: Fix return codes when failing
./testscript.sh

