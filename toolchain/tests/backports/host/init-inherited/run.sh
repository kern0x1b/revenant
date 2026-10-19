#!/bin/sh
# run.sh - the HomeKit and HealthKit -init and +new rows whose class carries neither selector of its own.
# No argument: the check reads the registry and the port's sources from the checkout it lives in.
here=$(cd "$(dirname "$0")" && pwd)
charon=${CHARON:-$here/../../../..}
charon=$(cd "$charon" && pwd)
exec xmake lua "$here/check.lua" "$charon"
