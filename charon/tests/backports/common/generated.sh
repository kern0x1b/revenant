# generated.sh: the generated contract layer, .gen/<Framework>/, for a harness that reads it.
#
#   . "$here/../../common/generated.sh"
#   ensure_generated "$here" AVFoundation
#
# .gen/ is gitignored and written by tools/gen.lua at build time: modules/apple/backports.lua generate() runs
# `gen --tree <tree> --all --sdk $CHARON_GEN_SDK` before any library is read, so a clean checkout has none of it.
# A harness that reads a generated file runs the same generator itself, once, and only when a folder it reads is
# missing. The SDK is CHARON_GEN_SDK when it is set; otherwise it is the iPhoneOS 26.2 package asked of xmake, never a
# folder of this machine. A generator that fails, or a folder that is still missing after it, fails the run: a check
# that did not get its input is not a check that passed.
ensure_generated() {
    gen_here=$1
    shift
    gen_tree=$(cd "$gen_here/../../../.." && pwd)
    gen_missing=""
    for gen_folder in "$@"; do
        [ -d "$gen_tree/packages/a/apple-backports/.gen/$gen_folder" ] || gen_missing="$gen_missing $gen_folder"
    done
    [ -z "$gen_missing" ] && return 0
    gen_out=$gen_tree/.agent-work/runs/generated
    mkdir -p "$gen_out"
    gen_sdk=${CHARON_GEN_SDK:-}
    if [ -z "$gen_sdk" ]; then
        mkdir -p "$gen_out/resolve"
        printf 'add_repositories("charon %s")\nadd_requires("iphoneos-sdk 26.2")\n' "$gen_tree" > "$gen_out/resolve/xmake.lua"
        gen_info=$(cd "$gen_out/resolve" && xmake require --info --format=json 2>"$gen_out/resolve.log") || {
            echo "FAIL the iPhoneOS 26.2 SDK did not resolve through xmake, so .gen/$gen_missing cannot be written: $gen_out/resolve.log"
            exit 1
        }
        gen_dir=$(printf '%s\n' "$gen_info" | sed -n 's/.*"installdir" *: *"\([^"]*\)".*/\1/p' | head -1 | sed 's#\\/#/#g')
        gen_sdk="$gen_dir/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.2.sdk"
    fi
    [ -d "$gen_sdk" ] || { echo "FAIL the SDK $gen_sdk is not there, so .gen/$gen_missing cannot be written"; exit 1; }
    (cd "$gen_tree" && CHARON_GEN_SDK="$gen_sdk" xmake l tools/gen.lua gen --tree "$gen_tree" --all --sdk "$gen_sdk") \
        > "$gen_out/gen.log" 2>&1 || {
        echo "FAIL the generator failed writing .gen/ (tail of $gen_out/gen.log):"
        tail -5 "$gen_out/gen.log" | sed 's/^/    /'
        exit 1
    }
    for gen_folder in $gen_missing; do
        [ -d "$gen_tree/packages/a/apple-backports/.gen/$gen_folder" ] || {
            echo "FAIL the generator wrote no .gen/$gen_folder"; exit 1; }
    done
}
