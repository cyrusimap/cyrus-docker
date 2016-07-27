#!/bin/bash

cd /srv/cyrus-docker.git
git pull -v
sh testscript.sh

