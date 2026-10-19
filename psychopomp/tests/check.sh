#!/bin/bash
# Verdict for one clean-machine run: did the agent write the app itself, build it for the
# scenario's release and architecture, check it in the emulator on the scenario's device, and
# package a .deb, without copying anything from the plugin?
# Usage: tests/check.sh PROJECT_DIR SCENARIO_DIR PLUGIN_DIR [EVIDENCE_DIR]
set -u
abs() { (cd "$1" 2>/dev/null && pwd); }
project=$1 scenario=$(abs "$2") plugin=$(abs "$3") evidence=${4:+$(abs "$4")} tests=$(abs "$(dirname "$0")")
# shellcheck disable=SC1091
. "$scenario/scenario.conf"   # RELEASE DEVICE ARCH LANGUAGE
failed=0
ok()   { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failed=1; }

cd "$project" || { echo "FAIL  no project directory $project"; exit 1; }
prune=(-name build -prune -o -name .xmake -prune -o -name .logs -prune -o -name .git -prune -o)

# 1. The app's own code exists, in the chosen language.
m=$(find . "${prune[@]}" -type f \( -name '*.m' -o -name '*.mm' \) -print | wc -l | tr -d ' ')
s=$(find . "${prune[@]}" -type f -name '*.swift' -print | wc -l | tr -d ' ')
case $LANGUAGE in
  objc)    [ "$m" -gt 0 ] && [ "$s" -eq 0 ] && ok "Objective-C sources ($m), no Swift" || fail "language objc: $m .m, $s .swift" ;;
  swift)   [ "$s" -gt 0 ] && ok "Swift sources ($s)" || fail "language swift: no .swift file" ;;
  swiftui) [ "$s" -gt 0 ] && grep -rlq --include='*.swift' '^import SwiftUI' . && ok "Swift sources ($s) importing SwiftUI" \
             || fail "language swiftui: no .swift file importing SwiftUI" ;;
esac
[ -f PROJECT.md ] && ok "PROJECT.md written" || fail "no PROJECT.md: the interview did not record its decisions"

# 2. Nothing from the plugin in the project: no skill file, and no run of 5 significant lines
#    (8+ characters after trimming) that also appears in the plugin's own text. The scenarios
#    are the user's input and are not part of what is compared.
if find . "${prune[@]}" -name SKILL.md -print | grep -q .; then fail "a SKILL.md is in the project"; else ok "no SKILL.md in the project"; fi
copied=$(xmake l "$tests/copied_text.lua" "$plugin" .)
[ -z "$copied" ] && ok "no 5-line run shared with the plugin" || { fail "text copied from the plugin:"; printf '      %s\n' "$copied"; }

# 3. xmake.lua targets the scenario's release.
if grep -Eq "apple_minimum[\"'], *[\"']${RELEASE//./\\.}[\"']" xmake.lua 2>/dev/null; then ok "apple_minimum $RELEASE in xmake.lua"
else fail "xmake.lua does not set apple_minimum to $RELEASE"; fi

# 4. The app was built for the architecture and release.
app=$(find build -type d -name '*.app' -not -path '*/.xmake/*' 2>/dev/null | head -1)
if [ -z "$app" ]; then fail "no .app under build/"
else
  exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist" 2>/dev/null || plutil -extract CFBundleExecutable raw "$app/Info.plist" 2>/dev/null)
  if [ -z "$exe" ] || [ ! -f "$app/$exe" ]; then fail "$app has no executable named by CFBundleExecutable"
  else
    lipo -archs "$app/$exe" | tr ' ' '\n' | grep -qx "$ARCH" && ok "$app/$exe has $ARCH" || fail "$app/$exe lacks $ARCH ($(lipo -archs "$app/$exe"))"
    minos=$(otool -arch "$ARCH" -l "$app/$exe" | awk '/LC_VERSION_MIN_IPHONEOS/{f=1} f&&/version/{print $2; exit}')
    [ "${minos%.0}" = "${RELEASE%.0}" ] && ok "minimum OS in the binary is $minos" || fail "minimum OS in the binary is '$minos', not $RELEASE"
  fi
fi

# 5. The emulator ran on the scenario's device and release, and passed.
#    Until charon can launch an app through SpringBoard, the pass line proves the image booted
#    with the app installed and the checked command exited 0, not that the app's screen worked.
if cat .logs/* 2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g' | grep -qE "^pass on ${DEVICE} ${RELEASE//./\\.} "; then ok "emulator: pass on $DEVICE $RELEASE"
else fail "emulator: no 'pass on $DEVICE $RELEASE' line in .logs/"; fi

# 6. A .deb of the app, for iphoneos-arm, carrying the bundle.
deb=$(find build -maxdepth 3 -name '*.deb' -not -name 'org.charon.*' 2>/dev/null | head -1)
if [ -z "$deb" ]; then fail "no app .deb under build/"
else
  a=$(dpkg-deb -f "$deb" Architecture 2>/dev/null)
  [ "$a" = iphoneos-arm ] && ok "$deb is iphoneos-arm" || fail "$deb Architecture is '$a'"
  dpkg-deb -c "$deb" | grep -q '/Applications/.*\.app/' && ok "$deb carries an app under /Applications" || fail "$deb has nothing under /Applications"
fi

# 7. The agent's login never reaches the evidence (run.sh also scans it for the exact token).
if [ -n "$evidence" ]; then
  creds=$( { find "$evidence" -name '.credentials.json'; grep -rlE 'claudeAiOauth|"refreshToken"|sk-ant-(oat|ort)[0-9]' "$evidence"; } 2>/dev/null | grep -v '/check\.txt$' | sort -u)
  [ -z "$creds" ] && ok "no login credentials in the evidence" || { fail "login credentials in the evidence:"; printf '      %s\n' $creds; }
fi

echo
[ $failed -eq 0 ] && echo "RUN COUNTS" || echo "RUN DOES NOT COUNT"
exit $failed
