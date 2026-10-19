#!/bin/sh
# translate.sh INPUT INCLUDES OUT — arm64 iOS executable to an armv7 iOS 6 executable.
set -eu
LAB=$(cd "$(dirname "$0")/.." && pwd)
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
LD=$(ls $HOME/.xmake/packages/l/ld64/956.6/*/bin/ld | head -1)
LLVM=/opt/homebrew/opt/llvm/bin
input=$1 includes=$2 out=$3
incdir=$(dirname "$includes")  # so the generated guest.m/host.m resolve a sibling include of $includes
shift 3
extra_images="$*"
name=$(basename "$input" -arm64)
mkdir -p "$out"
# Auto-lift embedded frameworks/dylibs the app links via @rpath/@executable_path/@loader_path:
# these are guest code the bundle ships (SDWebImage, LNPopupController, AFNetworking, ...), not
# system libraries, so they must be lifted as extra guest images like libc++ rather than linked.
# Resolve each against the bundle's Frameworks dir (XL_FRAMEWORKS_DIR), thin a fat binary to the
# arm64 slice, and lift the ones that are predominantly Objective-C; skip predominantly-Swift
# frameworks (the Swift metadata frontier) -- their classes weak-bind to nil.
if [ -n "${XL_FRAMEWORKS_DIR:-}" ]; then
  for dep in $(otool -L "$input" | awk '/@rpath\/|@executable_path\/|@loader_path\// {print $1}'); do
    base=$(basename "$dep")
    case "$dep" in
      */*.framework/*) fw=$(basename "$(dirname "$dep")"); src="$XL_FRAMEWORKS_DIR/$fw/$base" ;;
      *) src="$XL_FRAMEWORKS_DIR/$base" ;;
    esac
    [ -f "$src" ] || { echo "embedded framework not found, skipping: $dep"; continue; }
    file -b "$src" | grep -q 'Mach-O' || continue
    # thin to the arm64 slice if the framework is a fat binary
    img="$src"
    if file -b "$src" | grep -q 'universal'; then
      img="$out/$base-arm64"
      lipo "$src" -thin arm64 -output "$img" 2>/dev/null || { echo "no arm64 slice, skipping: $base"; continue; }
    fi
    swift=$(nm "$img" 2>/dev/null | grep -cE '_\$s|_swift_' || true)
    classes=$(nm -gj "$img" 2>/dev/null | grep -c '_OBJC_CLASS_\$_' || true)
    if [ "$classes" -eq 0 ] || [ "$swift" -gt "$classes" ]; then
      echo "embedded framework is predominantly Swift ($swift swift / $classes objc), not lifting: $base"
      continue
    fi
    echo "auto-lifting embedded framework: $base ($classes objc classes)"
    extra_images="$extra_images $img"
  done
fi
GUEST="-target arm64-apple-ios12.0 -isysroot $SDK -O2 -fno-stack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -w"
HOST="-target armv7-apple-ios6.0 -marm -isysroot $SDK -O2 -w"
for source in runtime data; do
  xcrun clang $GUEST -fno-builtin -I "$LAB/deps/BlocksRuntime" -c "$LAB/deps/BlocksRuntime/$source.c" -o "$out/support-blocks-$source.o"
done
xcrun clang $GUEST -fno-builtin -c "$LAB/runtime/int128.c" -o "$out/support-int128.o"
xcrun clang $GUEST -fno-builtin -c "$LAB/runtime/availability.c" -o "$out/support-availability.o"
nm -gU "$out"/support-*.o | awk 'NF==3 {print $3}' | sort -u > "$out/provided.txt"
# A guest image answers a bind by the library the bind names: its install name, or the system library a --replaces
# names it for (XL_REPLACES="/usr/lib/libc++.1.dylib=libs/libc++.1.dylib ..." -- the recipe-built libc++ is
# @rpath/libc++.1.dylib and stands for the system's; nothing but the invoker says so). xlate is the one place that
# decides it: it also writes guest-resolved.txt, the symbols no host library has to supply.
replaces=""
for spec in ${XL_REPLACES:-}; do replaces="$replaces --replaces $spec"; done
"$LAB/xlate/build/xlate" --base "${XL_BASE:-0x10000000}" $replaces --objc-manifest "$out/manifest.json" --resolved-out "$out/guest-resolved.txt" "$input" $extra_images
# Collect every image's imports. dyld_info -imports reads the LC_DYLD_INFO bind table, which
# is empty for a dylib pulled out of a shared cache (dsc_extractor does not rebuild it); nm -u
# reads the symbol table's undefined entries and catches those, so union the two -- an extra
# image like a cache-extracted libc++ contributes its libSystem calls (pthread_once, snprintf,
# the _Unwind_* EH primitives, ...) only through nm -u, and those must be bridged or trapped or
# xlate fails resolving their call stubs.
{ for image in "$input" $extra_images; do xcrun dyld_info -imports "$image" | tail -n +3 | awk '$1 ~ /^0x/ {print $2; next} {print $1}'; nm -u "$image" 2>/dev/null | awk '{print $NF}'; done; nm -u "$out"/support-*.o | grep '^_'; printf '_objc_retain\n_objc_release\n'; } | sort -u > "$out/all-imports.txt"
# A symbol every image imports only weakly is one the code checks for before it uses it; it must stay
# unbound when unsupported, not become a trap that the check would find.
{ for image in "$input" $extra_images; do xcrun dyld_info -imports "$image" | tail -n +3 | awk '{ print ($1 ~ /^0x/ ? $2 : $1), (index($0, "[weak-import]") ? "W" : "S") }'; done; nm -u "$out"/support-*.o | awk '{print $NF, "S"}'; } | awk '$2 == "S" { strong[$1] = 1 } $2 == "W" { weak[$1] = 1 } END { for (s in weak) if (!(s in strong)) print s }' | sort > "$out/weak-only.txt"
sort -u "$out/provided.txt" "$out/guest-resolved.txt" -o "$out/provided.txt"
# BACKPORTS_DIR points at an apple-backports build for this target band; unset means the app is translated
# with none. A value that names no backport library is an error, not an empty list: the weak imports the
# backports provide would be taken for absent.
backport_libs=""; strip_dylibs=""
if [ -n "${BACKPORTS_DIR+set}" ]; then
  if [ -z "$BACKPORTS_DIR" ] || ! ls "$BACKPORTS_DIR"/lib*Backports.dylib >/dev/null 2>&1; then
    echo "error: BACKPORTS_DIR='$BACKPORTS_DIR' holds no lib*Backports.dylib; unset it to translate without backports" >&2
    exit 1
  fi
  backport_libs=$(echo "$BACKPORTS_DIR"/lib*Backports.dylib)
  strip_dylibs="-Wl,-dead_strip_dylibs"
fi
# grep -v exits 1 when it selects nothing, which is a legitimate answer here; 2 is an error.
without() { grep -vxF -f "$1" "$2" > "$3" || [ $? -eq 1 ]; }
without "$out/guest-resolved.txt" "$out/all-imports.txt" "$out/imports.txt"
# A weak import the target OS neither has nor gets from a linked backport is absent there: the guest checks for
# it and takes its fallback, which only works if nothing is bound at that symbol, not a bridge to a call the
# device cannot make.
: > "$out/backport-exports.txt"
for l in $backport_libs; do nm -gU "$l" | awk 'NF==3 {print $3}' >> "$out/backport-exports.txt"; done
# What the build itself links in (support objects, guest images) is not absent either.
# The bridge provides some libobjc calls the target lacks (the Swift runtime's class registration, runtime/swift_classes.m).
cat "$LAB/runtime/bridge-provides.txt" >> "$out/backport-exports.txt"
sort -u "$out/backport-exports.txt" "$out/provided.txt" -o "$out/linked-exports.txt"
: > "$out/weak-absent.txt"
if [ -s "$out/weak-only.txt" ]; then
  xmake l "$LAB/scripts/absent_on_target.lua" "$HOME/.charon/dyld/6.0/dyld_shared_cache_armv7" "$out/weak-only.txt" "$out/linked-exports.txt" > "$out/weak-absent.txt"
  without "$out/weak-absent.txt" "$out/imports.txt" "$out/imports.txt.kept"
  mv "$out/imports.txt.kept" "$out/imports.txt"
  [ -s "$out/weak-absent.txt" ] && { echo "warning: weak imports absent on the target, left unbound (the app takes its fallback):"; sed 's/^/  /' "$out/weak-absent.txt"; }
fi
# Carry the input binary's own entitlements (an app that reads them at run time -- iSH's app-group id --
# expects them in the image; the translated binary is re-signed and no longer holds the originals).
codesign -d --entitlements :- "$input" > "$out/entitlements.plist" 2>/dev/null || : > "$out/entitlements.plist"
"$LAB/xlate/build/xlgen" --entitlements "$out/entitlements.plist" --sdk "$SDK" --resource-dir /opt/homebrew/opt/llvm/lib/clang/23 --includes "$includes" \
  --abi-header "$LAB/runtime/objc_abi.h" --symbols "$out/imports.txt" --guest-provided "$out/provided.txt" --weak-only "$out/weak-only.txt" \
  --objc-manifest "$out/manifest.json" --guest-out "$out/guest.m" --host-out "$out/host.m" \
  --passthrough-out "$out/passthrough.txt" --report-out "$out/report.txt"
# Visibility over device surprises: an imported symbol with no bridge becomes a trap that aborts if
# reached, and a weak one is left unbound, so the guest's check finds it absent. List those (imports the
# report marks UNSUPPORTED) at build time.
awk -F: 'FNR==NR{need[$1]=1;next} /UNSUPPORTED/{s=$1; if(need[s]) print "  " $0}' "$out/imports.txt" "$out/report.txt" > "$out/unbridged-imports.txt" || true
[ -s "$out/unbridged-imports.txt" ] && { echo "warning: imported symbols without a bridge (a strong import aborts if reached, a weak one is left unbound):"; cat "$out/unbridged-imports.txt"; }
traps=$(grep -o 'xl_trap_[A-Za-z0-9_]*' "$out/guest.m" | sort -u | sed 's/^/-Wl,-U,_/' | tr '\n' ' ')
xcrun clang $GUEST -x objective-c -fno-objc-arc -fblocks -fno-builtin -iquote "$incdir" -c "$out/guest.m" -o "$out/guest.o"
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" -dynamiclib -install_name @rpath/libxl-guest.dylib \
  "$out/guest.o" "$out"/support-*.o -o "$out/libxl-guest.dylib" $traps
# The lift and its compile are the whole cost of a translation (three minutes for the Swift demo) and depend on the guest
# images, the bridge library, the passthrough list and xlate itself -- not on the host runtime, which is compiled after
# them. A run whose lift inputs match the last one's reuses its objects, so a change to runtime/ costs seconds.
lift_key=$( { cat "$LAB/xlate/build/xlate" "$input" $extra_images "$out/passthrough.txt" "$out/libxl-guest.dylib"; echo "$replaces ${XL_BASE:-0x10000000}"; } | shasum | cut -d' ' -f1 )
if [ -f "$out/lift.stamp" ] && [ "$(cat "$out/lift.stamp")" = "$lift_key" ] && [ -f "$out/lifted-objs.txt" ]; then
  echo "lift inputs unchanged since the last run: reusing its lifted objects"
  lifted_objs=$(cat "$out/lifted-objs.txt")
else
  rm -f "$out/lift.stamp"
  "$LAB/xlate/build/xlate" --base "${XL_BASE:-0x10000000}" --output "$out/lifted.bc" --layout "$out/layout.txt" --passthrough "$out/passthrough.txt" \
    --state-header "$out/xl_state.h" $replaces --bridge "$out/libxl-guest.dylib" "$input" $extra_images "$out/libxl-guest.dylib"
  # Compile the lifted code to a single object (fast path). A large app (e.g. one that
  # statically links a heavy templated C++ library) can lift into a single object whose
  # inter-function BL branches exceed the armv7 ±32 MB range ("Relocation out of range",
  # reported by the ARM backend as "cannot compile inline asm"). Only then split the module,
  # so ld64 inserts branch islands for cross-piece calls -- no long calls, no text relocations,
  # and no cost for small/medium apps. The split keeps ALL globals (the rehosted guest image and
  # the Objective-C metadata) in ONE data object at exactly their single-object layout, and
  # distributes only the functions across code-only pieces. This is essential: the lifted code
  # reaches guest memory by absolute address and the metadata cross-references itself, so a
  # global that llvm-split moved to another piece (or duplicated into one) would break every
  # pointer into it -- the Objective-C class list would point at the wrong class objects and the
  # image would crash silently in objc's map_images, before any handler is installed.
  lifted_objs="$out/lifted.o"
  xl_split_compile() {
    echo "lifted.o: a module of $1 bytes does not fit one object's branch range; splitting code, keeping data in one object" >&2
    rm -rf "$out/split"; mkdir -p "$out/split"
    # data object: every global (with its initializer), functions reduced to declarations.
    "$LLVM/llvm-extract" --delete --rfunc='.*' "$out/lifted.bc" -o "$out/split/data.bc"
    $LLVM/clang $HOST -c "$out/split/data.bc" -o "$out/split/data.o" &
    data_job=$!
    # code pieces: functions distributed across objects, every global reduced to a declaration
    # so nothing is duplicated -- the one definition lives in data.o.
    "$LLVM/llvm-split" -j 8 -o "$out/split/p" "$out/lifted.bc"
    lifted_objs="$out/split/data.o"
    # The pieces are independent: compile XL_COMPILE_JOBS of them at a time (the data object runs beside the first batch).
    jobs=${XL_COMPILE_JOBS:-4}; running=0; pids="$data_job"
    for piece in "$out"/split/p[0-9]*; do
      case "$piece" in *.o|*.bc) continue;; esac
      ( "$LLVM/llvm-extract" --delete --rglob='.*' "$piece" -o "$piece.code.bc" && $LLVM/clang $HOST -c "$piece.code.bc" -o "$piece.o" ) &
      pids="$pids $!"; running=$((running + 1))
      lifted_objs="$lifted_objs $piece.o"
      if [ "$running" -ge "$jobs" ]; then
        for pid in $pids; do wait "$pid" || exit 1; done
        pids=""; running=0
      fi
    done
    for pid in $pids; do wait "$pid" || exit 1; done
  }
  # A module this big cannot fit one object (the demo's 80 MB failed after five minutes of compiling; Zebra's 45 MB does
  # fit): go straight to the split. XL_SPLIT_BYTES moves the line; below it the single object is tried and the split is the
  # fallback, as before.
  lifted_bytes=$(wc -c < "$out/lifted.bc" | tr -d ' ')
  if [ "$lifted_bytes" -gt "${XL_SPLIT_BYTES:-64000000}" ]; then
    xl_split_compile "$lifted_bytes"
  elif ! $LLVM/clang $HOST -c "$out/lifted.bc" -o "$out/lifted.o" 2>"$out/lifted-cc.log"; then
    if grep -q 'out of range' "$out/lifted-cc.log"; then
      xl_split_compile "$lifted_bytes"
    else
      cat "$out/lifted-cc.log" >&2; exit 1
    fi
  fi
  echo "$lifted_objs" > "$out/lifted-objs.txt"
  echo "$lift_key" > "$out/lift.stamp"
fi
# XL_EXTRA_CFLAGS: nothing reads this but the runtime/bridge objects below, and it defaults to
# empty -- a corpus fixture's own control build (corpus/swiftconformance) is the one caller that
# sets it, to compile a variant of runtime/bridge.m with a bridge deliberately switched off
# (-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1) and compare its behavior against a normal build.
$LLVM/clang $HOST -I "$out" -I "$LAB/runtime" ${XL_EXTRA_CFLAGS:-} -c "$LAB/runtime/runtime.c" -o "$out/runtime.o"
for source in "$LAB/runtime/bridge.m" "$LAB/runtime/objc_bridge.m" "$LAB/runtime/swift_classes.m" "$LAB/runtime/objc_compat.m" "$out/host.m"; do
  object="$out/$(basename "$source" .m).o"
  $LLVM/clang $HOST -fno-objc-arc -fblocks -I "$out" -I "$LAB/runtime" -iquote "$incdir" ${XL_EXTRA_CFLAGS:-} -c "$source" -o "$object"
  python3 "$LAB/scripts/rename_sections.py" "$object" toxl
done
# Bind APIs the backports provide (iOS 7+ classes like NSURLSession, UIAlertController)
# from the backports libraries rather than the stock frameworks, where they are absent on
# the target OS. Listing the backport dylibs BEFORE the frameworks makes the two-level
# linker resolve exactly the symbols they export from them (their install_names point at
# the on-device backports path), and -dead_strip_dylibs drops any backport dylib an app
# does not actually use, so a translated app depends only on the backports it needs.
# Weak-link frameworks outside a core set that is always present on the target. This makes
# the image tolerant: a class an app references that the target lacks (e.g. WKWebView -- the
# public WebKit is iOS 8+, and iOS 6's WebKit framework exists but has no WKWebView, so a
# framework-presence test is not enough) resolves to nil and faults only if actually used,
# rather than blocking load. Core frameworks stay hard-linked; backported classes still bind
# from the backports libs above regardless of this.
CORE_FRAMEWORKS="Foundation CoreFoundation CoreGraphics UIKit QuartzCore CoreText Security"
framework_flags=""
for fwpath in $(otool -L "$input" | awk '/\.framework\// { print $1 }' | sort -u); do
  # An embedded framework (@rpath/@executable_path/@loader_path -- a 3rd-party framework the
  # app bundles under Frameworks/) is guest code, not a system framework: it is lifted as an
  # extra image (its binary passed alongside the app), so skip it here -- linking it as a
  # system -framework would fail with "framework not found".
  case "$fwpath" in @rpath/*|@executable_path/*|@loader_path/*) continue;; esac
  fw=$(basename "$fwpath")
  case " $CORE_FRAMEWORKS " in
    *" $fw "*) framework_flags="$framework_flags -framework $fw" ;;
    *) framework_flags="$framework_flags -weak_framework $fw" ;;
  esac
done
# Plain (non-framework) /usr/lib satellites the app links directly (libsqlite3, libiconv, libresolv,
# libxml2, ...): a bridge xlgen generates for one of their functions calls the real function, so the
# lib must be linked or that call is unresolved. Add -l<name> for each, mapping libNAME.V.dylib ->
# -lNAME. Skip libSystem/libobjc/libc++ (implicit or linked below / lifted as a guest image).
extra_libs=""
for dylib in $(otool -L "$input" | awk '/\/usr\/lib\/lib.*\.dylib/ {print $1}'); do
  base=$(basename "$dylib")
  stem=${base#lib}; stem=${stem%.dylib}; stem=$(echo "$stem" | sed -E 's/(\.[0-9]+)+$//')
  case "$stem" in System|System.B|objc|objc.A|c++|c++abi|z) continue;; esac
  skip=""; for im in $extra_images; do [ "$(basename "$im")" = "$base" ] && skip=1; done
  [ -n "$skip" ] && continue
  extra_libs="$extra_libs -l$stem"
done
# A class the guest imports usually resolves at link against the SDK stub (which carries every
# system class, even iOS 7+ ones) or the backports. A class from an embedded framework we skip
# above, or one absent from the SDK entirely, has no link-time provider and would fail the link.
# Permit exactly the uncovered classes to be undefined: -Wl,-U only ALLOWS a symbol to be left
# undefined, so any of them the SDK or backports do define still binds normally, and the rest
# stay as dynamic-lookup undefineds that the post-link weaken step then marks weak-import.
stock_classes="$HOME/.charon/dyld/6.0/classes_armv7.json"
undef_flags=""
if [ -f "$stock_classes" ]; then
  d='$'
  { nm -u "$input" 2>/dev/null | sed -n 's/^_OBJC_CLASS_\$_//p'
    for im in $extra_images; do nm -u "$im" 2>/dev/null | sed -n 's/^_OBJC_CLASS_\$_//p'; done
  } | sort -u > "$out/imported-classes-pre.txt"
  { python3 -c "import json; print('\n'.join(json.load(open('$stock_classes'))['classes']))"
    for l in $backport_libs; do nm -gj "$l" 2>/dev/null | sed -n 's/^_OBJC_CLASS_\$_//p'; done
    sed -n 's/^_OBJC_CLASS_\$_//p' "$out/guest-resolved.txt"
  } | sort -u > "$out/covered-pre.txt"
  for c in $(comm -23 "$out/imported-classes-pre.txt" "$out/covered-pre.txt"); do
    undef_flags="$undef_flags -Wl,-U,_OBJC_CLASS_${d}_$c"
  done
fi
xl_link() {
  xcrun clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD" -Wl,-no_pie $strip_dylibs -Wl,-no_objc_category_merging -Wl,-no_deduplicate $(cat "$out/layout.txt") \
    $lifted_objs "$out/runtime.o" "$out/bridge.o" "$out/objc_bridge.o" "$out/swift_classes.o" "$out/objc_compat.o" "$out/host.o" \
    ${XL_EXTRA_OBJ:-} \
    $backport_libs \
    $framework_flags \
    $undef_flags "$@" \
    -framework Foundation -framework CoreGraphics -framework UIKit -lobjc -lz $extra_libs -o "$out/$name" 2> "$out/link.err"
}
if ! xl_link; then
  # A symbol the bridge references can be absent from the SDK's armv7 stub yet present at runtime
  # (e.g. kUTTypeTIFF from MobileCoreServices, deprecated in the modern SDK). Permit exactly the
  # symbols ld reported undefined and relink; they resolve dynamically at load, like the
  # uncovered-class -U set. A genuinely missing symbol then surfaces at load, not as a build wall.
  retry=$(grep -oE '"_[A-Za-z0-9_$]+", referenced' "$out/link.err" | sed -E 's/"([^"]+)", referenced/-Wl,-U,\1/' | sort -u | tr '\n' ' ')
  cat "$out/link.err" >&2
  if [ -n "$retry" ]; then
    echo "relinking, permitting undefined-at-link (resolve at runtime): $retry"
    xl_link $retry || { cat "$out/link.err" >&2; exit 1; }
  else
    exit 1
  fi
fi
python3 "$LAB/scripts/rename_sections.py" "$out/$name"
# Weak-bind uncovered class references (general load-enabler): an app imports iOS 7+ ObjC classes
# that neither stock iOS 6 nor the linked backports provide. Left as hard imports, dyld aborts the
# whole load; marked weak, dyld binds them to nil and the app loads, faulting only if one is used.
# uncovered = imported _OBJC_CLASS_$_ − stock-6.0 classes − linked-backport classes.
stock_classes="$HOME/.charon/dyld/6.0/classes_armv7.json"
if [ -f "$stock_classes" ]; then
  nm -u "$out/$name" | sed -n 's/^_OBJC_CLASS_\$_//p' | sort -u > "$out/imported-classes.txt"
  { python3 -c "import json,sys; print('\n'.join(json.load(open('$stock_classes'))['classes']))"
    # nm -gj must be one file at a time (multi-file invocation prints nothing)
    for l in $backport_libs; do nm -gj "$l" 2>/dev/null | sed -n 's/^_OBJC_CLASS_\$_//p'; done
  } | sort -u > "$out/covered-classes.txt"
  comm -23 "$out/imported-classes.txt" "$out/covered-classes.txt" | sed 's/^/_OBJC_CLASS_$_/' > "$out/uncovered-classes.txt"
  if [ -s "$out/uncovered-classes.txt" ]; then
    echo "weak-binding $(wc -l < "$out/uncovered-classes.txt" | tr -d ' ') uncovered class ref(s)"
    python3 "$LAB/scripts/weaken_classrefs.py" "$out/$name" "$out/uncovered-classes.txt"
  fi
fi
ldid -S "$out/$name"
nm "$out/$name" | awk '$3 ~ /^_xl_guest_class_/ { if ("_xl_guest_class_" $1 != $3) { print "misplaced " $3 " at " $1; bad = 1 } } END { exit bad }'
otool -ov "$out/$name" | awk '/^[^ ]/ { class = $1 } /instanceSize +0$/ { print "zero instanceSize: " class; bad = 1 } END { exit bad }'
xmake l "$LAB/scripts/imports.lua" "$HOME/.charon/dyld/6.0/dyld_shared_cache_armv7" "$out/$name"
