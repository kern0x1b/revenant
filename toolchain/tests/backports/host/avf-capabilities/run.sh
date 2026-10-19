#!/bin/sh
# run.sh -- the capture-device capability members the port carries (iOS 17 and 17.2), the port against the
# host's own camera, in one binary and in one process.
#
# The same shape as tests/backports/host/avf-globals' controls phase, for the same reason: the port's code is a
# CATEGORY on AVCaptureDevice and AVCaptureDeviceFormat, and those are APPLE's classes on this host. A copy
# compiled here unchanged would replace Apple's own implementations in this process and the probe would be
# comparing the port against itself. So the copies are renamed at their @implementation lines and land on
# stand-in owners this build declares (revenant_host_AVCaptureDevice, revenant_host_AVCaptureDeviceFormat), while
# the category names stay, so a category the port spells differently still fails to compile.
#
# WHAT MAKES IT A CHECK AND NOT A COMPARISON:
#   * the member list is read from the port's registry, never typed here, and every row of it must be answered
#     on both sides: a member one side does not carry is a red;
#   * every answer is compared against expectations.tsv, which carries BOTH columns - what this host's camera
#     answers and what the port answers - and the reason where the two differ. The hardware differs (this
#     camera has reaction effects, an iPhone 4S has not), so "the two columns are equal" is not the claim;
#     "each column is the one the table names, and the port's is the answer for the port's devices" is;
#   * the two CLASS properties are read out of the APPLICATION's Info.plist, so they are asked four times
#     with four plists the harness writes itself, and the expectation for each run is COMPUTED from the plist
#     that run used. That is the check that the rule is the rule and not a constant in either direction;
#   * the run is PLANTED and the plant must go red, and CONTROL=1 puts the unmutated sources through the
#     identical path and must stay clean;
#   * a mutation that does not build is RUN FAILED, never a noticed mutation.
#
# Run DIRECTLY: three small compiles, four small runs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/generated.sh"
ensure_generated "$here" AVFoundation
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
# the generated protocol header (tools/gen writes it into .gen/AVFoundation/ on gen --all)
avf_gen=$root/packages/a/apple-backports/.gen/AVFoundation
control=${CONTROL:-0}
# AVFCAPSMUTANT=1 plants a wrong capability answer; AVFCAPSMUTANT=prefcam plants the preferred-camera pair's
# persistence away. Each is named, so a run that plants neither is not called a mutation.
mutant=${AVFCAPSMUTANT:-0}
build=${AVF_CAPS_BUILD:-$root/.agent-work/avf-capabilities-build}
rm -rf "$build"
mkdir -p "$build/src" "$build/o"

for source in AVCaptureDeviceReactions17.m AVCaptureDeviceFormatDepthZoom17.m AVCaptureDeviceCapabilities18.m \
            AVCaptureDeviceRectsOfInterest26.m AVCaptureDeviceCinematicVideo26.m \
            AVCaptureDeviceExternalSync26.m AVCaptureDeviceDynamic26.m AVCaptureDeferredStart26.m; do
    [ -f "$avf/$source" ] || {
        echo "FAIL: $avf/$source does not exist, so the surface this run checks for is not there"
        exit 1
    }
done
for header in RevenantAVCaptureDeviceReactions17.h RevenantAVCaptureDeviceCapabilities18.h \
            RevenantAVCaptureDeviceRectsOfInterest26.h RevenantAVCaptureDeviceCinematicVideo26.h \
            RevenantAVCaptureDeviceExternalSync26.h RevenantAVCaptureDeviceDynamic26.h \
            RevenantAVCaptureDeferredStart26.h; do
    [ -f "$avf/$header" ] || {
        echo "FAIL: $avf/$header does not exist, so these members are declared nowhere"
        exit 1
    }
done

# THE LIST IS BUILT FROM THE REGISTRY and the port's own headers, never typed here. For a property the
# SELECTOR THE HEADER DECLARES is asked for, so a row whose getter= is something other than the property's
# name asks a selector both sides have. A property the header does not declare is reported, not guessed at.
#
# The pair with no registry file is RevenantAVFoundationProtocols.h: the two protocol methods of the deferred-start
# family are declared THERE and not in the slice's own header, and a row whose declaration is not in a header
# this generator reads is reported as undeclared rather than asked. Its prefix (protocols) matches no registry
# file, so it contributes declarations and no rows.
#
# One header and one registry prefix per argument pair, because each slice of this family is one release's API
# in its own header and its own registry file (AVCaptureDeviceReactions17.h + reactions*.json carry the 17.0 and
# 17.2 rows, RevenantAVCaptureDeviceCapabilities18.h + capabilities18.json the 18.0 ones,
# RevenantAVCaptureDeviceRectsOfInterest26.h + rectsofinterest26.json the 26.0 rectangles and
# RevenantAVCaptureDeviceCinematicVideo26.h + cinematicvideo26.json the 26.0 Cinematic Video ones and
# RevenantAVCaptureDeviceExternalSync26.h + externalsync26.json the 26.0 external-sync ones and
# RevenantAVCaptureDeviceDynamic26.h + dynamic26.json the 26.0 dynamic-aspect-ratio, smudge-detection and
# aperture ones, and RevenantAVCaptureDeferredStart26.h + deferredstart26.json the 26.0 deferred-start ones), and
# a row is asked for through the header that declares it.
python3 - 8 "$avf/CharonAVCaptureDeviceReactions17.h:reactions" \
        "$avf/RevenantAVCaptureDeviceCapabilities18.h:capabilities18" \
        "$avf/RevenantAVCaptureDeviceRectsOfInterest26.h:rectsofinterest26" \
        "$avf/RevenantAVCaptureDeviceCinematicVideo26.h:cinematicvideo26" \
        "$avf/RevenantAVCaptureDeviceExternalSync26.h:externalsync26" \
        "$avf/RevenantAVCaptureDeviceDynamic26.h:dynamic26" \
        "$avf/RevenantAVCaptureDeferredStart26.h:deferredstart26" \
        "$avf_gen/RevenantAVFoundationProtocols.h:protocols" \
        "$root/packages/a/apple-backports/registry/AVFoundation" \
        "$build/members.tsv" <<'MEMBERS'
import json, os, re, sys
# The pair COUNT is an argument of its own and not a slice's length: with four pairs, sys.argv[1:-2] is three of
# them, and the fourth header was then never read - which is exactly what happened, and the run said so
# ("no declaration in any of the port's headers for ..." for three rows whose header it was holding).
count = int(sys.argv[1])
registry, out = sys.argv[-2], sys.argv[-1]
pairs = sys.argv[2:2 + count]
if len(pairs) != count:
    raise SystemExit("this run was told %d header/prefix pairs and given %d: %s"
                     % (count, len(pairs), " ".join(sys.argv[2:])))
# every property and method the headers declare, with its owner, its accessor and whether it is a class
# member
declared = {}
rows, unnamed, refusals = [], [], []
for pair in pairs:
    header, prefix = pair.rsplit(":", 1)
    text = open(header).read()
    current = None
    for line in text.split("\n"):
        owner = re.match(r"@interface\s+(\w+)\s+\((\w+)\)", line.strip())
        if owner:
            current = (owner.group(1), owner.group(2))
            continue
        # A PROTOCOL is an owner too: the two deferred-start delegate methods are declared inside
        # @protocol AVCaptureSessionDeferredStartDelegate <NSObject> in RevenantAVFoundationProtocols.h, and a
        # generator that only knows @interface owners skips every line of a protocol body - which it did, and the
        # run then reported those two rows as undeclared while holding the header that declares them. A forward
        # declaration (`@protocol X;`) is not a body and sets no context.
        protocol = re.match(r"@protocol\s+(\w+)\s*<?", line.strip())
        if protocol and not line.strip().endswith(";"):
            current = (protocol.group(1), "protocol")
            continue
        if current is None:
            continue
        attributes = line.split("@property", 1)[1] if "@property" in line else None
        if attributes:
            getter = re.search(r"getter=(\w+)", attributes)
            rest = attributes[attributes.index(")") + 1:] if "(" in attributes else attributes
            rest = rest.split("API_AVAILABLE")[0].split("API_UNAVAILABLE")[0]
            rest = re.sub(r"<[^<>]*>", " ", rest)
            tokens = re.findall(r"\b([A-Za-z_]\w*)\b", rest)
            if not tokens:
                raise SystemExit("cannot tell the property name on this line, so this run must not guess: " + line)
            # `class` is in the attribute list, which is AFTER "@property": `@property(class, readonly) BOOL x`.
            isClass = line.split("@property", 1)[1].lstrip().startswith("(class")
            declared.setdefault((current[0], tokens[-1]), (getter.group(1) if getter else tokens[-1],
                                                      "class" if isClass else "instance"))
            continue
        signature = re.match(r"^[-+] \(([^)]*)\)\s*(\w+)\s*(:|;)", line.strip())
        if signature:
            declared.setdefault((current[0], signature.group(2)),
                                (signature.group(2), "class" if signature.group(1).startswith("instancetype") is False
                                 and signature.group(0).startswith("+") else "instance"))

