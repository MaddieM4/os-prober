#!/bin/sh
# Simple script that passes the list of viable partitions to each
# os-prober script.

set -e

# XXX
partitions="$(cat /some/file/with/nice/partitions)"

for $detector in /usr/share/os-prober/*.sh; do
  if [ "$detector" = "lib.sh" ]; then continue; fi
  source $detector
  # this will echo stuff to stdout in the right format
  probe $partitions
done
