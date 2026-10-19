#!/usr/bin/env python3
"""Write the Intents registry from what the built code carries, not from a list.

An entry that says a member is implemented is worth nothing unless something checks it, and
modules/apple/backports.lua's check_registry is what checks it: it reads the classes, the
selectors and the symbols the package's libraries really export and refuses an entry that names
none of them. Writing eight hundred entries by hand would be eight hundred chances to claim a
member the library does not carry, so they are written from the generator's own report of what
it emitted, and every member the SDK declares and this delivery does not carry is written as
`absent` with the reason it is not there - a class of a later group of the same delivery, or a
header that marks the member unavailable - so that nothing is claimed in one direction and
missed in the other.

The rows come from the corpus (coordination/corpus/sdk-26.2-surface.tsv, the SDK 26.2 surface
after iOS 6.1); the `introduced` of each is the corpus's own, which is the availability the SDK's
headers give, and the release an object file is carried from is the one measure-intents.lua
measured against the armv7 release caches. The two disagree for one class of this framework
(INPaymentStatusResolutionResult: the header says 10.0, the caches say 10.3), and the caches
decide the object file while the header decides the entry, which is what each of them is for.

Usage:
    tools/intents/gen-registry.py --corpus <surface.tsv> --report <report.json>... \\
        --out <registry/Intents/ios10.json> --facts <facts/Intents/Intents.md> --release 10.0.1
"""

import argparse
import collections
import json
import os
import re
import sys

HAND_WRITTEN = {
    "INParameter",
    "INIntent", "INIntentResolutionResult", "INInteraction", "INImage", "INSpeakableString",
    "INVocabulary", "INPreferences", "INExtension", "INPaymentMethod", "INRideCompletionStatus",
}

# The class of the iOS 11.0 group that is hand written, and what it answers.
# repeated in facts/Intents/Intents.md, which the entries point at.
HAND_WRITTEN_EFFECT = {
    "INIntent": "init makes a UUID string identifier, which is the key the interaction store of "
                "this port keeps a donation under and the value the system writes itself at "
                "donation time; intentDescription is the class's own words with the framework's IN "
                "prefix and Intent suffix off, computed once and kept, since the SDK does not "
                "document how the framework derives it; setImage:forParameterNamed: and "
                "imageForParameterNamed: keep a real map of the intent's images by parameter name "
                "and keyImage returns the first parameter that has one, in parameter name order so "
                "the answer is the same on every call; the coding and copying walk the whole ivar "
                "chain, so a subclass keeps the identifier, the description and the images its "
                "parent has; donationMetadata is not answered and says so in its own entry",
    "INIntentResolutionResult": "needsValue, notRequired and unsupported each answer a new result "
                                "of the class that was asked, carrying the status the name says; "
                                "the three answers a typed resolution result is built from - a "
                                "resolved value, values to disambiguate, a value to confirm - are "
                                "read back through the four accessors of "
                                "CharonIntentsResolution.h, which is where a port reads what it "
                                "resolved, because on a release with Siri the system is the reader",
    "INInteraction": "initWithIntent:response: copies the intent and the response and makes a "
                     "UUID string identifier, and the direction is outgoing; "
                     "donateInteractionWithCompletion: stamps the date interval with the moment of "
                     "the donation, archives the interaction into this application's own store "
                     "under Application Support and calls the handler with nil, or with the error "
                     "the write failed with; the three deletion methods remove by identifier, by "
                     "group identifier and all of them, and say so the same way; the two "
                     "charon_interactions accessors read the store back, newest last",
    "INImage": "imageNamed: resolves the name in the app's own asset catalogue through UIKit and "
               "carries the image's data, and answers no image for a name the app has none of; "
               "systemImageNamed: answers the names +[UIImage systemImageNamed:] answers, through the "
               "one symbol table of the UIKit band, and no image for the rest; imageWithImageData: "
               "carries the data it is given; "
               "imageWithURL: and imageWithURL:width:height: read the URL and carry what it holds, "
               "with the size when one is given; the data, the name and the size are carried by "
               "the coding and the copy",
    "INSpeakableString": "the three initialisers keep the phrase, the pronunciation hint and the "
                         "vocabulary identifier they are given, copying each; the deprecated "
                         "initWithIdentifier: keeps the identifier as well and the identifier "
                         "accessor answers the vocabulary identifier, which is what the header's "
                         "own deprecation message says it should be used for; "
                         "initWithSpokenPhrase: keeps the phrase alone and invents no vocabulary "
                         "identifier for it; INSpeakable's own properties are carried and read",
    "INVocabulary": "sharedVocabulary is one instance for the process; setVocabularyStrings:ofType: "
                    "replaces the phrases of that type in this application's own store, in the "
                    "order they were offered; setVocabulary:ofType: keeps the spoken phrase of "
                    "each speakable value it is given; removeAllVocabularyStrings empties the "
                    "store; charon_vocabularyStringsOfType: reads a type back, which is where a "
                    "port reads what it offered, because on a release with Siri the system is the "
                    "reader",
    "INPreferences": "siriAuthorizationStatus answers INSiriAuthorizationStatusRestricted, which "
                     "is the header's own wording for a system where Siri services are restricted "
                     "and the user cannot change the answer; requestSiriAuthorization: answers the "
                     "handler with that same status instead of waiting for a prompt this release "
                     "cannot show, and does nothing for a handler of nil; siriLanguageCode answers "
                     "the language the release itself is set to, which is the one a voice would "
                     "use, since this release has no Siri setting to read",
    "INExtension": "the class carries nothing but NSObject's, as its own surface is empty; the one "
                   "requirement it inherits from INIntentHandlerProviding, handlerForIntent:, "
                   "answers the instance of the loaded class that conforms to the intent's own "
                   "handling protocol and responds to -handleIntent:, and answers nil where there "
                   "is none, which is what a release with no assistant daemon to launch an "
                   "extension has to say",
    "INPaymentMethod": "the initialiser keeps the type, the name, the identification hint and the "
                       "icon, copying each of the three objects; applePayPaymentMethod is the one "
                       "object of that kind for the whole process, of the type the header gives "
                       "and with no name, hint or icon of its own, because this release has no "
                       "image of it and no name for it",
    "INRideCompletionStatus": "the six factory methods answer a real status: completed is completed "
                              "and not outstanding, the two with a payment amount carry it, the one "
                              "with a feedback type is outstanding and carries the type, canceled "
                              "by service and canceled by the user are both canceled and neither "
                              "missed the pickup, and canceledMissedPickup is canceled and missed "
                              "it; the five derived answers - isCompleted, isCanceled, "
                              "isMissedPickup, isOutstanding, paymentAmount and feedbackType - are "
                              "computed from that state, and completionUserActivity and "
                              "defaultTippingOptions are kept",
}