# THE ROWS, and in a SECOND LOOP on purpose: a declaration in ANY header this run reads has to be visible to
# every registry file, not only to the one whose pair names that header. The two deferred-start delegate methods
# are declared in RevenantAVFoundationProtocols.h and their rows are in deferredstart26.json, and with one loop the
# second pair's declarations did not exist yet when the first pair's rows were read - so the run reported two
# rows as undeclared while holding both of the files that declare them (measured, 2026-10-03).
for pair in pairs:
    header, prefix = pair.rsplit(":", 1)
    for name in sorted(os.listdir(registry)):
        if not name.startswith(prefix) or not name.endswith(".json"):
            continue
        for entry in json.load(open(os.path.join(registry, name))).get("entries", []):
            api = entry["api"]
            if entry["kind"] == "method":
                # The member of a method row ends in a colon when it takes an argument, and `\w` does not match
                # one: the selector that missed this was every method row of this family, which is all of them
                # except the ones with no argument. The list printed "0 refusal(s) of its own" for four runs
                # running until this was read.
                match = re.match(r"^-\[(\w+) ([\w:]+)\]$", api)
                if not match:
                    continue
                # and the member is the FIRST PIECE of the selector, which is what the signature line above
                # recorded: a selector with arguments is written with all of them
                # (setFoo:bar:) and the declaration carries only the first (setFoo:). Stripping the trailing
                # colon is not enough - `rstrip(":")` leaves `setFoo:bar` - and the run then reported "no
                # declaration in any of the port's headers" for three rows whose declaration it was holding.
                owner, member, sign = match.group(1), match.group(2).split(":")[0], "-"
            elif entry["kind"] == "property":
                owner, member = api.split(".", 1)
                sign = ""
            else:
                continue
            if (owner, member) not in declared:
                unnamed.append(api)
                continue
            accessor, kind = declared[(owner, member)]
            # A METHOD row is not in the table below: its answer is either a refusal or a value that takes
            # an argument, and the member table asks members with no argument. Those two are asked by the
            # probe's own phases and compared through this same expectations.tsv, and both are listed here so
            # a registry file that grows one is reported rather than dropped.
            if entry["kind"] == "method":
                refusals.append(api)
                continue
            rows.append((api, owner, sign + accessor, kind))
if unnamed:
    raise SystemExit("no declaration in any of the port's headers for %s, so this run would ask a selector"
                     " neither side has" % " ".join(unnamed))
with open(out, "w") as handle:
    for row in rows:
        handle.write("%s\t%s\t%s\t%s\n" % row)
print("the probe is asked about %d member(s) with a value, and %d of the registry's own method rows are asked"
      % (len(rows), len(refusals)))
print("  by their own phases instead: %s" % " ".join(refusals))
MEMBERS

# THE PROLOGUE: the stand-ins with the same categories the port's sources implement, and nothing else. The
# port's OWN members are NOT declared here: what the port's copy carries is asked of the port's copy through the
# runtime, and a prologue that declared them would answer that question itself.
#
# What IS declared here is the stand-in device list, because the port's preferred-camera pair asks the release
# for its devices: `[AVCaptureDevice devicesWithMediaType:]` and `[AVCaptureDevice defaultDeviceWithMediaType:]`.
# On the real target those two are the RELEASE's own functions over the release's own cameras (which is why the
# port calls them instead of naming a position), and here they are modelled over a list this build hands them -
# which is what makes "the most recent camera is gone" askable at all.
#
# The stand-in device carries an activeFormat too, because -setAutoVideoFrameRateEnabled: asks the release's own
# -activeFormat and then this port's AVCaptureDeviceFormat category before it accepts or refuses a value, and a
# device with no format could not answer that at all: the refusal would be the probe's crash rather than the
# header's rule.
#
# The three macros at the end are what route the port's OWN call sites to the stand-in: they rename the class name
# everywhere in the copied source, in a method body as well as at an @implementation line, so the port's code
# asks the stand-in and not Apple's camera. The control that this is happening, and not the probe talking to the
# stand-in behind the port's back, is the preferred-camera phase: its steps change with the list this run hands
# the stand-in, which only the port's own code can do.
python3 - "$avf/CharonAVCaptureDeviceReactions17.h" "$avf/CharonAVCaptureDeviceCapabilities18.h" \
        "$avf/RevenantAVCaptureDeviceRectsOfInterest26.h" "$avf/RevenantAVCaptureDeviceCinematicVideo26.h" \
        "$avf/RevenantAVCaptureDeviceExternalSync26.h" "$avf/RevenantAVCaptureDeviceDynamic26.h" \
        "$avf/RevenantAVCaptureDeferredStart26.h" "$avf_gen/RevenantAVFoundationProtocols.h" \
        "$build/src/prologue.h" <<'PROLOGUE'
import re, sys
out = sys.argv[-1]
headers = sys.argv[1:-1]
text = "".join(open(header).read() for header in headers)
categories = re.findall(r"@interface\s+(\w+)\s+\((\w+)\)", text)
if len(categories) != 18:
    raise SystemExit("expected the eighteen categories these seven headers declare (three, three, one, three, two,"
                     " three and three) and found %d: %s" % (len(categories), categories))
owners = sorted(set(owner for owner, _ in categories))
if owners != ["AVCaptureDevice", "AVCaptureDeviceFormat", "AVCaptureDeviceInput", "AVCaptureOutput",
              "AVCaptureSession", "AVCaptureVideoPreviewLayer"]:
    raise SystemExit("expected the six owners these categories sit on and found %s" % owners)
lines = ["// Generated by tests/backports/host/avf-capabilities/run.sh from " + " ".join(headers) + ": stand-in",
         "// owners for the port's categories, because those classes are Apple's classes on this host and a copy",
         "// compiled here unchanged would replace their own methods in this process.",
         "#import <Foundation/Foundation.h>",
         "#import <AVFoundation/AVFoundation.h>",
         "",
         "// The stand-in device list. +devicesWithMediaType: and +defaultDeviceWithMediaType: are the release's own",
         "// functions on a real target and are implemented over this list in standins.rn; -uniqueID is how the port",
         "// names a device across a launch, so it is the one member the list carries.",
         "// AVCaptureAspectRatio is declared by the HOST SDK too, and there it is marked API_UNAVAILABLE(macos),",
         "// so a copy that spells it in a method signature does not compile against the host at all:",
         "// clang says the type is unavailable there, which is an error and not a warning.",
         "// This rename gives the copy its own name for it, which is the same arrangement the three class renames",
         "// below use, and the port's own build - the iOS SDK, where the type is available - is untouched.",
         "typedef NSString *revenant_host_AVCaptureAspectRatio NS_TYPED_ENUM;",
         "#define AVCaptureAspectRatio revenant_host_AVCaptureAspectRatio",
         "",
         "// The format is named before the device because the device holds one (activeFormat, below).",
         "@class revenant_host_AVCaptureDeviceFormat;",
         "",
         "@interface revenant_host_AVCaptureDevice : NSObject",
         "+ (void)revenant_host_setPresentDevices:(NSArray *)devices;",
         "+ (NSArray *)devicesWithMediaType:(NSString *)mediaType;",
         "+ (id)defaultDeviceWithMediaType:(NSString *)mediaType;",
         "@property(nonatomic, copy) NSString *uniqueID;",
         "@property(nonatomic, copy) NSString *localizedName;",
         "@property(nonatomic) long position;",
         "@property(nonatomic) BOOL connected;",
         "// What -setAutoVideoFrameRateEnabled: asks before it accepts or refuses a value, so the stand-in is",
         "// given one here rather than having the probe answer for it.",
         "@property(nonatomic, strong) revenant_host_AVCaptureDeviceFormat *activeFormat;",
         "// THE RELEASE'S OWN SUBSTRATE, which the 26.0 rectangles of interest are built on: a rectangle of",
         "// interest is applied through the release's point of interest (AVCaptureDevice.h:1171), so on this",
         "// host, where there is no 6.1.3 release, the stand-in carries the members that release carries. All",
         "// of them are in 6.1.3's own AVCaptureDevice (measured: tools/corpus/objc-inventory.lua over",
         "// ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7), and the two refusals below are the ones the SDK 16.4",
         "// header states for them (:1083 and :1269), which are the two the 26.2 header states for the",
         "// rectangle. The support flag is what the harness sets, so both branches of the port's rule are asked.",
         "+ (void)revenant_host_setPointsOfInterestSupported:(BOOL)supported;",
         "- (BOOL)isFocusPointOfInterestSupported;",
         "- (BOOL)isExposurePointOfInterestSupported;",
         "- (CGPoint)focusPointOfInterest;",
         "- (void)setFocusPointOfInterest:(CGPoint)point;",
         "- (CGPoint)exposurePointOfInterest;",
         "- (void)setExposurePointOfInterest:(CGPoint)point;",
         "- (BOOL)isLockedForConfiguration;",
         "- (void)lockForConfiguration;",
         "- (void)unlockForConfiguration;",
         "@end",
         "",
         "@interface revenant_host_AVCaptureDeviceFormat : NSObject",
         "@end",
         "",
         "// The input's device, which 6.1.3's own AVCaptureDeviceInput carries and the 26.0 Cinematic Video",
         "// support flag asks: that flag is the header's rule about the session's configuration, so the port",
         "// reads the device's active format. The harness hands it the same stand-in device the device rows",
         "// are asked of.",
         "// The deferred-start family's three owners. They carry NOTHING of their own: the port's categories on",
         "// them refuse or answer the header's absent case without asking the release anything, so what is",
         "// asked here is the port's own answer and Apple's, side by side.",
         "@interface revenant_host_AVCaptureOutput : NSObject",
         "@end",
         "",
         "@interface revenant_host_AVCaptureSession : NSObject",
         "@end",
         "",
         "@interface revenant_host_AVCaptureVideoPreviewLayer : NSObject",
         "@end",
         "",
         "@interface revenant_host_AVCaptureDeviceInput : NSObject",
         "+ (void)revenant_host_setDevice:(id)device;",
         "- (id)device;",
         "@end",
         ""]
