#!/bin/bash

source functions.sh

get_git /srv/cyrus-imapd.git https://github.com/cyrusimap/cyrus-imapd.git
get_git /srv/cassandane.git https://github.com/cyrusimap/cassandane.git
get_git /srv/cyruslibs.git https://github.com/cyrusimap/cyruslibs.git

cd /srv/cyrus-imapd.git

# Store the current and parent commit so we can compare
current_commit=$(git rev-parse HEAD)

_cassandane