HAND_WRITTEN_EFFECT["INParameter"] = (
    "parameterForClass:keyPath: keeps the class and the key path, which are the whole of what "
    "the header's two properties say a parameter is; isEqualToParameter: compares those two, so "
    "two parameters are the same parameter when they name the same class and the same key path; "
    "setIndex:forSubKeyPath: and indexForSubKeyPath: keep a real index per sub key path, and a "
    "sub key path that was never given one answers NSNotFound, which is what an NSUInteger return "
    "has to say for no index; the class and the key path and the indices are carried by the "
    "coding and the copy"
)

# What the class is where the class is one of the ten hand written ones, and what it answers.
# Every one of these lines is measured against the code in packages/a/apple-backports/Intents/ and

HAND_WRITTEN_REASON = (
    "behaviour that is more than the class's own storage, written by hand in "
    "packages/a/apple-backports/Intents/CharonIntents100.m"
)

GENERATED_REASON = (
    "a data class of the framework: every property the SDK's header declares is kept in the "
    "class's own state with the ownership the header gives it, the initialisers the header "
    "declares keep every value they are given, NSSecureCoding and NSCopying carry the whole "
    "ivar chain, and a member whose type is a class of a later group has an entry of its own "
    "below that says so"
)

GENERATED_EFFECT = (
    "every member the header declares has a body that stores or returns the class's own state; "
    "the object file is generated from the SDK's own declarations by tools/intents/gen-intents.py "
    "and this entry is written from what that generator emitted, read back out of the emitted text"
)

# The readers a class whose store the headers ask to be written carries, named the way INVocabulary's
# row names charon_vocabularyStringsOfType:. A setter whose value nothing can read back is a field
# that only grows, so each of these states a reader next to the setter that fills it.
STORE_EFFECT = {
    "INRelevantShortcutStore":
        "defaultStore is one instance for the process, which is what the header's own note asks "
        "for; setRelevantShortcuts:completionHandler: replaces the whole set rather than adding to "
        "it, as the header's note says, keeps it in the class's own state and answers the handler "
        "with no error; charon_relevantShortcuts reads the set back, which is where a port reads "
        "what it offered, because on a release with Siri the system is the reader",
    "INUpcomingMediaManager":
        "sharedManager is one instance for the process; setSuggestedMediaIntents: keeps the intents "
        "it is given in the order they were given; setPredictionMode:forType: keeps one mode per "
        "media item type and removes the entry for the enumeration own zero case; "
        "charon_suggestedMediaIntents and charon_predictionModeForType: read both back",
    "INVoiceShortcutCenter":
        "sharedCenter is one instance for the process; setShortcutSuggestions: keeps the suggestions "
        "it is given in the order they were given; getAllVoiceShortcutsWithCompletion: answers an "
        "empty array and no error, and getVoiceShortcutWithIdentifier:completion: nil and no error, "
        "because this release runs no assistant daemon and has no Shortcuts app, so no shortcut was "
        "ever added to Siri; charon_shortcutSuggestions reads the suggestions back",
}

# Rows a plain run does not reproduce, read from curated-rows.json beside this file and keyed
# "api\tkind".  The curated prose used to live only in the generated JSON, which is why the next
# generate.sh overwrote it: every other table in this file is in the tool, and a hand edit to a row's
# prose was in neither.  A key here REPLACES the emitted row whole, key order included, because these
# files' key order is not the generator's (a hand-set row carries `effect` where an emitted one does
# not) and a fixed point that is byte for byte has to carry the order too.  Replacing the row is also
# what lets an `absent` row become `implemented`; an overlay would have to invent the fields the other
# shape has.
#
# A key that matches no row this run emitted is an error, not a silent no-op: a table entry for a row
# the generator no longer writes is a claim about a row that is not there.
CURATED_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "curated-rows.json")


def curated_rows(name):
    """The curated rows for the file this run writes, keyed "api\tkind".  Nesting by file is what
    lets one invocation of this script - which writes exactly one file, and generate.sh writes all of
    them - tell "this row belongs to another file" from "this row is gone"."""
    if not os.path.exists(CURATED_PATH):
        return {}
    return json.load(open(CURATED_PATH, encoding="utf-8")).get(name, {})


def apply_curated(entries, curated):
    """Replace the rows curated-rows.json holds for this file.

    A key that matched no row this run emitted is an error rather than a silent no-op: the generator
    no longer writes that row, so the table is making a claim about a row that is not there. generate.sh
    writes every registry file, so every key in the table is checked by the end of a run.
    """
    if not curated:
        return 0
    index = {(entry["api"], entry["kind"]): n for n, entry in enumerate(entries)}
    replaced, stale = 0, []
    for key in sorted(curated):
        api, _, kind = key.partition("\t")
        where = index.get((api, kind))
        if where is None:
            stale.append(key)
            continue
        entries[where] = curated[key]
        replaced += 1
    if stale:
        raise SystemExit("curated-rows.json holds %d row(s) of this file this run emitted no row "
                         "for: %s" % (len(stale), "; ".join(stale[:5])))
    return replaced