for owner, category in categories:
    lines += ["@interface revenant_host_%s (%s)" % (owner, category), "@end", ""]
lines += ["// The rename. Defined after every declaration above, which already carry the stand-in names.",
          "#define AVCaptureDevice revenant_host_AVCaptureDevice",
          "#define AVCaptureDeviceFormat revenant_host_AVCaptureDeviceFormat",
          "#define AVCaptureDeviceInput revenant_host_AVCaptureDeviceInput",
         "#define AVCaptureOutput revenant_host_AVCaptureOutput",
         "#define AVCaptureSession revenant_host_AVCaptureSession",
         "#define AVCaptureVideoPreviewLayer revenant_host_AVCaptureVideoPreviewLayer",
          ""]
open(out, "w").write("\n".join(lines) + "\n")
print("the host build's prologue declares %d stand-in categories over %d stand-in owners, and renames their"
      % (len(categories), len(owners)))
print("  owner names in the port's sources, in a method body as well as at an @implementation line")
PROLOGUE
# The stand-ins' own OBJECTS, in a source of their own and not in the prologue: the prologue is prepended to
# both copies, so an @implementation in it would define each class twice ("duplicate symbol
# _OBJC_CLASS_$_revenant_host_AVCaptureDevice").
{
    echo '#import "prologue.h"'
    cat <<'STANDINS'

// The list this build hands the port. One entry per camera of a device of this port's bands.
static NSArray *revenant_host_present_devices;

@implementation revenant_host_AVCaptureDevice

+ (void)revenant_host_setPresentDevices:(NSArray *)devices
{
    revenant_host_present_devices = [devices copy];
}

// "+devicesWithMediaType: ... devices currently connected and available for capture" (AVCaptureDevice.h:105):
// a camera that is not connected is not one of them, which is the whole point of the history phase.
+ (NSArray *)devicesWithMediaType:(NSString *)mediaType
{
    NSMutableArray *found = [NSMutableArray array];
    for (id device in revenant_host_present_devices)
        if ([(id)device connected])
            [found addObject:device];
    return found;
}

// "+defaultDeviceWithMediaType: ... will return the built in camera that is primarily used for capture and
// recording" (AVCaptureDevice.h:120). What it models: the first connected video device of that list, which on a
// device of this port's bands is the camera on the back - measured on an iPhone 4S in
// tests/backports/device/avcapture.m:91, where +defaultDeviceWithDeviceType:mediaType:position: answers
// firstObject of the discovery list and that list is ordered back before front
// (facts/AVFoundation/AVCaptureDeviceDiscovery.md). Nothing in the port depends on that rule: the port asks
// this function, so the release's own answer is what it gets.
+ (id)defaultDeviceWithMediaType:(NSString *)mediaType
{
    return [[self devicesWithMediaType:mediaType] firstObject];
}

// THE RELEASE'S OWN SUBSTRATE, over the stand-in. 6.1.3's AVCaptureDevice owns every member below
// (tools/corpus/objc-inventory.lua over the 6.1.3 armv7 cache), and the rules here are the ones the SDK 16.4
// header states for them and nothing else: a point of interest defaults to (0.5, 0.5), a setter refuses with
// NSGenericException while the configuration lock is not held and with NSInvalidArgumentException where the
// device does not support the point (AVCaptureDevice.h:1083 for the focus pair, :1269 for the exposure pair).
// The port's 26.0 rectangle object asks all of this, so the harness has to answer it; what it does NOT answer
// is the rectangle itself, which is the port's own and is asked of the port's own copy.
static BOOL revenant_host_points_supported = YES;
static BOOL revenant_host_locked = NO;
static CGPoint revenant_host_focus_point = { 0.5, 0.5 };
static CGPoint revenant_host_exposure_point = { 0.5, 0.5 };

+ (void)revenant_host_setPointsOfInterestSupported:(BOOL)supported
{
    revenant_host_points_supported = supported;
}

- (BOOL)isLockedForConfiguration
{
    return revenant_host_locked;
}

- (void)lockForConfiguration
{
    revenant_host_locked = YES;
}

- (void)unlockForConfiguration
{
    revenant_host_locked = NO;
}

- (BOOL)isFocusPointOfInterestSupported
{
    return revenant_host_points_supported;
}

- (BOOL)isExposurePointOfInterestSupported
{
    return revenant_host_points_supported;
}

- (CGPoint)focusPointOfInterest
{
    return revenant_host_focus_point;
}

- (void)setFocusPointOfInterest:(CGPoint)point
{
    if (!revenant_host_locked)
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"setFocusPointOfInterest: cannot be set without first"
                                               " successfully gaining exclusive ownership of the device using"
                                               " -lockForConfiguration:"
                                     userInfo:nil];
    if (!revenant_host_points_supported)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"*** -[AVCaptureDevice setFocusPointOfInterest:] Not supported -"
                                               " use -isFocusPointOfInterestSupported"
                                     userInfo:nil];
    revenant_host_focus_point = point;
}

- (CGPoint)exposurePointOfInterest
{
    return revenant_host_exposure_point;
}

- (void)setExposurePointOfInterest:(CGPoint)point
{
    if (!revenant_host_locked)
        @throw [NSException exceptionWithName:NSGenericException
                                       reason:@"setExposurePointOfInterest: cannot be set without first"
                                               " successfully gaining exclusive ownership of the device using"
                                               " -lockForConfiguration:"
                                     userInfo:nil];
    if (!revenant_host_points_supported)
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"*** -[AVCaptureDevice setExposurePointOfInterest:] Not supported -"
                                               " use -isExposurePointOfInterestSupported"
                                     userInfo:nil];
    revenant_host_exposure_point = point;
}

@end

@implementation revenant_host_AVCaptureDeviceFormat

@end

// The input the 18.0 and 26.0 slices' members are asked of. It carries nothing of its own but the device the
// release's own input carries: the port's code reads no other member of the release's input except the values
// it keeps itself, and every answer below is the port's own category's, which is what the rename is for.
static id revenant_host_input_device;

@implementation revenant_host_AVCaptureDeviceInput

+ (void)revenant_host_setDevice:(id)device
{
    revenant_host_input_device = device;
}

- (id)device
{
    return revenant_host_input_device;
}

@end

// The deferred-start family's three owners. Empty on purpose: the port's categories on them refuse or answer
// the header's absent case without asking the release anything, so the harness asks the PORT's answer of the
// stand-in and Apple's of Apple's own class, and there is nothing to model.
@implementation revenant_host_AVCaptureOutput

@end

@implementation revenant_host_AVCaptureSession

@end

@implementation revenant_host_AVCaptureVideoPreviewLayer

@end
STANDINS
} > "$build/src/standins.rn"

