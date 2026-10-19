#!/bin/sh
# run.sh - PKPaymentToken and PKPayment, the port's against the host's own PassKit, in one process.
#
# PKPayment8.m is compiled for the Mac Catalyst target, the one PassKit's own iOS surface is read through, with
# its classes renamed (revenantHost_PKPayment and revenantHost_PKPaymentToken) so the system's PassKit and the port's
# run side by side. probe.m asks both the same questions and prints SAME or FAIL for each. The renamed build and
# the probe live under the checkout's .agent-work/runs, not the system temporary directory.
#
# The mutant check is run here too: a copy of PKPayment8.m in which -initWithToken: drops the token it is given
# must make the probe FAIL, because a comparison that cannot fail decides nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/PassKit}
build=${PAYMENT_BUILD:-$(runs_fresh revenant-payment-value)}
MACOSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="-target arm64-apple-ios17.0-macabi -isysroot $MACOSX_SDK -isystem $MACOSX_SDK/System/iOSSupport/usr/include -F $MACOSX_SDK/System/iOSSupport/System/Library/Frameworks"
RENAME="-DPKPayment=revenantHost_PKPayment -DPKPaymentToken=revenantHost_PKPaymentToken -DPKPaymentRequest=revenantHost_PKPaymentRequest -DPKPaymentSummaryItem=revenantHost_PKPaymentSummaryItem -DPKPaymentOrderDetails=revenantHost_PKPaymentOrderDetails -DPKPaymentMethod=revenantHost_PKPaymentMethod"
# The port's files compile on their own: their other classes are not in this run, so their names are not renamed.
xcrun clang -fobjc-arc -w -fPIC $TARGET $RENAME -I"$port" -c "$port/PKPayment8.m" -o "$build/payment.o"
xcrun clang -fobjc-arc -w -fPIC $TARGET $RENAME -I"$port" -c "$port/PKPaymentOrderDetails16.m" -o "$build/order.o"
xcrun clang -fobjc-arc -w -fPIC $TARGET $RENAME -I"$port" -c "$port/PKPaymentMethod9.m" -o "$build/method.o"
xcrun clang -fobjc-arc -w $TARGET -I"$port" "$here/probe.m" "$build/payment.o" "$build/order.o" "$build/method.o" \
    -framework Foundation -framework PassKit -o "$build/probe"
"$build/probe"

# The mutant: the same file with -initWithToken: dropping the token. The probe must answer FAIL.
mutant="$build/mutant"
mkdir -p "$mutant"
sed -e 's/        _token = token;/        _token = nil;/' "$port/PKPayment8.m" > "$mutant/PKPayment8.m"
xcrun clang -fobjc-arc -w -fPIC $TARGET $RENAME -I"$port" -I"$mutant" -c "$mutant/PKPayment8.m" -o "$build/mutant.o"
xcrun clang -fobjc-arc -w $TARGET -I"$port" "$here/probe.m" "$build/mutant.o" "$build/order.o" "$build/method.o" \
    -framework Foundation -framework PassKit -o "$build/probe-mutant"
if "$build/probe-mutant" > "$build/mutant.out"; then
    echo "mutant: the probe did not fail on a dropped token, so it decides nothing" >&2
    exit 1
fi
echo "mutant: the probe fails on a dropped token, as it must"