LATER_GROUP = "a class of a group of this delivery that is not in this one"


# The members a hand written class of this delivery does not answer, and why. Empty: +[INImage
# systemImageNamed:] answers the names +[UIImage systemImageNamed:] answers, through the one symbol table
# of the UIKit band, so it is an implemented row, not an absent one.
NOT_ANSWERED = {}

# The two protocols the corpus names that no Objective-C header declares and the runtime does not load:
# the SDK's Swift overlay declares them (Swift-only, iOS 10), and there is no Objective-C protocol here
# to carry. The protocol branch skips them, so no row is written for either.
SWIFT_ONLY_PROTOCOLS = ("INIntentSetImageKeyPath", "_INIntentSetImageKeyPath")

SOURCE = ("the header of iPhoneOS 16.4 for the contract, and the armv7 release caches for the "
          "release each object file is carried from (tools/intents/measure-intents.lua)")

# The -init a class whose header marks it NS_UNAVAILABLE still answers, and the header is NOT what
# says so - the host's own IMP and the object it hands back are.  Measured, and a compile-time call is
# not what was made and could not be: the marker forbids naming the selector, so the measurement
# reads class_getMethodImplementation instead.  A row whose source does not name it is claiming a
# behaviour on the header's authority, and the header says the opposite.
#
# The measurement is tests/backports/host/intents-init/run.sh, which measures EVERY class the
# registry carries a -init row for - not eight of them by hand and the rest by the same rule
# applied to the same header, which is a claim and not a measurement.  The golden file it compares
# against is read here, per class, so a row names its own line rather than the shape of one: what
# the host answered for THIS class is what the row is about.
INIT_GOLDEN = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "tests", "backports", "host", "intents-init", "expected.txt")

INIT_SOURCE = SOURCE + (
    "; and for the -init, which the header marks unavailable on some of these classes and declares "
    "on others, the host's own answer, measured for every class this framework carries a -init row "
    "for by tests/backports/host/intents-init/run.sh: it "
    "reads class_getInstanceMethod(Cls, @selector(init)) and calls [[Cls alloc] init] through that "
    "IMP, because a compile-time call to the selector is unavailable and could not be the "
    "measurement; it looks up NSObject, NSString, INCar and INListCarsIntent first and fails if any "
    "is missing, and prints the forwarding trampoline beside three real IMPs, so a zero it reports "
    "is the host's answer and not the reader's; it compares every line against expected.txt and "
    "then re-runs itself with PLANT=one-wrong, which must FAIL. The IMP is how the answer was read, "
    "and is how the emitted body reaches the superclass, because the marker is what forbids naming "
    "the selector at compile time")


def init_golden():
    """The harness's golden lines by class, read once.

    A missing file or a line is a hard error rather than a fallback: the row's claim is that a
    measurement exists, and writing the old "it is owed" text once the harness is in the tree is
    the false claim this replaced.  Refusing is the same rule the registry check itself enforces.
    """
    global INIT_GOLDEN_LINES
    try:
        return INIT_GOLDEN_LINES
    except NameError:
        pass
    lines = {}
    try:
        with open(INIT_GOLDEN, encoding="utf-8") as handle:
            for line in handle:
                line = line.rstrip("\n")
                if not line or line.startswith("//") or line.startswith("#"):
                    continue
                fields = line.split("\t")
                lines[fields[0]] = fields[1:]
    except OSError as error:
        sys.exit("gen-registry.py: no host measurement to cite for a -init row: %s (%s). Run "
                 "sh tests/backports/host/intents-init/run.sh" % (INIT_GOLDEN, error))
    INIT_GOLDEN_LINES = lines
    return lines


def init_source(owner):
    """The source of a `-[<owner> init]` row: the harness, and this class's own line of it.

    One line of the golden file says four things the row's own claim rests on: whether the class
    DECLARES -init or takes NSObject's, what `[[Cls alloc] init]` answered through that IMP, how
    many of the properties the port synthesizes for the class were read and how many of those read
    non-nil.  A class whose line says `own` is one whose body differs from the host's, and a row
    that hid that behind "the same rule applied to the same header" was hiding a difference it was
    written to record.
    """
    fields = init_golden().get(owner)
    if not fields or len(fields) < 3:
        sys.exit("gen-registry.py: %s has no line in %s, so a -[%s init] row would cite a "
                 "measurement that does not cover it. Run sh tests/backports/host/intents-init/"
                 "run.sh --write if the host changed, and put the class in init-classes.inc if it "
                 "is new." % (owner, INIT_GOLDEN, owner))
    # The golden file spells the two facts of one line as one word: `own`/`inherit` says where the
    # IMP came from and `object`/`nil`/`threw` says what the call through it answered.
    word = fields[0]
    if not word.startswith("own") and not word.startswith("inherit"):
        sys.exit("gen-registry.py: %s reads %r in %s, which is neither an `own` nor an `inherit` "
                 "line. Re-read the header of that file before trusting a row built on it."
                 % (owner, word, INIT_GOLDEN))
    declared = "DECLARES" if word.startswith("own") else "INHERITS"
    answered = word[len("inherit"):] if word.startswith("inherit") else word[len("own"):]
    properties, non_nil = fields[1], fields[2]
    which = fields[3].strip() if len(fields) > 3 else ""
    named = which and which != "-"
    return INIT_SOURCE + (
        ". Its golden line for this class is %s, which says the class %s -init and [[%s alloc] init] "
        "through that IMP answered %s, so respondsToSelector:init is 1 by the same lookup, and the %s "
        "properties the port synthesizes for this class were read off that fresh object: %s. The "
        "harness's own counts for the whole population, and the argument behind every figure here, "
        "are in facts/Intents/Intents.md"
        % ("\\t".join([owner] + fields), declared, owner,
           {"object": "an object", "nil": "nil", "threw": "an exception it did not catch"}[answered],
           properties,
           ("%s of them read non-nil, and they are %s" % (non_nil, which)) if named and non_nil != "0"
           else ("all %s read non-nil" % non_nil if named else "none of them read non-nil")))