# THE COPIES: the port's own header import is dropped, because on this host its @interface AVCaptureDeviceFormat
# category would collide with the macOS SDK's own declarations and its forward declarations are Apple's business.
# The class name is NOT rewritten here: the prologue's macros do it, in a method body as well as at an
# @implementation line, so the port's own `[AVCaptureDevice devicesWithMediaType:]` reaches the stand-in. Each
# copy is asserted to carry the owner lines this harness was written against, as WHOLE WORDS - a count of
# substrings would also match the port's own header import and prove nothing. The third field is that header's
# own file, and its import is asserted to occur exactly once before it is dropped: Python's str.replace on a
# missing needle is a silent no-op, and a "copied" run over a copy that lost its import would then be asked a
# question about a file that no longer is the one this harness was written against.
# The fourth field is how many bodies of the copy are expected to send a message to a renamed class, so the
# "the macros have something to rename" assertion is not applied to the format-only object, which has none.
for triple in "AVCaptureDeviceReactions17.m:RevenantAVCaptureDeviceReactions17.h:reactions17.rn:2:4" \
             "AVCaptureDeviceFormatDepthZoom17.m:RevenantAVCaptureDeviceReactions17.h:depthzoom17.rn:1:0" \
             "AVCaptureDeviceCapabilities18.m:RevenantAVCaptureDeviceCapabilities18.h:capabilities18.rn:3:0" \
             "AVCaptureDeviceRectsOfInterest26.m:RevenantAVCaptureDeviceRectsOfInterest26.h:rects26.rn:2:0" \
             "AVCaptureDeviceCinematicVideo26.m:RevenantAVCaptureDeviceCinematicVideo26.h:cinematic26.rn:3:0" \
             "AVCaptureDeviceExternalSync26.m:RevenantAVCaptureDeviceExternalSync26.h:externalsync26.rn:3:0" \
             "AVCaptureDeviceDynamic26.m:RevenantAVCaptureDeviceDynamic26.h:dynamic26.rn:3:0" \
             "AVCaptureDeferredStart26.m:RevenantAVCaptureDeferredStart26.h:deferredstart26.rn:3:0"; do
    src=$(printf '%s\n' "$triple" | cut -d: -f1)
    header=$(printf '%s\n' "$triple" | cut -d: -f2)
    python3 - "$avf/$src" "$header" "$build/src/prologue.h" \
            "$build/src/$(printf '%s\n' "$triple" | cut -d: -f3)" \
            "$(printf '%s\n' "$triple" | cut -d: -f4)" "$(printf '%s\n' "$triple" | cut -d: -f5)" <<'COPY'
import re, sys
source, header, prologue, out, expected, bodies = (sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4],
                                                  int(sys.argv[5]), int(sys.argv[6]))
text = open(source).read()
drop = '#import "%s"\n' % header
if text.count(drop) != 1:
    raise SystemExit("%s imports its own header %s %d time(s), so this copy is not the one the harness was "
                     "written against" % (source, header, text.count(drop)))
text = text.replace(drop, "")
owners = re.findall(r"^@(?:implementation|interface)\s+(AVCaptureDevice|AVCaptureDeviceFormat|AVCaptureDeviceInput|AVCaptureOutput|AVCaptureSession|AVCaptureVideoPreviewLayer)\b",
                    text, re.M)
if len(owners) != expected:
    raise SystemExit("%s names %d owner line(s) at an @implementation/@interface and this copy is written for "
                     "%d: %s" % (source, len(owners), expected, owners))
# Not vacuous: the owner names have to appear where the macros do their work, which is CODE. Comments and
# string literals are removed first, and that is not tidiness: the port's two refusal messages spell Apple's
# own selector inside a string literal on purpose, so that the reason a caller reads names AVCaptureDevice
# rather than the stand-in - and a count taken over the whole file would be counting those strings and the
# prose about them instead of the sends. A comment above a refusal that names the class is one more place the
# name occurs (the same trap the reactions plant walked into on 2026-10-03).
code = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
code = re.sub(r"//[^\n]*", " ", code)
code = re.sub(r'"(\\.|[^"\\])*"', '""', code)
found = len(re.findall(r"\[AVCaptureDevice(?:Format|Input)?\b", code))
if found != bodies:
    raise SystemExit("%s sends %d message(s) to a renamed class in code and this copy is written for %d, so"
                     " the macros would rename a different number of places than this harness was written"
                     " against" % (source, found, bodies))
open(out, "w").write(open(prologue).read() + text)
print("the copy of %s carries the prologue and names %d owner line(s) the macros will rename"
      % (source, len(owners)))
COPY
done
objects=""
for pair in "reactions17.rn:reactions17.o" "depthzoom17.rn:depthzoom17.o" \
            "capabilities18.rn:capabilities18.o" "rects26.rn:rects26.o" \
            "cinematic26.rn:cinematic26.o" "externalsync26.rn:externalsync26.o" \
            "dynamic26.rn:dynamic26.o" "deferredstart26.rn:deferredstart26.o" \
            "standins.rn:standins.o"; do
    src=${pair%%:*}; obj=${pair##*:}
    # -I"$avf" -I"$avf_gen" and -I"$build/src" and nothing else: the port's sources reach a header above their own folder by a
    # relative path, which is what the build does (modules/apple/backports.lua:928 passes only the library's own
    # folder), so a copy that needed -I"$pkg" would be a copy the build could not compile. The harness once did
    # add it, and relcheck caught the difference.
    if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -I"$build/src" -c "$build/src/$src" \
            -o "$build/o/$obj" > "$build/o/$obj.log" 2>&1; then
        echo "RUN FAILED: the port's $src did not build - a build failure is never a noticed mutation"
        head -8 "$build/o/$obj.log"
        exit 1
    fi
    [ -f "$build/o/$obj" ] || { echo "FAIL: $obj was not written, so the link below would measure nothing"; exit 1; }
    objects="$objects $build/o/$obj"
done
# The plant is applied AFTER the first compile, the only order in which the guard below can see it: a
# plant applied before it leaves the object identical to its own recompile, and the guard then refuses a
# mutation that did happen.
if [ "$mutant" != 0 ] && [ "$control" = 0 ]; then
    # Each plant names the copy it applies to, because the two slices of this family are two files and a
    # needle that is not in the file it is aimed at is refused below rather than silently reported as applied.
    case "$mutant" in
    1|reactions)  plant=reactions;   target=reactions17 ;;
    prefcam)      plant=prefcam;     target=reactions17 ;;
    capabilities) plant=capabilities; target=capabilities18 ;;
    multichannel) plant=multichannel; target=capabilities18 ;;
    rectsupport)  plant=rectsupport;  target=rects26 ;;
    syncmin)      plant=syncmin;      target=externalsync26 ;;
    smudge)       plant=smudge;       target=dynamic26 ;;
    deferred)     plant=deferred;     target=deferredstart26 ;;
    linkread)     plant=linkread;     target=deferredstart26 ;;
    cinematic)    plant=cinematic;    target=cinematic26 ;;
    *) echo "FAIL: AVFCAPSMUTANT=$mutant is not a plant this harness writes; run it as 1, as prefcam, as"
       echo "      capabilities, as multichannel, as rectsupport, as cinematic, as syncmin, as smudge or as"
       echo "      deferred or as linkread"
       exit 1 ;;
    esac
    python3 - "$build/src/$target.rn" "$plant" <<'PERTURB'
