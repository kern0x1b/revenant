#!/bin/sh
# run.sh — records what the system's UIKit answers for every case of device/traits11-cases.m in a Mac Catalyst binary, writes the answers where the
# device test reads them, then compiles the port's own categories over the system's classes (a category replaces the method it names) and its
# UITextInputPasswordRules and the accessors of the scroll indicator insets under names of their own (the host's UIScreen asks -isCaptured while it is made, so that file is held to the iPad 2 alone), holds them to the same records, and tells each of a list of mutants of the port apart.
set -eu
echo "FAIL host/traits11/run.sh: its Python steps are gone and not yet ported to Lua: the inline block PY at line 47; the inline block PY at line 63" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
uikit=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
build=${BUILD:-$(runs_fresh revenant-traits11)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework UIKit -framework Foundation -framework CoreGraphics"
files="UITextInputPasswordRules.m UITextInputTraits11.m UIView+InvertColors.m UIScrollView+IndicatorInsets11.m"

xcrun clang $common -I"$device" "$here/record.m" "$device/traits11-cases.m" $libs -o "$build/system"
TRAITS11_RECORDS="$build/system.json" "$build/system"
xmake l "$here/../../common/embed.lua" "$build/system.json" "$device/traits11-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/traits11_expectations/' "$device/traits11-expectations.h" && rm -f "$device/traits11-expectations.h.bak"
echo "records: $(runs_harness records "$build/system.json")"

cat > "$build/rename.h" <<'HEADER'
#define UITextInputPasswordRules RevenantUITextInputPasswordRules
#define UIScreenCapturedDidChangeNotification RevenantUIScreenCapturedDidChangeNotification
#define verticalScrollIndicatorInsets revenantVerticalScrollIndicatorInsets
#define setVerticalScrollIndicatorInsets setRevenantVerticalScrollIndicatorInsets
#define horizontalScrollIndicatorInsets revenantHorizontalScrollIndicatorInsets
#define setHorizontalScrollIndicatorInsets setRevenantHorizontalScrollIndicatorInsets
HEADER
cat > "$build/constant.m" <<'STUB'
#import <UIKit/UIKit.h>
NSNotificationName const UIScreenCapturedDidChangeNotification = @"UIScreenCapturedDidChangeNotification";
STUB
port() {
    dir=$1
    sources=""
    for each in $files; do sources="$sources $dir/$each"; done
    xcrun clang $common -include "$build/rename.h" -I"$device" -I"$uikit" "$here/record.m" "$device/traits11-cases.m" $sources "$build/constant.m" $libs -o "$dir/run"
}
mkdir -p "$build/port"
for file in $files RevenantMenus.h; do cp "$uikit/$file" "$build/port/$file"; done
port "$build/port"
TRAITS11_RECORDS="$build/port.json" "$build/port/run"
if cmp -s "$build/system.json" "$build/port.json"; then echo "port: same as the system"; else
    python3 - "$build/system.json" "$build/port.json" <<'PY'
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
for key in sorted(a):
    if a[key] != b.get(key):
        print("DIFF", key)
        print("  system", a[key][:300])
        print("  port  ", str(b.get(key))[:300])
PY
    echo "port: DIFFERS"; exit 1
fi

survived=0
mutant() {
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    for each in $files RevenantMenus.h; do cp "$uikit/$each" "$build/mutant/$each"; done
    python3 - "$build/mutant/$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
assert old in text, old
open(path, "w").write(text.replace(old, new, 1))
PY
    port "$build/mutant"
    rm -f "$build/mutant.json"
    TRAITS11_RECORDS="$build/mutant.json" timeout 60 "$build/mutant/run" > /dev/null 2>&1 || true
    if cmp -s "$build/system.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $2 -> $3"; survived=$((survived + 1)); fi
}
mutant UITextInputTraits11.m "objc_setAssociatedObject(self, &revenant_quotes_key, @(smartQuotesType)" "objc_setAssociatedObject(self, &revenant_dashes_key, @(smartQuotesType)"
mutant UITextInputTraits11.m "objc_setAssociatedObject(self, &revenant_dashes_key, @(smartDashesType)" "objc_setAssociatedObject(self, &revenant_insert_key, @(smartDashesType)"
mutant UITextInputTraits11.m "objc_setAssociatedObject(self, &revenant_insert_key, @(smartInsertDeleteType)" "objc_setAssociatedObject(self, &revenant_quotes_key, @(smartInsertDeleteType)"
mutant UITextInputTraits11.m "[passwordRules copy]" "nil"
mutant UITextInputPasswordRules.m "rules->_passwordRulesDescriptor = [passwordRulesDescriptor copy];" "rules->_passwordRulesDescriptor = @\"x\";"
mutant UITextInputPasswordRules.m "return _passwordRulesDescriptor == other || [_passwordRulesDescriptor isEqual:other];" "return YES;"
mutant UITextInputPasswordRules.m "return [[self class] passwordRulesWithDescriptor:_passwordRulesDescriptor];" "return self;"
mutant UITextInputPasswordRules.m "return YES;
}

+ (instancetype)passwordRulesWithDescriptor" "return NO;
}

+ (instancetype)passwordRulesWithDescriptor"
mutant UITextInputPasswordRules.m "[description appendString:@\">\"];" ""
mutant UIView+InvertColors.m "@(ignores ? YES : NO)" "@(NO)"
mutant UIView+InvertColors.m "return [objc_getAssociatedObject(self, &revenant_ignores_key) boolValue];" "return YES;"
mutant UIScrollView+IndicatorInsets11.m "return held ? held.UIEdgeInsetsValue : self.scrollIndicatorInsets;
}

- (void)setVerticalScrollIndicatorInsets" "return held ? held.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

- (void)setVerticalScrollIndicatorInsets"
mutant UIScrollView+IndicatorInsets11.m "return held ? held.UIEdgeInsetsValue : self.scrollIndicatorInsets;
}

- (void)setHorizontalScrollIndicatorInsets" "return held ? held.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

- (void)setHorizontalScrollIndicatorInsets"
mutant UIScrollView+IndicatorInsets11.m "            objc_setAssociatedObject(view, &revenant_vertical_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);" ""
mutant UIScrollView+IndicatorInsets11.m "            objc_setAssociatedObject(view, &revenant_horizontal_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);" ""
mutant UIScrollView+IndicatorInsets11.m "revenant_hold(self, &revenant_vertical_key, insets);" "revenant_hold(self, &revenant_horizontal_key, insets);"
mutant UIScrollView+IndicatorInsets11.m "revenant_hold(self, &revenant_horizontal_key, insets);
}

@end" "revenant_hold(self, &revenant_vertical_key, insets);
}

@end"
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