# The (class, selector) pairs whose body is written by hand in the generator's EXTRA_METHODS,
# read from the generator itself rather than listed again here: a second list would be a third
# thing to keep in step with the first, and this row's reason is only true if the two agree.
def hand_written_bodies():
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "gen_intents", os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen-intents.py"))
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    return set(generator.EXTRA_METHODS)


# A body written by hand in EXTRA_METHODS is a decision, not a derivation, and SOURCE names only the
# header and the release caches - which is where the CONTRACT came from and not where the answer did.
# A row whose behaviour was measured on the host says so, and says what it answered, so a reader can
# run the harness and see the same numbers. Keyed the way EXTRA_METHODS is keyed.
HAND_WRITTEN_SOURCE = {
    ("INMediaDestination", "libraryDestination"):
        SOURCE + (
            "; and the behaviour, from the host's own class rather than from the header: "
            "tests/backports/host/intents/factory-rows.m, run by "
            "tests/backports/host/intents/run-rows.sh, reads this factory through its real IMP "
            "because all four of these classes are API_UNAVAILABLE(macos) in the SDK and a "
            "compile-time call cannot be made; it answers mediaDestinationType 1 and no playlist "
            "name, and a second call is isEqual to the first. For the absence at the band ends: no "
            "release this package is gated for carries any Intents class at all, read with "
            "CHARON_ROOT=$PWD xmake l tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0 - the "
            "armv7 caches of 6.1.3 and 4.3 hold 0 of the 11378 and 7187 classes under the IN prefix, "
            "in a census whose own control found 1039 IN names on 11.0 and 12.0 (239 and 411 of "
            "them), so a zero is the release's and not the reader's. The framework arrived with "
            "iOS 10 and the armv7 ladder ends at 10.3.4, so the port has to supply the class itself"),
    ("INMediaDestination", "playlistDestinationWithName:"):
        SOURCE + (
            "; and the behaviour, from the host's own class rather than from the header: "
            "tests/backports/host/intents/factory-rows.m answers mediaDestinationType 2 and the "
            "name it was given, and nil for a nil name, which is the header's own nullable. Read "
            "through the real IMP, with the four control classes and the forwarding trampoline "
            "beside it; the class is API_UNAVAILABLE(macos) in the SDK, so a compile-time call "
            "cannot be made. For the absence at the band ends: no release this package is gated "
            "for carries any Intents class at all (tools/corpus/cache-census.lua IN 6.1.3 4.3 "
            "11.0 12.0 - 0 of 11378 and of 7187 on the two armv7 rungs, control 1039 IN names on "
            "11.0 and 12.0), so the port supplies the class itself"),
    ("INFile", "fileWithData:filename:typeIdentifier:"):
        SOURCE + (
            "; and the behaviour, from the host's own class rather than from the header: "
            "tests/backports/host/intents/factory-rows.m, run by "
            "tests/backports/host/intents/run-rows.sh, answers the bytes it was given, filename "
            "and typeIdentifier as given, fileURL nil, removedOnCompletion false, and a nil "
            "filename stays nil. For the absence at the band ends: no release this package is "
            "gated for carries any Intents class at all (tools/corpus/cache-census.lua IN 6.1.3 "
            "4.3 11.0 12.0 - 0 of 11378 and of 7187 on the two armv7 rungs, control 1039 IN names "
            "on 11.0 and 12.0), so the port supplies the class itself"),
    ("INFile", "fileWithFileURL:filename:typeIdentifier:"):
        SOURCE + (
            "; and the behaviour, from the host's own class rather than from the header: "
            "tests/backports/host/intents/factory-rows.m answers fileURL the URL it was given, "
            "filename the URL's last path component when the name is nil, typeIdentifier as given, "
            "removedOnCompletion false, and -data the file's own bytes - /etc/hosts came back as "
            "its 213 bytes and a path that does not exist as 0 - which is the header's own "
            "sentence that a file created with a URL has its contents memory mapped on access. For "
            "the absence at the band ends: no release this package is gated for carries any "
            "Intents class at all (tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0 - 0 of "
            "11378 and of 7187 on the two armv7 rungs, control 1039 IN names on 11.0 and 12.0)"),
    ("INAddTasksTargetTaskListResolutionResult",
     "confirmationRequiredWithTaskListToConfirm:forReason:"):
        SOURCE + (
            "; and the behaviour, from the host's own class rather than from the header: "
            "tests/backports/host/intents/factory-rows.m answers what the superclass's "
            "one-argument factory answers - resolutionResultCode NeedsConfirmation, the task list "
            "as the item to confirm, nothing else - and the reason is in no property either class "
            "declares, unsupportedReason staying 0, so it is kept where only this port can read "
            "it, which is the same answer +unsupportedForReason: already gives. For the absence "
            "at the band ends: no release this package is gated for carries any Intents class at "
            "all (tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0 - 0 of 11378 and of 7187 "
            "on the two armv7 rungs, control 1039 IN names on 11.0 and 12.0)"),
    ("INUserContext", "becomeCurrent"):
        SOURCE + (
            "; and the behaviour, from the host's own class rather than from the header: "
            "tests/backports/host/intents/factory-rows.m reads the class present with superclass "
            "NSObject and 0 properties of its own, its seven declared methods are initWithCoder:, "
            ".cxx_destruct, becomeCurrent, encodeWithCoder:, _init, _becomeCurrentNoHelper and "
            "_setStore: with no -init among them, and -becomeCurrent returns with no exception. "
            "The class declares no reader of its own, so a body that remembered the object would "
            "answer that the context is current and nothing the SDK declares could ever see that "
            "it is. (INImage's +systemImageNamed: is not this case: it answers the names UIKit draws.) "
            "For the absence at the band ends: no release this package is gated for carries "
            "any Intents class at all (tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0 - 0 of "
            "11378 and of 7187 on the two armv7 rungs, control 1039 IN names on 11.0 and 12.0)"),
}