import sys
path, plant = sys.argv[1], sys.argv[2]
text = open(path).read()
# Each plant is a (before, after) pair asserted to occur EXACTLY once before anything is written: Python's
# str.replace on a missing needle is a silent no-op, and a "planted" run over an unplanted file reported a
# mutant as applied four times running (2026-10-03).
plants = {
    "reactions": ("""- (BOOL)canPerformReactionEffects
{
    return NO;
}""", """- (BOOL)canPerformReactionEffects
{
    return YES; /* PLANTED */
}"""),
    "prefcam": ("""    [[NSUserDefaults standardUserDefaults] setObject:[history copy]
                                              forKey:REVENANT_CAPTURE_USER_PREFERRED_HISTORY_KEY];""",
                 """    /* PLANTED: the choice is not persisted, so the next launch forgets it. */
    (void)[history copy];"""),
    # The 18.0 slice's first plant. A format that claims the auto video frame rate makes two rows differ at
    # once: the format's own answer, and -setAutoVideoFrameRateEnabled:, which refuses on this port only
    # because that answer is NO. So the plant cannot be seen by one row and missed by the other.
    "capabilities": ("""- (BOOL)isAutoVideoFrameRateSupported
{
    return NO;
}""", """- (BOOL)isAutoVideoFrameRateSupported
{
    return YES; /* PLANTED */
}"""),
    # And its second: an input that supports every multichannel audio mode makes the three support rows and
    # the two setter refusals differ, which is the whole of the rule -isMultichannelAudioModeSupported: is for.
    "multichannel": ("""    return multichannelAudioMode == AVCaptureMultichannelAudioModeNone;""",
                     """    return YES; /* PLANTED */"""),
    # The 26.0 rectangle family's plant, and it is the answer the coordinator's ruling settled: a rectangle of
    # interest supported. It has to be noticed by the support row, by the rectangle, by the two default-rectangle
    # answers and by the setter cases - so a port that answers YES behind a centre-only implementation cannot
    # pass this harness.
    "rectsupport": ("""- (BOOL)isFocusRectOfInterestSupported
{
    return NO;
}""", """- (BOOL)isFocusRectOfInterestSupported
{
    return YES; /* PLANTED */
}"""),
    # The Cinematic Video family's plant, and the one that shows the input's flag is DERIVED and not written:
    # a format that claims Cinematic Video support has to move the format's own row, the input's support row
    # (which reads that format through the release's -activeFormat), the input's setter (which would then
    # accept YES) and all three focus methods (which would then return instead of refusing).
    # The external-sync family's plant: a device with a real minimum locked frame duration. Two rows have to
    # move with it - the device's own minimum and the input's support flag - because the flag is DERIVED from
    # that minimum by the header's own sentence, and that is what makes the derivation visible.
    "syncmin": ("""- (CMTime)minSupportedLockedVideoFrameDuration
{
    return kCMTimeInvalid;
}""", """- (CMTime)minSupportedLockedVideoFrameDuration
{
    return CMTimeMake(1, 60); /* PLANTED */
}"""),
    # The dynamic family's plant: a format that reports a real minimum simulated aperture. Three rows have to
    # move with it - the format's own minimum, the input's aperture (which the setter then accepts) and the
    # input's aperture value - so a port that refused the aperture unconditionally would be caught.
    "smudge": ("""- (float)minSimulatedAperture
{
    return 0.0f;
}""", """- (float)minSimulatedAperture
{
    return 2.0f; /* PLANTED */
}"""),
    # The deferred-start family's plant: a session that supports a deferred start by hand. Everything the
    # header ties to that flag has to move with it - the flag itself, and -setAutomaticallyRunsDeferredStart:
    # false, which refuses exactly because the flag is NO.
    "deferred": ("""- (BOOL)isManualDeferredStartSupported
{
    return NO;
}""", """- (BOOL)isManualDeferredStartSupported
{
    return YES; /* PLANTED */
}"""),
    # And the linked-on-or-after read itself: asking about a version every band already passes. A band links
    # against 16.4, so a comparison against 4.0 is TRUE where it must be false, and the session's default row
    # moves the wrong way - which the two-build check above sees as well as the table.
    "linkread": ("""    return revenant_program_linked_on_or_after(26.0, 0);""",
                 """    return revenant_program_linked_on_or_after(4.0, 0); /* PLANTED */"""),
    "cinematic": ("""- (BOOL)isCinematicVideoCaptureSupported
{
    return NO;
}""", """- (BOOL)isCinematicVideoCaptureSupported
{
    return YES; /* PLANTED */
}"""),
}
before, after = plants[plant]
if text.count(before) != 1:
    raise SystemExit("the %s mutation target is not unique (%d matches), so this run proves nothing"
                     % (plant, text.count(before)))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the %s mutation did not take, so this run proves nothing" % plant)
open(path, "w").write(out)
print("# the mutation applied: " + {"reactions": "-canPerformReactionEffects answers YES for a camera with no"
                                         " reactions",
                                     "prefcam": "+setUserPreferredCamera: no longer persists the choice",
                                     "capabilities": "every format claims auto video frame rate support, so"
                                                     " -setAutoVideoFrameRateEnabled: accepts a value too",
                                     "multichannel": "-isMultichannelAudioModeSupported: answers YES for every"
                                                     " mode, so the setter accepts Stereo and ambisonics too",
                                     "rectsupport": "a device that supports focus rectangles of interest,"
                                                     " which this release cannot weigh and this port does not claim",
                                     "syncmin": "a device with a real minimum locked frame duration, so the"
                                                " input's support flag answers YES as well",
                                     "smudge": "a format with a real minimum aperture, so the input's aperture"
                                               " is settable and kept",
                                     "deferred": "a session that supports a deferred start by hand, so"
                                                 " -setAutomaticallyRunsDeferredStart: false stops refusing",
                                     "linkread": "the linked-on-or-after read asks about version 4.0, which"
                                                " every band passes, so the session's default answers YES"
                                                " where the link says NO",
                                     "cinematic": "every format claims Cinematic Video support, so the input's"
                                                  " flag, its setter and the three focus methods follow"}[plant])
PERTURB
fi
if [ "$mutant" != 0 ] && [ "$control" = 0 ]; then
    # The plant is applied AFTER the first compile, the only order in which the guard below can see it: a
    # plant applied before it leaves the object identical to its own recompile and the guard then refuses a
    # mutation that did happen.
    before=$(shasum -a 256 "$build/o/$target.o" | cut -d' ' -f1)
    if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -I"$build/src" -c "$build/src/$target.rn" \
            -o "$build/o/$target.o" > "$build/o/$target.rebuild.log" 2>&1; then
        echo "RUN FAILED: the port's $target.rn did not build after the mutation"
        head -6 "$build/o/$target.rebuild.log"
        exit 1
    fi
    after=$(shasum -a 256 "$build/o/$target.o" | cut -d' ' -f1)
    [ "$before" != "$after" ] || {
        echo "FAIL: $target.o is byte-for-byte what it was before the mutation, so the probe links the same"
        echo "      object and this mutation can never be noticed"
        exit 1
    }
    echo "rebuilt $target.o after the mutation, and it differs: ${before%????????????????????????????????????????????????} -> ${after%????????????????????????????????????????????????}"
fi
# CoreGraphics joins the three frameworks the 26.0 rectangle rows need for CGRectNull, CGRectIsNull and
# CGRectGetMidX/Y; the port's other objects need the three that were here before it.
#
# THE PROBE IS LINKED TWICE, and the second link is what makes the 26.0 deferred-start defaults checkable at
# all: "By default, for apps that are linked on or after iOS 26, this value is true" (AVCaptureSession.h:685) is
# a property of the APPLICATION, which this port can only read out of the main executable's own load command
# (packages/a/apple-backports/RevenantProgramSDK.h). One binary answers one branch, so both are asked: the
# default link carries this host's SDK and the second carries an explicit pre-26 field. Each probe PRINTS the
# field it was linked with (a CONTROL line, read back with the port's own helper), and run.sh refuses either
# binary whose measurement does not match the branch it was linked for - so the label on a row is a measurement
# and not a claim.
link_probe() {   # $1 = output binary, $2... = extra linker flags
    output=$1
    shift
    xcrun clang -fobjc-arc -w -I"$avf" -I"$avf_gen" "$here/probe.m" $objects -framework Foundation \
        -framework AVFoundation -framework CoreMedia -framework CoreGraphics "$@" -o "$output"
}
if ! link_probe "$build/probe" > "$build/probe.log" 2>&1; then
    echo "FAIL: the probe did not build"; head -14 "$build/probe.log"; exit 1
fi
if ! link_probe "$build/probe16" -Wl,-platform_version,macos,11.0,16.4 > "$build/probe16.log" 2>&1; then
    echo "FAIL: the pre-26 probe did not build"; head -14 "$build/probe16.log"; exit 1
fi
"$build/probe" "$build/members.tsv" > "$build/table" 2> "$build/stderr" || {
    echo "FAIL: the probe did not run"; head -10 "$build/stderr"; exit 1; }
# The same arguments as the first run, with no tag: which table a row is in says which build answered it, and
# the CONTROL line in each says what that build was linked with.
"$build/probe16" "$build/members.tsv" > "$build/table16" 2> "$build/stderr16" || {
    echo "FAIL: the pre-26 probe did not run"; head -10 "$build/stderr16"; exit 1; }
# BOTH BUILDS ANSWERED, and the one the table above compares is the PRE-26 one, because that is what every band
# of this repository is: its package line names SDK 16.4 and that is the sdk field of the binary. The other
# build is here so that the rows the 26.0 header writes with a linked-on-or-after condition are checkable in
# both directions, which the check below does.
printf '' > "$build/table16moved"
mv "$build/table" "$build/table26"
mv "$build/table16" "$build/table"
mv "$build/table16moved" "$build/table16"
mv "$build/stderr" "$build/stderr26"
mv "$build/stderr16" "$build/stderr"

# 1. the controls, each named, so a run that examined nothing cannot pass
check_control() {
    line=$(grep "^CONTROL	$1	" "$build/table" | cut -f3 || true)
    [ -n "$line" ] || { echo "FAIL: control $1 printed nothing, so the run examined nothing"; exit 1; }
    case "$2" in
        ABSENT) [ "$line" = ABSENT ] || { echo "FAIL: control $1 answered [$line], expected ABSENT"; exit 1; } ;;
        *) case "$line" in HAS*|one) : ;; *) echo "FAIL: control $1 answered [$line], expected HAS"; exit 1; ;; esac ;;
    esac
    echo "ok  control $1 = $line"
}
check_control AVCaptureNoSuchClass ABSENT
check_control AVCaptureDevice HAS
check_control AVCaptureDeviceFormat HAS
check_control revenant_host_AVCaptureDevice HAS
check_control revenant_host_AVCaptureDeviceFormat HAS
check_control revenant_host_AVCaptureDeviceInput HAS
# The host's own microphone input, which the 18.0 slice's AVCaptureDeviceInput rows are asked of. Checked
# separately because this control prints a fourth field: a microphone and an input of its own are what make
# the host's column of those three rows a measurement and not an absence.
input_control=$(grep "^CONTROL	AVCaptureDeviceInput	" "$build/table" | cut -f3,4 || true)
[ "${input_control%%	*}" = "HAS" ] || {
    echo "FAIL: the host has no AVCaptureDeviceInput, so the input rows would have no host column"
    exit 1
}
case "${input_control#*	}" in
    *"microphone=one input=one") echo "ok  control AVCaptureDeviceInput = $input_control" ;;
    *) echo "FAIL: the host's input control reads [$input_control], and the input rows need a microphone and an"
       echo "      input of its own on this side too"
       exit 1 ;;
