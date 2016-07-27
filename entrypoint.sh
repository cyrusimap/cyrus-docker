#!/bin/bash

# Fedora 21 does not invoke /etc/bashrc, thus giving you a weird PS1
if [ ! -z "$PS1" ]; then
    . /etc/bashrc
fi

cd /srv/cyrus-docker.git
git pull -v
sh testscript.sh