def hand_written_source(owner, member):
    """The source of a row whose body EXTRA_METHODS writes, or None when it was not measured.

    Keyed the way EXTRA_METHODS is keyed, and the key is the same (owner, member) the hand-written
    test below builds, so a body and the measurement quoted for it cannot drift apart. None falls
    back to SOURCE, which is what every hand-written body whose behaviour was not measured gets.
    """
    return HAND_WRITTEN_SOURCE.get((owner, member))


def member_name(api):
    """The name the generator records a cause under, for a row of either shape.

    A method row is "-[INCar setMaximumPower:forChargingConnectorType:]" and the name is what
    follows the last space with the bracket off. A PROPERTY row is "INRelevantShortcutStore.defaultStore"
    and there is no space in it at all, so the space test alone left every property row with no
    name to look up: the cause was recorded under "defaultStore", the lookup asked under the whole
    row, it missed, and the member fell back to the group's blanket reason. That is how the four
    class properties read "a class of a later group of this same delivery" when the generator had
    recorded class_property for each of them. Both spellings are asked for, so one function serves
    the two row shapes rather than one of them being right by accident.
    """
    if " " in api:
        return api.rsplit(" ", 1)[-1][:-1]
    return api.split(".", 1)[1] if "." in api else None


def reason_for(causes, vocabulary, api, fallback):
    """The reason for a member, from the cause the generator recorded for it.

    The generator records a cause under the member's own name - "EKRecurrenceRule",
    "initWithEKRecurrenceRule:", "defaultStore" - and the registry asks under the whole row,
    "-[INDateComponentsRange EKRecurrenceRule]", "INRelevantShortcutStore.defaultStore". Every
    lookup that did only the second missed, and the member fell back to the group's blanket reason,
    which is how a row whose class this delivery carries read "a class of a later group of this
    same delivery".
    """
    name = member_name(api)
    return vocabulary.get(causes.get(api) or causes.get(name), fallback)


def generator_property_names(selector):
    """The property names one answered selector answers: its own, and a getter's name off it."""
    body = selector.partition("[")[2].partition(" ")[2].rstrip("]").strip()
    if ":" in body or not body:
        return []
    found = [body]
    if body.startswith("is") and len(body) > 2 and body[2].isupper():
        found.append(body[2].lower() + body[3:])
    return found


def spellings(selector):
    """The property names one answered selector answers: its own name, and a getter's name off it."""
    sign, owner, rest = selector.partition("[")
    name = rest.partition(" ")[2].rstrip("]").strip()
    if ":" in name or not name:
        return []
    found = [name]
    if name.startswith("is") and len(name) > 2 and name[2].isupper():
        found.append(name[2].lower() + name[3:])
    return found