esac

# 2. every member must be answered by the PORT, and by the host unless expectations.tsv records that the host's
#    own framework does not carry it. One row is in that state, measured: this macOS's AVCaptureDevice has no
#    -cinematicVideoCaptureSceneMonitoringStatuses, so there is no host cell to read and reading one would be
#    reading nothing. A host that later gains the selector fails the run below with a message that asks for a
#    re-measurement, which is what should happen then.
host_absent=$(awk -F'\t' '$2 == "-" && $1 !~ /^#/ { print $1 }' "$here/expectations.tsv")
# THE LINKED-ON-AFTER CHECK: two probes, one linked with this host's SDK field and one with an explicit
# pre-26 field, and the rows the 26.0 header writes with a linked-on-or-after condition must answer
# DIFFERENTLY between them while every other row answers the same. Each probe prints the SDK field of its own
# image - a CONTROL line, read back with the port's own helper - and the two fields are checked against what the
# two links claim, so a link flag that did not take is caught here rather than as a silent agreement.
#
# WHY it matters: "By default, for apps that are linked on or after iOS 26, this value is true"
# (AVCaptureSession.h:685) is a property of the APPLICATION, and every band of this repository links against
# SDK 16.4 - so the answer a band gives is the pre-26 one, and the port must not read the condition as TRUE in
# one place and FALSE in another. A rule read one way in two places shows up here as a row that does not move.
answer_row_in() {   # $1 = table, $2 = api
    awk -F'\t' -v wanted="$2" '$1 == "ANSWER" && $2 == wanted { print; exit }' "$1"
}
linked16=$(grep '^CONTROL	linked-sdk	' "$build/table" | cut -f3 || true)
linked26=$(grep '^CONTROL	linked-sdk	' "$build/table26" | cut -f3 || true)
case "$linked16" in
1[6-9].*) : ;;
*) echo "FAIL: the pre-26 probe reports a linked SDK of [$linked16], so the pre-26 case is not what this run"
   echo "      claims, and the port's answer for it would be a claim rather than a measurement"
   exit 1 ;;
esac
case "$linked26" in
2[6-9].*|3*) : ;;
*) echo "FAIL: the probe linked with this host's SDK reports [$linked26], so the 26-or-later case is not what"
   echo "      this run claims"
   exit 1 ;;
esac
# The rows the header writes with that condition, and they are NOT the same kind of row:
#   moves   - the session's default (:685). The condition is the ONLY thing behind it, so it must answer
#            differently in the two builds or the condition is not being read at all.
#   pinned  - the output's default (:129), whose sentence needs three things at once: an application linked on
#            or after 26, an AVCapturePhotoOutput or AVCaptureFileOutput subclass, AND deferredStartSupported
#            ("if supported, and false otherwise"). The support flag is NO for every output on this port, so
#            this row is NO in BOTH builds whatever the link says - and it must not move, which is what makes
#            "and false otherwise" visible.
# The preview layer's default names no version at all (:271), so it must not move either.
moves=" AVCaptureSession.automaticallyRunsDeferredStart "
pinned=" AVCaptureOutput.deferredStartEnabled AVCaptureVideoPreviewLayer.deferredStartEnabled "
moved=0; disagreement=0; linked_wrong=0; pinned_wrong=0; compared_links=0; missing_in_16=0
# The rows to compare, one per line as api<TAB>host<TAB>port - NOT the ANSWER rows with their leading field,
# which is why the count below is read from this file's own lines and not from a grep for ANSWER: the file it
# used to be asked about was this one before the field was dropped, and `grep -c '^ANSWER'` on it answers 0 for
# every run, which is how a check that compares 108 rows came to print "the other 0 answers" and me to write
# "103" into the facts page by hand instead of measuring (the coordinator's finding of 2026-10-03). The guard
# below is what makes that impossible now.
awk -F'\t' '$1 == "ANSWER" { print $2 "\t" $3 "\t" $4 }' "$build/table26" > "$build/answers26"
answer_rows26=$(wc -l < "$build/answers26" | tr -d ' ')
while IFS=$(printf '\t') read -r api host26 port26; do
    case "$api" in ''|\#*) continue ;; esac
    line16=$(answer_row_in "$build/table" "$api")
    if [ -z "$line16" ]; then missing_in_16=$((missing_in_16 + 1)); continue; fi
    compared_links=$((compared_links + 1))
    [ "$host26" = "$(printf '%s\n' "$line16" | cut -f3)" ] || disagreement=$((disagreement + 1))
    port16=$(printf '%s\n' "$line16" | cut -f4)
    case "$moves" in
    *" $api "*)
        if [ "$port26" != "$port16" ]; then moved=$((moved + 1)); else disagreement=$((disagreement + 1)); fi ;;
    *)
        [ "$port26" = "$port16" ] || disagreement=$((disagreement + 1)) ;;
    esac
done < "$build/answers26"
# THE CHECK IS NOT ALLOWED TO BE VACUOUS. It must have compared every answer the 26 table holds, found each of
# them in the pre-26 table, and it must have moved the one row the header makes depend on the link alone. A run
# where the comparison covered nothing, or covered less than the table, or where the governed row did not move,
# is a run that cannot fail - and that is exactly how this check spent four runs printing ok.
if [ "$compared_links" -lt "$answer_rows26" ] || [ "$missing_in_16" != 0 ]; then
    echo "FAIL: the two linked probes were compared over $compared_links of the $answer_rows26 answers the table"
    echo "      holds ($missing_in_16 of them had no row in the other build), so this check would pass without"
    echo "      comparing anything - a vacuous check is not a check"
    exit 1
fi
if [ "$moved" -lt 1 ]; then
    echo "FAIL: no row moved between the two linked probes, so the port's linked-on-or-after read is not"
    echo "      following the binary it is in"
    exit 1
fi
# The disagreement is COUNTED and not exited on, so that a planted run reaches the verdict below and says
# "the mutation was noticed" like every other plant does; a clean run fails on it in the verdict section.
if [ "$disagreement" != 0 ]; then
    echo "note: $disagreement row(s) differ between the two linked probes where the header does not make them"
    echo "      differ, or on the host's side; the verdict below decides whether that is a noticed mutation"
fi
pinned_no=0
for api in $pinned; do
    line16=$(answer_row_in "$build/table" "$api")
    line26=$(answer_row_in "$build/table26" "$api")
    [ "$(printf '%s\n' "$line16" | cut -f4)" = "port=[0]" ] && [ "$(printf '%s\n' "$line26" | cut -f4)" = "port=[0]" ] \
        && pinned_no=$((pinned_no + 1))
done
pinned_wrong=$((2 - pinned_no))
if [ "$pinned_wrong" != 0 ]; then
    echo "note: $pinned_wrong of the two rows the header pins to NO through a term this port answers NO did not"
    echo "      answer NO in both builds; the verdict below decides"
fi
echo "ok  two probes, linked against [$linked26] and [$linked16]: $moved row(s) whose only condition is the link"
echo "    moved with it, $pinned_no of the 2 rows the header pins through a term this port answers NO stayed at"
echo "    NO, and all $compared_links answers were compared - none fewer than the $answer_rows26 the table holds"

members=$(grep -c '^RESPONDS	' "$build/table" || true)
listed=$(wc -l < "$build/members.tsv" | tr -d ' ')
if [ "$members" != "$listed" ]; then
    echo "FAIL: the list names $listed members and the probe answered $members"
    exit 1
fi
# The PORT's side is never optional, for any row.
lacks=$(grep '^RESPONDS	' "$build/table" | grep 'port=no' || true)
if [ -n "$lacks" ]; then
    echo "FAIL: a member is missing from the port:"
    echo "$lacks" | head -12
    exit 1
