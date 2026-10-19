#!/bin/sh
# Build and run the probe, and never run anything but what was just built: a compile that fails must not
# leave the previous binary on screen to be read as this one's output, which is how two earlier runs of this
# probe reported numbers its source had never produced.
#
#     sh run.sh [/path/to/iPhoneOS.sdk/System/Library/Frameworks/MediaPlayer.framework/Headers/MPMediaItem.h]
#
# The header is an argument because the SDK's own MediaPlayer is unavailable to compile against here, and
# it is ALSO FOUND so the probe runs under run-all.sh, which passes a run.sh no arguments of its own: a
# test that dies without one is dead, and it certifies nothing while looking present in the tree.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"

# WHICH HEADER, and where it comes from. The iOS SDK is the authority for what MPMediaItem declares and
# what a property is called - five of these carry a getter= attribute, so the property name is not a
# selector on any platform - so the header has to be an iOS one, not the host's. MPITEM_SDK names the SDK
# to use; without it the newest iPhoneOS SDK in the shared store is taken, and "newest" is a version sort
# of the SDK's own number rather than a byte sort of its path, which puts 9.0 after 16.4.
sdk=${MPITEM_SDK:-}
if [ -z "$sdk" ]; then
    store=$HOME/.xmake/packages/i/iphoneos-sdk
    latest=$(ls -d "$store"/*/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk 2>/dev/null |
             sed 's|.*/iPhoneOS||; s|\.sdk$||' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
    [ -n "$latest" ] || {
        echo "FAIL: no iPhoneOS SDK under \$HOME/.xmake/packages/i/iphoneos-sdk. The getters this probe asks"
        echo "      about are read out of an iOS header and the host's own framework does not declare them."
        echo "      Set MPITEM_SDK to an iPhoneOS SDK."
        exit 1
    }
    sdk=$(ls -d "$store"/*/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$latest.sdk 2>/dev/null | head -1)
fi
header=${1:-$sdk/System/Library/Frameworks/MediaPlayer.framework/Headers/MPMediaItem.h}
[ -f "$header" ] || {
    echo "FAIL: no MPMediaItem.h at $header, so there is nothing to read the declared getters out of"
    exit 1
}
# The header the getters are read out of, in full, because the probe below prints only its file name and a
# run that silently read some other SDK's header cannot be told apart from one that read this one's.
echo "header:   $header"

# The port's own sources, which is where MPMediaItemStandin.h lives and what the three checks below
# measure: each check re-declares the class under test and the base it stands on, so it compiles against
# the port's header and the port's own shape rather than against this Mac's MediaPlayer, which declares
# several of these already and a category compiled against that would look like a clobber. It is the same
# compile line tools/media-event-class.lua uses.
library=${MPITEM_LIBRARY:-$(cd "$here/../../../../packages/a/apple-backports/MediaPlayer" 2>/dev/null && pwd)}
[ -f "$library/MPMediaItemStandin.h" ] || {
    echo "FAIL: no MPMediaItemStandin.h under $library, so the three checks below have no stand-in to"
    echo "      compile against and would certify nothing while looking present in the tree."
    exit 1
}
echo "library: $library"

bin=$(runs_folder revenant-mediaplayeritem)/probe-$$
rm -f "$bin"
xcrun clang -fobjc-arc -framework Foundation -framework MediaPlayer -o "$bin" "$here/probe.m"
# The status is taken through `|| status=$?`, not by reading $? on the next line: under `set -e` the probe
# failing ends the script there, so the line below was unreachable and the rm never ran.
status=0
"$bin" "$header" || status=$?

# The three contract checks, each built before it is run and removed after, for the reason the comment
# above the probe gives: a compile that fails must not leave a previous binary on screen to be read as
# this one's output. They were in this directory and named by no runner, which is what
# coordination/crutches.md's "MediaPlayer MPSeekCommandEvent's host check is missing" recorded; they run
# here now.
# The UIKit stand-in joins the include path for the checks that include the port's 7.1 object, which
# sends its events through +[UIApplication sharedApplication] and reads UIEventTypeRemoteControl.
for check in contract mpratingcommandeventcheck mpskipintervalcommandeventcheck mpseekcommandeventcheck; do
    rm -f "$bin"
    if ! xcrun clang -fobjc-arc -w -framework Foundation -I"$here" -I"$library" -I"$here/standin" -o "$bin" "$here/$check.m"; then
        echo "FAIL: $check.m did not build, so it certifies nothing"
        rm -f "$bin"
        exit 1
    fi
    "$bin" || status=$?
    rm -f "$bin"
done
exit $status