def load_corpus(path, framework):
    rows = []
    for line in open(path):
        fields = line.rstrip("\n").split("\t")
        if len(fields) < 5 or fields[0] != framework:
            continue
        rows.append({"kind": fields[1], "lang": fields[2], "api": fields[3],
                     "introduced": fields[4], "deprecated": fields[5]})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--corpus", required=True)
    parser.add_argument("--report", action="append", default=None)
    parser.add_argument("--out", required=True)
    parser.add_argument("--facts", required=True)
    parser.add_argument("--merge-into", default=None,
                        help="add or replace ONLY this tool's constant rows in an existing registry file, "
                             "leaving every other row exactly as it is. A full regeneration needs the "
                             "measurement reports this tool reads for the classes, and without them it would "
                             "mark answered classes absent; the constants need no report, so they can be "
                             "written on their own and cannot be lost by a later regeneration.")
    parser.add_argument("--constants-facts", default="facts/Intents/Constants.md",
                        help="the facts page a carried constant row points at")
    parser.add_argument("--constants", default=None,
                        help="the manifest tools/intents/emit-intents-constants.py wrote: the extern "
                             "constants this package DEFINES and exports. Without it every "
                             "constant is skipped as before, which is right for an enum case and "
                             "wrong for these - see the branch below.")
    parser.add_argument("--release", required=True)
    parser.add_argument("--framework", default="Intents")
    parser.add_argument("--classes", default=None, nargs="+",
                        help="the class names this file carries, one per line, one file per group "
                             "that shares it (the two 10.x groups share ios10.json)")
    parser.add_argument("--hand-written", default="CharonIntents100.m",
                        help="the file this group's hand written classes are in")
    parser.add_argument("--causes",
                        help="the generator's own vocabulary of why a member is not answered, "
                             "written by tools/intents/gen-causes.py")
    parser.add_argument("--no-protocols", action="store_true",
                        help="this group writes no protocol row: another group's file already has it")
    parser.add_argument("--reason", default=None,
                        help="why a member whose type is a class of a later group is absent")
    options = parser.parse_args()

    answered = {}
    if options.merge_into and options.constants:
        # --report, --classes and --reason are what a FULL regeneration reads, and this path reads none
        # of them: a constant row is decided by the corpus row and the emitter's manifest, not by a
        # measurement of a class. That is why they are optional rather than required.
        manifest = json.load(open(options.constants, encoding="utf-8"))["constants"]
        corpus = load_corpus(options.corpus, "Intents")
        # A row goes in the bucket of the band that exports it, which is the same routing the driver
        # uses for its groups: 18_0 writes ios18.json and everything earlier writes ios10.json. The
        # file is a band bucket and not the row's introduced - main's own ios10.json already holds
        # rows from 10.0 to 18.0 - so `introduced` stays the exact SDK availability either way.
        later = [n for n in manifest if float(manifest[n]["introduced"]) >= 17.0]
        target = options.merge_into
        held = json.load(open(target, encoding="utf-8"))
        entries = held["entries"] if isinstance(held, dict) else held
        have = {e["api"]: i for i, e in enumerate(entries)}
        added = replaced = 0
        for row in corpus:
            if row["kind"] != "constant":
                continue
            carried = manifest.get(row["api"])
            if not carried:
                continue
            is_later = float(row["introduced"]) >= 17.0
            if is_later != (target.endswith("ios18.json")):
                continue
            entry = {"api": row["api"], "kind": "constant", "introduced": row["introduced"],
                     "minimum": "6.0", "status": "implemented",
                     "facts": options.constants_facts,
                     "source": "the value read out of the host's own Intents at runtime by dlsym, and the "
                               "object's own rung: %s, which is the release it first appears in"
                               % carried["rung"],
                     "reason": "the header declares it an extern NSString *const and the release has no such "
                               "symbol in the built libraries or the 6.1.3 cache, so the port has to export "
                               "it; the SDK's own availability for it is %s" % carried["introduced"],
                     "effect": "the symbol is there and its value is the system's own: a program that reads "
                               "it gets the same string the host holds, and the object's release rung is "
                               "%s, so a band gate sees the definition only in the bands that export it"
                               % carried["rung"]}
            if row["api"] in have:
                entries[have[row["api"]]] = entry
                replaced += 1
            else:
                entries.append(entry)
                added += 1
        with open(target, "w", encoding="utf-8") as handle:
            json.dump(held, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        print("  %s: %d constant rows added, %d replaced" % (os.path.basename(target), added, replaced))
        return 0

    vocabulary = json.load(open(options.causes)) if options.causes else {}
    causes = {}
    for path in options.report:
        for name, report in json.load(open(path)).items():
            answered.setdefault(name, {"properties": set(), "dynamic": set(), "methods": set(),
                                        "class_properties": set()})
            for kind in ("properties", "dynamic", "methods", "class_properties"):
                answered[name][kind] |= set(report.get(kind, []))
            # The generator records why it left a member out. That cause is the reason, and it is
            # the whole of N3: an entry that says "a class of a later group" for a member whose
            # class this delivery carries is a false claim, and the cause is already known.
            causes.update(report.get("causes", {}))
            # A property answered by an accessor of its own - the ones a category of the SDK's own
            # header declares, which clang will not let a class implementation synthesise - is
            # answered just the same, and the registry has to say so.
            for method in list(answered[name]["methods"]):
                for spelling in generator_property_names(method):
                    answered[name]["properties"].add(spelling)

    classes = sorted(name for name in answered if name not in HAND_WRITTEN)
    carried = sorted(set(answered) | HAND_WRITTEN)
    # Only the classes of this group are this file's business: a class of another group of the
    # same delivery is that group's entry, and a member of one of those is skipped with it.
    group = set()
    for path in options.classes:
        group |= {line.strip() for line in open(path) if line.strip()}

    # What the hand written classes answer, read back out of the same text the compiler
    # compiled: a hand written class is no less checked than a generated one, so it goes through
    # the generator's own answer_of() and not through a second reading of the text.
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "gen_intents", os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen-intents.py"))
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)

    # <repository>/tools/intents/gen-registry.py -> <repository>/packages/a/apple-backports/Intents
    here = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", "..", "packages", "a", "apple-backports", "Intents")) + "/"
    hand_text = open(here + options.hand_written, errors="replace").read()
    hand_lines = hand_text.split("\n")
    for name in group | HAND_WRITTEN:
        block, start = [], None
        for index, line in enumerate(hand_lines):
            if line.startswith("@implementation %s" % name) and \
                    line[len("@implementation %s" % name):].strip() in ("", "{"):
                start = index
                continue
            if start is not None:
                if line.startswith("@implementation ") or line.startswith("@end"):
                    break
                block.append(line)
        if not block:
            continue
        answered.setdefault(name, {"properties": set(), "dynamic": set(), "methods": set(),
                                        "class_properties": set()})
        report = generator.answer_of(block, name)
        for kind in ("properties", "dynamic", "methods", "class_properties"):
            # .get: answer_of() reports class_properties only for a GENERATED class, and the
            # hand-written ones read here go through the same function without that key.
            answered[name][kind] |= set(report.get(kind, ()))
        for method in list(answered[name]["methods"]):
            for spelling in generator_property_names(method):
                answered[name]["properties"].add(spelling)

    # A member of a hand written class is claimed only where the class's own @implementation
    # shows the accessor or the @synthesize. modules/apple/backports.lua's check_registry marks a
    # member built as soon as its owner class is exported, so a green gate says nothing about a
    # member's own accessor, and an entry that claims one the file does not have is exactly the
    # silent fake the rules forbid. This is the check that refuses to write it.
    hand_written = {name for name in HAND_WRITTEN}
    HAND_WRITTEN_BODIES = hand_written_bodies()

    entries, missing = [], collections.Counter()
    for row in load_corpus(options.corpus, options.framework):
        api, kind, intro = row["api"], row["kind"], row["introduced"]
        owner = None
        if kind == "method":
            found = re.match(r"^[-+]\[([A-Za-z_0-9]+) ", api)
            owner = found.group(1) if found else None
        elif kind == "property":
            owner = api.split(".")[0]
        if kind == "constant":
            # An ENUM CASE is the header's own: the compiler writes it into the application and the
            # package carries nothing of it, so registry/README.md gives it no entry, and the port's
            # headers bring the type down where every API that uses it is implemented. That is still true.
            #
            # An EXTERN CONSTANT the package DEFINES is a different thing entirely, and skipping it
            # was a real defect: 83 of them are compiled into packages/a/apple-backports/Intents/ and
            # the 6.1.3 cache has no such symbol, so the port has to export each one - and a
            # regeneration then dropped all 83 rows, and the gate that reads the link reported every
            # one as "built, but no entry in registry/". The rows are not written by hand: the
            # manifest is the emitter's own list of what it compiled, so the names that get a row and
            # the names that got built are the same set by construction and cannot drift.
            carried = (options.constants and json.load(open(options.constants,
                                                             encoding="utf-8"))["constants"].get(api))
            if not carried:
                continue
            entries.append({"api": api, "kind": "constant", "introduced": intro,
                            "minimum": "6.0", "status": "implemented",
                            "facts": options.constants_facts,
                            "source": "the value read out of the host's own Intents at runtime by dlsym, and "
                                      "the object's own rung: %s, which is the release it first appears in"
                                      % carried["rung"],
                            "reason": "the header declares it an extern NSString *const and the release has no "
                                      "such symbol in the built libraries or the 6.1.3 cache, so the port has "
                                      "to export it; the SDK's own availability for it is %s"
                                      % carried["introduced"],
                            "effect": "the symbol is there and its value is the system's own: a program that "
                                      "reads it gets the same string the host holds, and the object's release "
                                      "rung is %s, so a band gate sees the definition only in the bands that "
                                      "export it" % carried["rung"]})
            continue
        if kind == "enum":
            continue
        if kind == "protocol":
            # A protocol is the framework's, not one group's: it is written once, in the file of
            # the group whose classes first conform to it, because two files naming one protocol
            # stop the build with both names.
            #
            # SWIFT_ONLY_PROTOCOLS are named by the 26.2 corpus and declared by no Objective-C header
            # of the SDKs measured (iPhoneOS 16.5, macOS 27); the Swift overlay declares them, from
            # iOS 10. With no Objective-C protocol to carry, no row is written for them. Their absence
            # from the runtime is measured in tests/backports/host/intents-remaining.
            if api in SWIFT_ONLY_PROTOCOLS:
                continue
            if options.no_protocols:
                missing["protocol of another group"] += 1
                continue
            entries.append({"api": api, "kind": "protocol", "introduced": intro,
                            "minimum": "6.0", "status": "implemented", "facts": options.facts,
                            "reason": "the protocol is the SDK's own declaration, carried by the "
                                      "header once the availability of its members is lowered, and "
                                      "the members are the entries of this file",
                            "source": SOURCE})
            continue
        if kind == "typealias":
            continue
        if kind == "swift" or row["lang"] == "swift":
            # The Swift-only rows of this framework are the swift-runtime's own module and not
            # this package's; they are in the delivery of the Swift side of AppIntents.
            continue
        if owner is not None and owner not in group:
            missing["another group"] += 1
            continue
        if owner is not None and owner not in answered:
            # A member of a class this delivery does not carry is not this file's entry: it is
            # the entry of the group that carries that class, and writing it here as absent
            # would say the framework never has it.
            missing["later group"] += 1
            continue
        if owner is not None and owner in answered:
            report = answered[owner]
            if kind == "property":
                spelled = api.split(".")[1]
                if spelled in report["properties"]:
                    entries.append(implemented(api, "property", intro, owner, options.facts,
                                               where="%s's own @implementation synthesises it"
                                                     % owner if owner in hand_written else None,
                                               hand=(owner, spelled) in HAND_WRITTEN_BODIES))
                    continue
                if spelled in report["class_properties"]:
                    entries.append(implemented(api, "property", intro, owner, options.facts,
                                               hand=True))
                    continue
                if api.split(".")[1] in report["dynamic"]:
                    entries.append(absent(api, "property", intro,
                                          reason_for(causes, vocabulary, api, options.reason), options.facts))
                    missing["dynamic"] += 1
                    continue
            if kind == "method":
                if api in NOT_ANSWERED:
                    entries.append(absent(api, "method", intro, NOT_ANSWERED[api], options.facts))
                    missing["not answered"] += 1
                    continue
                if api in report["methods"]:
                    # A bare -[owner init] the generator ANSWERED is a class whose header marks
                    # -init unavailable: it emits that method for such a class and no other, forwarding
                    # through the superclass's IMP.  Every other method of the same class keeps the
                    # header's own source, which is what that method was decided on.
                    marked_init = api == "-[%s init]" % owner
                    entries.append(implemented(api, "method", intro, owner, options.facts,
                                               where="%s's own @implementation answers it"
                                                     % owner if owner in hand_written else None,
                                               source=init_source(owner) if marked_init
                                               else hand_written_source(owner, member_name(api)),
                                               hand=(owner, member_name(api)) in HAND_WRITTEN_BODIES))
                    continue
                if api.endswith("] init") or api == "-[%s init]" % owner:
                    # The fourth of the four lookups, and the busiest branch in the file: it
                    # carries the 51 rows whose class marks -init unavailable.  It had its own
                    # inline causes.get(api) and its own copy of the fallback, so a cause recorded
                    # under a bare selector was honoured in three of the four places and not here.
                    # The fallback is the argument, which is the whole point of reason_for.
                    entries.append(absent(api, "method", intro,
                                          reason_for(causes, vocabulary, api,
                                                     "the header marks the class's -init "
                                                     "unavailable, so a port cannot call it and "
                                                     "the class answers the initialiser the "
                                                     "header does declare"), options.facts))
                    missing["init"] += 1
                    continue
                # A method of a class this delivery carries, that no header declares and that the
                # generator therefore never mentioned: not_declared, not the group's blanket reason.
                # Without the fallback below this branch is the one place a carried class's member
                # still read "a class of a later group of this same delivery", which is how
                # +[INIntentResolutionResult unsupportedWithReason:] - declared by NEITHER 16.4 nor
                # 26.2 - and the five post-16.4 -[INMessage initWithIdentifier:...] rows did.
                absent_reason = reason_for(causes, vocabulary, api, None)
                if absent_reason is None:
                    absent_reason = vocabulary.get("not_declared")
                entries.append(absent(api, "method", intro, absent_reason or options.reason,
                                      options.facts))
                missing["skipped"] += 1
                continue
        if kind == "class":
            if api in group:
                entry = {"api": api, "kind": "class", "introduced": intro, "minimum": "6.0",
                         "status": "implemented", "facts": options.facts, "source": SOURCE}
                if api in HAND_WRITTEN_EFFECT:
                    entry["reason"] = HAND_WRITTEN_REASON
                    entry["effect"] = HAND_WRITTEN_EFFECT[api]
                else:
                    entry["reason"] = GENERATED_REASON
                    entry["effect"] = STORE_EFFECT.get(api, GENERATED_EFFECT)
                entries.append(entry)
                continue
            missing["another group"] += 1
            continue
        # A member of a class this delivery does carry and does not answer: a class of a later
        # group of this same delivery, or a member the SDK's own header marks unavailable. It is
        # written as absent with that reason rather than left out, so that nothing is claimed in
        # one direction and missed in the other.
        # The cause the generator recorded, and nothing else: a chain the SDK forbids, a value
        # this delivery does not carry, a class the headers only forward declare, a factory that
        # answers an array. Nothing else about the entry moves.
        # The generator records a cause under the member's own selector - "initWithEKRecurrenceRule:",
        # "EKRecurrenceRule" - and the registry is asking under the whole row: "-
        # [INDateComponentsRange EKRecurrenceRule]".  So the lookup never matched and every absent
        # row of a class this delivery carries fell through to the group's blanket reason, which
        # is why INDateComponentsRange's two EventKit rows read "a class of a later group of this
        # same delivery" when the cause the generator had recorded for one of them was
        # deferred_value and for the other now foreign_class.  The selector is tried too.
        # "a class of the same name" no: "X" is the class and "selector]" is the member, so the
        # name is what follows the LAST space with the closing bracket off, or the whole of a
        # property row's "Class.property" second field - member_name() has both spellings, and this
        # second copy of the space-only test is what left every property cause unlooked-up.
        reason = reason_for(causes, vocabulary, api, None)
        if reason is None and owner in answered:
            # The generator read every header of the SDK this port compiles against and wrote
            # down every member it declared, implemented, withheld or did not find. A member of a
            # class it implemented that it never mentioned is one no header declares.
            reason = vocabulary.get("not_declared")
        reason = reason or options.reason
        if owner in hand_written:
            # A member of a hand written class whose accessor the file does not show: the reason
            # says so, and the count says how many, so a delivery cannot quietly claim one.
            reason = ("this is a member of a hand written class and %s's @implementation shows no"
                      " accessor of that name for it, so nothing in the package answers it; the"
                      " header's declaration alone is not an implementation" % owner)
            missing["hand written without an accessor"] += 1
        entries.append(absent(api, kind, intro, reason, options.facts))
        missing["unanswered member"] += 1

    replaced = apply_curated(entries, curated_rows(os.path.basename(options.out)))
    if replaced:
        print("  %d row(s) from curated-rows.json" % replaced)
    entries.sort(key=lambda entry: (entry["kind"], entry["api"]))
    document = {"framework": options.framework, "entries": entries}
    with open(options.out, "w") as handle:
        json.dump(document, handle, indent=2)
        handle.write("\n")
    tally = collections.Counter(entry["status"] for entry in entries)
    print("%s: %d entries (%s), %d not carried: %s" %
          (options.out, len(entries), ", ".join("%s %d" % pair for pair in sorted(tally.items())),
           sum(missing.values()), dict(missing)))
    return 0


def implemented(api, kind, introduced, owner, facts, where=None, source=None, hand=None):
    """An implemented row, and WHICH body answers it.

    A body the generator wrote itself and a body written by hand in EXTRA_METHODS are both in the
    class's own generated implementation file, so saying "the generated implementation answers" is
    true of both and useless for telling them apart. A reader deciding whether a body here is a
    derivation of the header or a decision needs to know which, so the hand-written ones say so.
    """
    return {"api": api, "kind": kind, "introduced": introduced, "minimum": "6.0",
            "status": "implemented", "facts": facts,
            "reason": ("a member of %s, which %s" % (owner, where or
                       ("answers it with a body written by hand in the generator's EXTRA_METHODS"
                        if hand else "the class's own generated implementation answers"))),
            "source": source or SOURCE}


def absent(api, kind, introduced, reason, facts):
    return {"api": api, "kind": kind, "introduced": introduced, "status": "absent",
            "reason": reason,
            "effect": "the class is there and does not implement this: respondsToSelector: answers "
                      "no, and a port that reached it would not find it",
            "facts": facts}


if __name__ == "__main__":
    raise SystemExit(main() or 0)