fi
# The HOST's side is optional only where expectations.tsv says so, and then the probe's own NOHOST line is
# what says it happened.
for api in $(grep '^RESPONDS	' "$build/table" | grep 'host=no' | cut -f2 | sed 's/^-\[\([A-Za-z]*\) \(.*\)\]$/\1.\2/'); do
    # grep -x -F and not a shell glob: a command substitution drops the last line's newline, so a
    # *"\n$api\n"* pattern misses the final entry of the list - and a check that misses is worse than none.
    if printf '%s\n' "$host_absent" | grep -x -F -q "$api"; then
        if ! grep -q "^NOHOST	$api\$" "$build/table"; then
            echo "FAIL: expectations.tsv records no host column for $api, but the probe did not print a NOHOST"
            echo "      line for it, so this run cannot tell an absent host from an unasked one"
            exit 1
        fi
        echo "ok  $api is asked of the port alone: expectations.tsv records no host column and the probe"
        echo "    printed NOHOST for it"
    else
        echo "FAIL: $api is missing from the host's own framework and expectations.tsv has a host answer for it,"
        echo "      so either the table is stale or the host gained the selector: re-measure and update the table"
        exit 1
    fi
done
echo "ok  $members members are answered by both sides, or by the port alone where the table says the host has none"

# 3. the answers, each against the table. BOTH columns: the host's is measured here and the port's is the
#    answer for the port's own devices, and where they differ the table says why.
# ONE LOOKUP, and it matches whole fields rather than a pattern. A row's name is a member selector, and a
# selector written -[AVCaptureDeviceInput isMultichannelAudioModeSupported:] has both a [ and a ] in it: in a
# basic regular expression that pair is a bracket expression, so "grep "^ANSWER\t$api\t"" never matched the
# method rows of this family and the run reported no row for a row the probe had printed. awk compares the
# field with the string and cannot read a pattern into it.
answer_row() {
    awk -F'\t' -v wanted="$1" '$1 == "ANSWER" && $2 == wanted { print; exit }' "$build/table"
}
compared=0; wrong=0; : > "$build/wrong.log"
while IFS=$(printf '\t') read -r api host port why; do
    case "$api" in ''|\#*) continue ;; esac
    line=$(answer_row "$api")
    [ -n "$line" ] || { echo "FAIL: the probe printed no ANSWER row for $api"; exit 1; }
    got_host=$(printf '%s\n' "$line" | cut -f3)
    got_port=$(printf '%s\n' "$line" | cut -f4)
    want_host="host=[$host]"
    want_port="port=[$port]"
    ok=1
    # A host cell of "-" is the row expectations.tsv records as one the host's own framework does not carry:
    # the probe prints an empty host cell for it (and a NOHOST line), and only the port's answer is compared.
    [ "$host" = "-" ] || [ "$got_host" = "$want_host" ] || ok=0
    [ "$got_port" = "$want_port" ] || ok=0
    compared=$((compared + 1))
    if [ "$ok" = 0 ]; then
        wrong=$((wrong + 1))
        printf 'DIFFERS\t%s\twant %s %s\tgot %s %s\n' "$api" "$want_host" "$want_port" "$got_host" "$got_port" \
            >> "$build/wrong.log"
    fi
done < "$here/expectations.tsv"

# 4. THE PREFERRED-CAMERA PAIR. Five rules of the header (AVCaptureDevice.h:661-663 for the user's choice, :674
#    for the system's) and one step each, so none of them can be a constant that happens to be right for one
#    step. The expectation for every step is computed HERE from the fixture that step used - the list of cameras
#    the stand-in was given and the choice the probe made before it - by a second implementation of the four
#    rules in python, and then compared with what the port answered. A model that repeats the port's code would
#    only test that it is self-consistent, so the model is written from the header's sentences:
#
#      the most recent entry of the history that is in the list of connected cameras now, else the release's own
#      best present camera once the history is not empty, else nil while nothing was ever chosen;
#      the system's answer is the user's answer, or that same best camera;
#      a nil set adds nothing to the history.
cat > "$build/prefcam-fixture.tsv" <<'FIXTURE'
# step	cameras the stand-in is given	choice the probe makes before the step	a nil set after it	cleared before it
before-any-set	back-camera,front-camera	-	no	no
after-front-is-chosen	back-camera,front-camera	front-camera	no	no
after-back-is-chosen	back-camera,front-camera	back-camera	no	no
after-nil-is-set	back-camera,front-camera	-	yes	no
most-recent-gone-next-best-answers	front-camera	-	no	no
no-camera-at-all	-	-	no	no
history-exhausted	back-camera	front-camera	no	yes
nothing-ever-chosen	back-camera,front-camera	-	no	yes
FIXTURE
#    One python block, run once: it writes what differs to the log and prints "compared wrong" for the verdict
#    below, so the counts and the differences come from the same pass and cannot disagree.
: > "$build/prefcam-wrong.log"
: > "$build/persist-wrong.log"
python3 - "$build/table" "$build/prefcam-fixture.tsv" "$build/prefcam-wrong.log" > "$build/prefcam-counts" <<'PREFCAM'
import sys
table, fixture, log = sys.argv[1], sys.argv[2], sys.argv[3]
DEPTH = 3                                   # the port's history depth; the header says "a short history"
seen = {}
for line in open(table):
    fields = line.rstrip("\n").split("\t")
    if len(fields) >= 5 and fields[0] == "PREFCAM" and fields[1] != "host":
        seen[fields[1]] = (fields[2], fields[3], fields[4])
host = [line.rstrip("\n").split("\t") for line in open(table) if line.startswith("PREFCAM\thost\t")]
if not host or "auth=0 (notDetermined)" not in host[0][2]:
    raise SystemExit("the host line does not carry this process's camera authorization, so the host's nil for"
                     " the preferred-camera pair cannot be read for what it is: %s" % (host[0][2] if host else "(no line)"))
history, compared, wrong = [], 0, 0
with open(log, "w") as handle:
    for line in open(fixture):
        if line.startswith("#") or not line.strip():
            continue
        step, cameras, chosen, nil_set, cleared = line.rstrip("\n").split("\t")
        if cleared == "yes":
            history = []
        if chosen != "-":
            history = [chosen] + [entry for entry in history if entry != chosen]
            del history[DEPTH:]
        present = [camera for camera in cameras.split(",") if camera != "-"]
        user = next((entry for entry in history if entry in present),
                    present[0] if (present and history) else None)
        system = user if user else (present[0] if present else None)
        stored = "%d %s [%s]" % (len(history), "entry" if len(history) == 1 else "entries", ",".join(history))
        want = ("user=[%s]" % (user or "nil"), "system=[%s]" % (system or "nil"), "defaults=[%s]" % stored)
        compared += 1
        got = seen.get(step)
        if got is None:
            wrong += 1
            handle.write("%s\twant %s %s %s\tgot (no PREFCAM row for this step)\n"
                         % (step, want[0], want[1], want[2]))
        elif got != want:
            wrong += 1
            handle.write("%s\twant %s %s %s\tgot %s %s %s\n"
                         % (step, want[0], want[1], want[2], got[0], got[1], got[2]))
print(compared, wrong)
PREFCAM
read -r compared_prefcam wrong_prefcam < "$build/prefcam-counts"
echo "note: the host's own preferred-camera line, with this process's camera authorization beside it:"
grep "^PREFCAM	host	" "$build/table" | sed 's/^/note: /'

# 5. PERSISTENCE ACROSS LAUNCHES. Two processes of one bundle: the first chooses a camera, the second only
#    reads. The header's promise is "across app launches and reboots" (:661), so a value kept in one process's
#    own memory cannot answer it.
mkdir -p "$build/two-launches.app/Contents/MacOS"
cp "$build/probe" "$build/two-launches.app/Contents/MacOS/probe"
cat > "$build/two-launches.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>probe</string>
  <key>CFBundleIdentifier</key><string>org.revenant.probe.avf-two-launches</string>
  <key>CFBundleName</key><string>avf-two-launches</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
"$build/two-launches.app/Contents/MacOS/probe" "$build/members.tsv" set > "$build/launch1.table" 2>&1 || {
    echo "FAIL: the first launch of the persistence pair did not run"; head -8 "$build/launch1.table"; exit 1; }
"$build/two-launches.app/Contents/MacOS/probe" "$build/members.tsv" read > "$build/launch2.table" 2>&1 || {
    echo "FAIL: the second launch of the persistence pair did not run"; head -8 "$build/launch2.table"; exit 1; }
first=$(grep "^PERSIST	first-launch	" "$build/launch1.table" | cut -f3 || true)
second=$(grep "^PERSIST	second-launch	" "$build/launch2.table" | cut -f3 || true)
# Nothing here exits: a planted run has to reach the verdict below, which is where "the mutation was noticed" is
# decided over the table, the steps and this pair together.
persist_wrong=0
[ -n "$first" ] && [ -n "$second" ] || {
    echo "FAIL: a launch of the persistence pair printed no PERSIST line, so nothing was compared"
    echo "      first=[$first] second=[$second]"
    exit 1
}
echo "      across two launches of one bundle: the first chose [$first], the second read [$second]"
if [ "$first" != front-camera ] || [ "$second" != front-camera ]; then
    persist_wrong=$((persist_wrong + 1))
    {
        echo "DIFFERS	persistence	AVCaptureDevice.h:661 promises the choice across app launches and"
        echo "    reboots, and the first launch left [$first] while the second read [$second]"
    } >> "$build/persist-wrong.log"
