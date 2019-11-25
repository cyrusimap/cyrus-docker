#!/bin/bash

BUILD_CYRUS_FROM_SOURCE=${BUILD_CYRUS_FROM_SOURCE:-yes}
export CASSANDANEOPTS=${CASSANDANEOPTS:-""}

source functions.sh

[ -d /srv/cassandane.git ] || _cassandaneclone

if [ "$BUILD_CYRUS_FROM_SOURCE" = "yes" ] ; then
  _cyrusclone
  _cyrusbuild
else
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y cyrus-imapd
fi

_updatejmaptestsuite

_cassandane "$BUILD_CYRUS_FROM_SOURCE"
retval=$?
_report
exit ${retval}

