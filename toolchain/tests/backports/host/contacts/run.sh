#!/bin/sh
# run.sh — records what the host's Contacts answers for every case of device/contacts-cases.m in a Mac Catalyst binary, holds the port's
# Contacts classes, compiled under names of their own (Revenant<name>), to the same records, and tells apart mutants of the port.
#
# Every case builds its objects in memory: no CNContactStore instance is ever asked for a permission, a fetch or a save, because the host
# runs as whoever is signed into this Mac, and this package promised never to touch that person's own address book. What is compared is
# the value-object surface - CNContact and its values, the formatter, the vCard pair (both sides delegate to the same
# ABPersonCreateVCardRepresentationWithPeople of the host's own AddressBook.framework, so this is an exact match, not an approximation),
# groups and containers before a save, and the plain value classes beside them.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
contacts=${CONTACTS:-$here/../../../../packages/a/apple-backports/Contacts}
registry9=${REGISTRY9:-$here/../../../../packages/a/apple-backports/registry/Contacts/ios9.json}
registry10=${REGISTRY10:-$here/../../../../packages/a/apple-backports/registry/Contacts/ios10.json}
build=${BUILD:-$(runs_fresh revenant-contacts)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
frameworks="-iframework $sdk/System/iOSSupport/System/Library/Frameworks"
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk $frameworks -fobjc-arc -w"
libs="-framework Foundation"

# Nothing here needs to differ: every case avoids the one path (CNContactStore) that could disagree with the release for reasons that have
# nothing to do with this port - a store the host is not an oracle for at all, since it is never opened.
# One the host cannot answer: the macOS 26 host's CNContactFetchRequest archives rankSort as a bool and reads it back with
# decodeInt64ForKey:, so decoding its own archive raises NSInvalidUnarchiveOperationException (measured). What the port must answer
# there is pinned, from two host records that are compared: the host's archive carries the predicate
# (predicate.fetchRequestArchivesPredicate) and the host's predicate comes back equal from a secure archive
# (predicate.identifiersEqualAfterSecureRoundTrip), so a request read back keeps its predicate: "kept".
divergent="predicate.fetchRequestRoundTrip=kept"

xcrun clang $common -I"$device" "$here/record.m" "$device/contacts-cases.m" $libs -framework Contacts -o "$build/system"
CONTACTS_RECORDS="$build/system.json" "$build/system"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/system.json'))))")"

python3 "$here/rename.py" "$registry9" "$registry10" "$build/rename.h"

port() {
    dir=$1
    xcrun clang $common -include "$build/rename.h" -I"$device" -I"$contacts" "$here/record.m" "$device/contacts-cases.m" \
        "$dir"/*.m $libs -framework AddressBook -o "$dir/run"
}
rm -rf "$build/port"; mkdir -p "$build/port"
cp "$contacts"/*.m "$contacts/RevenantContacts.h" "$build/port/"
port "$build/port"
CONTACTS_RECORDS="$build/port.json" "$build/port/run"
python3 "$here/compare.py" "$build/system.json" "$build/port.json" "$divergent"
echo "port: agrees with the system on every record"

python3 "$here/expectations.py" "$build/system.json" "$divergent" "$build/expectations.json"
xmake l "$here/../../common/embed.lua" "$build/expectations.json" "$device/contacts-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/contacts_expectations/' "$device/contacts-expectations.h" && rm -f "$device/contacts-expectations.h.bak"

survived=0
mutant() {
    file=$1; from=$2; to=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$contacts"/*.m "$contacts/RevenantContacts.h" "$build/mutant/"
    python3 "$here/mutate.py" "$build/mutant/$file" "$from" "$to"
    port "$build/mutant"
    rm -f "$build/mutant.json"
    CONTACTS_RECORDS="$build/mutant.json" timeout 60 "$build/mutant/run" > /dev/null 2>&1 || true
    if cmp -s "$build/port.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $file $from -> $to"; survived=$((survived + 1)); fi
}
mutant CNPhoneNumber9.m "_revenantStringValue = [string copy];" "_revenantStringValue = @\"mutated\";"
mutant CNLabeledValue9.m "_revenantLabel = [label copy];" "_revenantLabel = @\"mutated\";"
mutant CNLabeledValue9.m "made->_revenantIdentifier = [_revenantIdentifier copy];" "made->_revenantIdentifier = [[NSUUID UUID] UUIDString];"
mutant CNPostalAddress9.m "- (NSString *)city { return [self revenant_fieldForKey:CNPostalAddressCityKey]; }" "- (NSString *)city { return [self revenant_fieldForKey:CNPostalAddressStateKey]; }"
mutant CNPostalAddressFormatter9.m "[cityLine appendString:stateZip];" "[cityLine appendString:@\"X\"];"
mutant CNContact9.m "- (NSString *)givenName { return [self revenant_stringForKey:CNContactGivenNameKey]; }" "- (NSString *)givenName { return [self revenant_stringForKey:CNContactFamilyNameKey]; }"
mutant CNContactFormatter9.m "return composite.length > 0 ? composite : nil;" "return nil;"
mutant CNGroup9.m "return _revenantName ?: @\"\";" "return @\"mutated\";"
mutant CNContactsUserDefaults9.m "return code.length > 0 ? [code lowercaseString] : @\"us\";" "return @\"\";"
mutant RevenantContactsBook.m "@\"identifier IN %@\"" "@\"identifier == %@\""
mutant RevenantContactsBook.m "[coder encodeObject:_value forKey:@\"value\"];" ";"
mutant RevenantContactsBook.m "return other->_match == _match &&" "return other->_match != _match ||"
mutant CNContactFetchRequest9.m "[coder encodeObject:_revenantPredicate forKey:@\"predicate\"];" ";"
mutant CNContactFetchRequest9.m "_revenantPredicate = [coder decodeObjectOfClass:[NSPredicate class] forKey:@\"predicate\"];" ";"
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