fi
# And a bundle of its own must see nothing: the choice is the application's, not the system's.
mkdir -p "$build/other-launch.app/Contents/MacOS"
cp "$build/probe" "$build/other-launch.app/Contents/MacOS/probe"
sed 's/org.revenant.probe.avf-two-launches/org.revenant.probe.avf-other-launch/' \
    "$build/two-launches.app/Contents/Info.plist" > "$build/other-launch.app/Contents/Info.plist"
"$build/other-launch.app/Contents/MacOS/probe" "$build/members.tsv" read > "$build/launch3.table" 2>&1 || {
    echo "FAIL: the third launch did not run"; head -8 "$build/launch3.table"; exit 1; }
third=$(grep "^PERSIST	second-launch	" "$build/launch3.table" | cut -f3 || true)
if [ "$third" != nil ]; then
    persist_wrong=$((persist_wrong + 1))
    {
        echo "DIFFERS	one-application	another bundle of its own read [$third], so what is kept is not"
        echo "    this application's own choice"
    } >> "$build/persist-wrong.log"
fi
echo "      a bundle of its own reads [$third], so what is kept is one application's own choice"
[ "$persist_wrong" = 0 ] &&
    echo "ok  the choice survives a launch and stays in the application that made it"

# 6. THE VERDICT, for a planted run and for its control. Both the table and the preferred-camera steps count: a
#    plant that only one of the two can see is a plant that proves nothing.
if [ "$mutant" != 0 ] && [ "$control" = 0 ]; then
    if [ $((wrong + wrong_prefcam + persist_wrong + linked_wrong + pinned_wrong)) = 0 ]; then
        echo "FAIL: the mutation left every answer, every step, both launches and both linked builds as they"
        echo "      were, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed: $wrong of $compared table answers, $wrong_prefcam of $compared_prefcam"
    echo "    preferred-camera steps, $persist_wrong of the two checks around surviving a launch, and"
    echo "    $((linked_wrong + pinned_wrong)) of the linked-on-or-after rows differ"
    head -4 "$build/wrong.log"
    head -4 "$build/prefcam-wrong.log"
    head -4 "$build/persist-wrong.log"
    exit 0
fi
if [ "$mutant" != 0 ] && [ "$control" != 0 ]; then
    if [ $((wrong + wrong_prefcam + persist_wrong + linked_wrong + pinned_wrong)) != 0 ]; then
        echo "FAIL: the control is not clean: $wrong of $compared table answers, $wrong_prefcam of"
        echo "      $compared_prefcam preferred-camera steps, $persist_wrong of the two checks around"
        echo "      surviving a launch and $((linked_wrong + pinned_wrong)) of the linked-on-or-after rows differ"
        echo "      through the identical path, so the red would be the path and not the mutation"
        head -4 "$build/wrong.log"
        head -4 "$build/prefcam-wrong.log"
        head -4 "$build/persist-wrong.log"
        exit 1
    fi
    echo "ok  the control is clean: the unmutated sources through the identical build-and-run path"
    exit 0
fi
if [ $((linked_wrong + pinned_wrong)) != 0 ]; then
    echo "FAIL: $((linked_wrong + pinned_wrong)) of the linked-on-or-after rows are wrong: a row whose only"
    echo "      condition is the link did not move with it, or one the header pins did not stay put"
    exit 1
fi
if [ "$persist_wrong" != 0 ]; then
    echo "FAIL: $persist_wrong of the two checks around the choice surviving a launch are not what the"
    echo "      header's rule gives"
    head -8 "$build/persist-wrong.log"
    exit 1
fi
if [ "$wrong" != 0 ]; then
    echo "FAIL: $wrong of $compared answers differ from expectations.tsv"
    head -12 "$build/wrong.log"
    exit 1
fi
echo "ok  $compared answers are the ones expectations.tsv names, the host's and the port's columns both"
if [ "$wrong_prefcam" != 0 ]; then
    echo "FAIL: $wrong_prefcam of $compared_prefcam preferred-camera steps differ from the header's rules"
    head -12 "$build/prefcam-wrong.log"
    exit 1
fi
echo "ok  $compared_prefcam preferred-camera steps are the ones the header's four rules give, computed here"
echo "    from the fixture each step used"
grep "^PREFCAM	host	" "$build/table" | sed 's/^/    the host: /'

# 7. THE FOUR INFO.PLISTS. The two class properties answer out of the APPLICATION's bundle, so the probe runs
#    as a bundle four times, with four plists this script writes, and the expectation for each run is
#    computed from the plist that run used. A rule answered with a constant cannot pass this: the two rows
#    change their answer between runs.
run_plist() {
    name=$1
    plist=$2
    bundle="$build/$name.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$build/probe" "$bundle/Contents/MacOS/probe"
    cp "$plist" "$bundle/Contents/Info.plist"
    "$bundle/Contents/MacOS/probe" "$build/members.tsv" > "$build/$name.table" 2> "$build/$name.stderr" || {
        echo "FAIL: the probe did not run with the $name Info.plist"; head -6 "$build/$name.stderr"; exit 1; }
}
# Four plists, each written with the value the key really takes, and the expectation for each run COMPUTED
# from the file that run used - read out of the plist, not remembered from the name.
#   UIBackgroundModes                          an ARRAY of strings; "voip" among them is the header's voip app
#   NSCameraReactionEffectsEnabled             true: the header's opt-in for every other application
#   NSCameraReactionEffectGesturesEnabledDefault
#                                             false is what disables gesture detection ("A value of true
#                                             enables gesture detection and a value of false disables it",
#                                             AVCaptureDevice.h:2465)
mkplist() {
    file=$1
    shift
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        echo '<plist version="1.0"><dict>'
        for key in "$@"; do
            echo "  <key>$key</key>"
            case "$key" in
                UIBackgroundModes) echo "  <array><string>voip</string></array>" ;;
                NSCameraReactionEffectGesturesEnabledDefault) echo "  <false/>" ;;
                *) echo "  <true/>" ;;
            esac
        done
        echo '</dict></plist>'
    } > "$file"
}
mkplist "$build/empty.plist"
mkplist "$build/voip.plist" UIBackgroundModes
mkplist "$build/optin.plist" NSCameraReactionEffectsEnabled
mkplist "$build/gesturesoff.plist" NSCameraReactionEffectGesturesEnabledDefault
for name in empty voip optin gesturesoff; do run_plist "$name" "$build/$name.plist"; done
for name in empty voip optin gesturesoff; do
    plist="$build/$name.plist"
    want_enabled=0
    grep -q "<key>UIBackgroundModes</key>" "$plist" && want_enabled=1
    grep -q "<key>NSCameraReactionEffectsEnabled</key>" "$plist" && want_enabled=1
    want_gestures=1
    if grep -A1 "<key>NSCameraReactionEffectGesturesEnabledDefault</key>" "$plist" | grep -q "<false/>"; then
        want_gestures=0
    fi
    got=$(grep "^ANSWER	AVCaptureDevice.reactionEffectsEnabled	" "$build/$name.table" | head -1 | cut -f4 || true)
    [ "$got" = "port=[$want_enabled]" ] || {
        echo "FAIL: with the $name Info.plist the port's reactionEffectsEnabled answered [$got], and the"
        echo "      header's rule (AVCaptureDevice.h:2448) says [$want_enabled] for that plist"
        exit 1
    }
    got=$(grep "^ANSWER	AVCaptureDevice.reactionEffectGesturesEnabled	" "$build/$name.table" | head -1 | cut -f4 || true)
    [ "$got" = "port=[$want_gestures]" ] || {
        echo "FAIL: with the $name Info.plist the port's reactionEffectGesturesEnabled answered [$got], and"
        echo "      the header's default (AVCaptureDevice.h:2461) says [$want_gestures] for that plist"
        exit 1
    }
    echo "ok  the $name Info.plist: reactionEffectsEnabled=$want_enabled, reactionEffectGesturesEnabled=$want_gestures"
done
echo "ok  over four Info.plists the port's reactionEffectsEnabled answered YES exactly for voip and for the"
echo "    NSCameraReactionEffectsEnabled opt-in, and its reactionEffectGesturesEnabled NO only for"
echo "    NSCameraReactionEffectGesturesEnabledDefault - the header's rules, not two constants"

echo "note: the host's own answers for the two class properties are the platform's rules, not this port's:"
grep "^ANSWER	AVCaptureDevice.reactionEffectsEnabled	" "$build/table"
grep "^ANSWER	AVCaptureDevice.reactionEffectGesturesEnabled	" "$build/table"
echo "note: the camera this ran against: $(grep '^CAMERA	' "$build/table")"
exit 0
