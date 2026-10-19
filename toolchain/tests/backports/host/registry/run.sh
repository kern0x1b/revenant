#!/bin/sh
# usage: run.sh <dyld_shared_cache_armv7 of the release the band is built for>
here=$(cd "$(dirname "$0")" && pwd)
exec xmake lua "$here/check.lua" "$1" "$here/../../../../modules/apple"
