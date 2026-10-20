import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})

local D = import("intents-data", {rootdir = os.scriptdir()}).data()

local NULL = {kind = "null"}

local HAND_WRITTEN_EFFECT = {
    INIntent = "init makes a UUID string identifier, which is the key the interaction store of "
        .. "this port keeps a donation under and the value the system writes itself at "
        .. "donation time; intentDescription is the class's own words with the framework's IN "
        .. "prefix and Intent suffix off, computed once and kept, since the SDK does not "
        .. "document how the framework derives it; setImage:forParameterNamed: and "
        .. "imageForParameterNamed: keep a real map of the intent's images by parameter name "
        .. "and keyImage returns the first parameter that has one, in parameter name order so "
        .. "the answer is the same on every call; the coding and copying walk the whole ivar "
        .. "chain, so a subclass keeps the identifier, the description and the images its "
        .. "parent has; donationMetadata is not answered and says so in its own entry",
    INIntentResolutionResult = "needsValue, notRequired and unsupported each answer a new result "
        .. "of the class that was asked, carrying the status the name says; "
        .. "the three answers a typed resolution result is built from - a "
        .. "resolved value, values to disambiguate, a value to confirm - are "
        .. "read back through the four accessors of "
        .. "RevenantIntentsResolution.h, which is where a port reads what it "
        .. "resolved, because on a release with Siri the system is the reader",
    INInteraction = "initWithIntent:response: copies the intent and the response and makes a "
        .. "UUID string identifier, and the direction is outgoing; "
        .. "donateInteractionWithCompletion: stamps the date interval with the moment of "
        .. "the donation, archives the interaction into this application's own store "
        .. "under Application Support and calls the handler with nil, or with the error "
        .. "the write failed with; the three deletion methods remove by identifier, by "
        .. "group identifier and all of them, and say so the same way; the two "
        .. "revenant_interactions accessors read the store back, newest last",
    INImage = "imageNamed: resolves the name in the app's own asset catalogue through UIKit and "
        .. "carries the image's data, and answers no image for a name the app has none of; "
        .. "systemImageNamed: answers the names +[UIImage systemImageNamed:] answers, through the "
        .. "one symbol table of the UIKit band, and no image for the rest; imageWithImageData: "
        .. "carries the data it is given; "
        .. "imageWithURL: and imageWithURL:width:height: read the URL and carry what it holds, "
        .. "with the size when one is given; the data, the name and the size are carried by "
        .. "the coding and the copy",
    INSpeakableString = "the three initialisers keep the phrase, the pronunciation hint and the "
        .. "vocabulary identifier they are given, copying each; the deprecated "
        .. "initWithIdentifier: keeps the identifier as well and the identifier "
        .. "accessor answers the vocabulary identifier, which is what the header's "
        .. "own deprecation message says it should be used for; "
        .. "initWithSpokenPhrase: keeps the phrase alone and invents no vocabulary "
        .. "identifier for it; INSpeakable's own properties are carried and read",
    INVocabulary = "sharedVocabulary is one instance for the process; setVocabularyStrings:ofType: "
        .. "replaces the phrases of that type in this application's own store, in the "
        .. "order they were offered; setVocabulary:ofType: keeps the spoken phrase of "
        .. "each speakable value it is given; removeAllVocabularyStrings empties the "
        .. "store; revenant_vocabularyStringsOfType: reads a type back, which is where a "
        .. "port reads what it offered, because on a release with Siri the system is the "
        .. "reader",
    INPreferences = "siriAuthorizationStatus answers INSiriAuthorizationStatusRestricted, which "
        .. "is the header's own wording for a system where Siri services are restricted "
        .. "and the user cannot change the answer; requestSiriAuthorization: answers the "
        .. "handler with that same status instead of waiting for a prompt this release "
        .. "cannot show, and does nothing for a handler of nil; siriLanguageCode answers "
        .. "the language the release itself is set to, which is the one a voice would "
        .. "use, since this release has no Siri setting to read",
    INExtension = "the class carries nothing but NSObject's, as its own surface is empty; the one "
        .. "requirement it inherits from INIntentHandlerProviding, handlerForIntent:, "
        .. "answers the instance of the loaded class that conforms to the intent's own "
        .. "handling protocol and responds to -handleIntent:, and answers nil where there "
        .. "is none, which is what a release with no assistant daemon to launch an "
        .. "extension has to say",
    INPaymentMethod = "the initialiser keeps the type, the name, the identification hint and the "
        .. "icon, copying each of the three objects; applePayPaymentMethod is the one "
        .. "object of that kind for the whole process, of the type the header gives "
        .. "and with no name, hint or icon of its own, because this release has no "
        .. "image of it and no name for it",
    INRideCompletionStatus = "the six factory methods answer a real status: completed is completed "
        .. "and not outstanding, the two with a payment amount carry it, the one "
        .. "with a feedback type is outstanding and carries the type, canceled "
        .. "by service and canceled by the user are both canceled and neither "
        .. "missed the pickup, and canceledMissedPickup is canceled and missed "
        .. "it; the five derived answers - isCompleted, isCanceled, "
        .. "isMissedPickup, isOutstanding, paymentAmount and feedbackType - are "
        .. "computed from that state, and completionUserActivity and "
        .. "defaultTippingOptions are kept",
    INParameter = "parameterForClass:keyPath: keeps the class and the key path, which are the whole of what "
        .. "the header's two properties say a parameter is; isEqualToParameter: compares those two, so "
        .. "two parameters are the same parameter when they name the same class and the same key path; "
        .. "setIndex:forSubKeyPath: and indexForSubKeyPath: keep a real index per sub key path, and a "
        .. "sub key path that was never given one answers NSNotFound, which is what an NSUInteger return "
        .. "has to say for no index; the class and the key path and the indices are carried by the "
        .. "coding and the copy",
}

local HAND_WRITTEN_REASON = "behaviour that is more than the class's own storage, written by hand in "
    .. "frameworks/Backports/src/Intents/RevenantIntents100.m"

local GENERATED_REASON = "a data class of the framework: every property the SDK's header declares is kept in the "
    .. "class's own state with the ownership the header gives it, the initialisers the header "
    .. "declares keep every value they are given, NSSecureCoding and NSCopying carry the whole "
    .. "ivar chain, and a member whose type is a class of a later group has an entry of its own "
    .. "below that says so"

local GENERATED_EFFECT = "every member the header declares has a body that stores or returns the class's own state; "
    .. "the object file is generated from the SDK's own declarations by tools/intents/gen-intents.py "
    .. "and this entry is written from what that generator emitted, read back out of the emitted text"

local STORE_EFFECT = {
    INRelevantShortcutStore = "defaultStore is one instance for the process, which is what the header's own note asks "
        .. "for; setRelevantShortcuts:completionHandler: replaces the whole set rather than adding to "
        .. "it, as the header's note says, keeps it in the class's own state and answers the handler "
        .. "with no error; revenant_relevantShortcuts reads the set back, which is where a port reads "
        .. "what it offered, because on a release with Siri the system is the reader",
    INUpcomingMediaManager = "sharedManager is one instance for the process; setSuggestedMediaIntents: keeps the intents "
        .. "it is given in the order they were given; setPredictionMode:forType: keeps one mode per "
        .. "media item type and removes the entry for the enumeration own zero case; "
        .. "revenant_suggestedMediaIntents and revenant_predictionModeForType: read both back",
    INVoiceShortcutCenter = "sharedCenter is one instance for the process; setShortcutSuggestions: keeps the suggestions "
        .. "it is given in the order they were given; getAllVoiceShortcutsWithCompletion: answers an "
        .. "empty array and no error, and getVoiceShortcutWithIdentifier:completion: nil and no error, "
        .. "because this release runs no assistant daemon and has no Shortcuts app, so no shortcut was "
        .. "ever added to Siri; revenant_shortcutSuggestions reads the suggestions back",
}

local NOT_ANSWERED = {}

local SWIFT_ONLY_PROTOCOLS = {INIntentSetImageKeyPath = true, _INIntentSetImageKeyPath = true}

local SOURCE = "the header of iPhoneOS 16.4 for the contract, and the armv7 release caches for the "
    .. "release each object file is carried from (tools/intents/measure-intents.lua)"

local INIT_SOURCE = SOURCE
    .. "; and for the -init, which the header marks unavailable on some of these classes and declares "
    .. "on others, the host's own answer, measured for every class this framework carries a -init row "
    .. "for by tests/backports/host/intents-init/run.sh: it "
    .. "reads class_getInstanceMethod(Cls, @selector(init)) and calls [[Cls alloc] init] through that "
    .. "IMP, because a compile-time call to the selector is unavailable and could not be the "
    .. "measurement; it looks up NSObject, NSString, INCar and INListCarsIntent first and fails if any "
    .. "is missing, and prints the forwarding trampoline beside three real IMPs, so a zero it reports "
    .. "is the host's answer and not the reader's; it compares every line against expected.txt and "
    .. "then re-runs itself with PLANT=one-wrong, which must FAIL. The IMP is how the answer was read, "
    .. "and is how the emitted body reaches the superclass, because the marker is what forbids naming "
    .. "the selector at compile time"

local CENSUS = "tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0 - 0 of 11378 and of 7187 on the two armv7 rungs, "
    .. "control 1039 IN names on 11.0 and 12.0"

local HAND_WRITTEN_SOURCE = {
    ["INMediaDestination libraryDestination"] = SOURCE
        .. "; and the behaviour, from the host's own class rather than from the header: "
        .. "tests/backports/host/intents/factory-rows.m, run by "
        .. "tests/backports/host/intents/run-rows.sh, reads this factory through its real IMP "
        .. "because all four of these classes are API_UNAVAILABLE(macos) in the SDK and a "
        .. "compile-time call cannot be made; it answers mediaDestinationType 1 and no playlist "
        .. "name, and a second call is isEqual to the first. For the absence at the band ends: no "
        .. "release this package is gated for carries any Intents class at all, read with "
        .. "REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua IN 6.1.3 4.3 11.0 12.0 - the "
        .. "armv7 caches of 6.1.3 and 4.3 hold 0 of the 11378 and 7187 classes under the IN prefix, "
        .. "in a census whose own control found 1039 IN names on 11.0 and 12.0 (239 and 411 of "
        .. "them), so a zero is the release's and not the reader's. The framework arrived with "
        .. "iOS 10 and the armv7 ladder ends at 10.3.4, so the port has to supply the class itself",
    ["INMediaDestination playlistDestinationWithName:"] = SOURCE
        .. "; and the behaviour, from the host's own class rather than from the header: "
        .. "tests/backports/host/intents/factory-rows.m answers mediaDestinationType 2 and the "
        .. "name it was given, and nil for a nil name, which is the header's own nullable. Read "
        .. "through the real IMP, with the four control classes and the forwarding trampoline "
        .. "beside it; the class is API_UNAVAILABLE(macos) in the SDK, so a compile-time call "
        .. "cannot be made. For the absence at the band ends: no release this package is gated "
        .. "for carries any Intents class at all (" .. CENSUS .. "), so the port supplies the class itself",
    ["INFile fileWithData:filename:typeIdentifier:"] = SOURCE
        .. "; and the behaviour, from the host's own class rather than from the header: "
        .. "tests/backports/host/intents/factory-rows.m, run by "
        .. "tests/backports/host/intents/run-rows.sh, answers the bytes it was given, filename "
        .. "and typeIdentifier as given, fileURL nil, removedOnCompletion false, and a nil "
        .. "filename stays nil. For the absence at the band ends: no release this package is "
        .. "gated for carries any Intents class at all (" .. CENSUS .. "), so the port supplies the class itself",
    ["INFile fileWithFileURL:filename:typeIdentifier:"] = SOURCE
        .. "; and the behaviour, from the host's own class rather than from the header: "
        .. "tests/backports/host/intents/factory-rows.m answers fileURL the URL it was given, "
        .. "filename the URL's last path component when the name is nil, typeIdentifier as given, "
        .. "removedOnCompletion false, and -data the file's own bytes - /etc/hosts came back as "
        .. "its 213 bytes and a path that does not exist as 0 - which is the header's own "
        .. "sentence that a file created with a URL has its contents memory mapped on access. For "
        .. "the absence at the band ends: no release this package is gated for carries any "
        .. "Intents class at all (" .. CENSUS .. ")",
    ["INAddTasksTargetTaskListResolutionResult confirmationRequiredWithTaskListToConfirm:forReason:"] = SOURCE
        .. "; and the behaviour, from the host's own class rather than from the header: "
        .. "tests/backports/host/intents/factory-rows.m answers what the superclass's "
        .. "one-argument factory answers - resolutionResultCode NeedsConfirmation, the task list "
        .. "as the item to confirm, nothing else - and the reason is in no property either class "
        .. "declares, unsupportedReason staying 0, so it is kept where only this port can read "
        .. "it, which is the same answer +unsupportedForReason: already gives. For the absence "
        .. "at the band ends: no release this package is gated for carries any Intents class at "
        .. "all (" .. CENSUS .. ")",
    ["INUserContext becomeCurrent"] = SOURCE
        .. "; and the behaviour, from the host's own class rather than from the header: "
        .. "tests/backports/host/intents/factory-rows.m reads the class present with superclass "
        .. "NSObject and 0 properties of its own, its seven declared methods are initWithCoder:, "
        .. ".cxx_destruct, becomeCurrent, encodeWithCoder:, _init, _becomeCurrentNoHelper and "
        .. "_setStore: with no -init among them, and -becomeCurrent returns with no exception. "
        .. "The class declares no reader of its own, so a body that remembered the object would "
        .. "answer that the context is current and nothing the SDK declares could ever see that "
        .. "it is. (INImage's +systemImageNamed: is not this case: it answers the names UIKit draws.) "
        .. "For the absence at the band ends: no release this package is gated for carries "
        .. "any Intents class at all (" .. CENSUS .. ")",
}

local ABSENT_EFFECT = "the class is there and does not implement this: respondsToSelector: answers "
    .. "no, and a port that reached it would not find it"

local INIT_FALLBACK = "the header marks the class's -init unavailable, so a port cannot call it and the class answers "
    .. "the initialiser the header does declare"

local function revenant_root()
    return path.absolute(path.join(os.scriptdir(), "..", ".."))
end

local function object(pairs_list)
    local value = {kind = "object", keys = {}, map = {}}
    for _, pair in ipairs(pairs_list) do
        local key, item = pair[1], pair[2]
        if item == nil then
            item = NULL
        end
        if value.map[key] == nil then
            table.insert(value.keys, key)
        end
        value.map[key] = item
    end
    return value
end

local function field(value, key)
    if type(value) == "table" and value.kind == "object" then
        local found = value.map[key]
        if found == NULL then
            return nil
        end
        return found
    end
end

local function utf8_char(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xc0 | (code >> 6), 0x80 | (code & 0x3f))
    elseif code < 0x10000 then
        return string.char(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
    end
    return string.char(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f))
end

local function decode(text)
    local at = 1
    local length = #text
    local value

    local function fail(what)
        raise("JSON: %s at byte %d", what, at)
    end

    local function skip()
        while at <= length do
            local byte = text:byte(at)
            if byte == 32 or byte == 9 or byte == 10 or byte == 13 then
                at = at + 1
            else
                break
            end
        end
    end

    local function hex4()
        local digits = text:sub(at, at + 3)
        if not digits:match("^%x%x%x%x$") then
            fail("a bad \\u escape")
        end
        at = at + 4
        return tonumber(digits, 16)
    end

    local function string_value()
        at = at + 1
        local parts = {}
        while true do
            local stop = text:find('["\\]', at)
            if not stop then
                fail("an unterminated string")
            end
            table.insert(parts, text:sub(at, stop - 1))
            at = stop
            if text:sub(at, at) == '"' then
                at = at + 1
                return table.concat(parts)
            end
            local escape = text:sub(at + 1, at + 1)
            at = at + 2
            if escape == "n" then
                table.insert(parts, "\n")
            elseif escape == "t" then
                table.insert(parts, "\t")
            elseif escape == "r" then
                table.insert(parts, "\r")
            elseif escape == "b" then
                table.insert(parts, "\b")
            elseif escape == "f" then
                table.insert(parts, "\f")
            elseif escape == '"' or escape == "\\" or escape == "/" then
                table.insert(parts, escape)
            elseif escape == "u" then
                local code = hex4()
                if code >= 0xd800 and code <= 0xdbff and text:sub(at, at + 1) == "\\u" then
                    local saved = at
                    at = at + 2
                    local low = hex4()
                    if low >= 0xdc00 and low <= 0xdfff then
                        code = 0x10000 + (code - 0xd800) * 0x400 + (low - 0xdc00)
                    else
                        at = saved
                    end
                end
                table.insert(parts, utf8_char(code))
            else
                fail("a bad escape")
            end
        end
    end

    function value()
        skip()
        local char = text:sub(at, at)
        if char == "{" then
            at = at + 1
            local result = {kind = "object", keys = {}, map = {}}
            skip()
            if text:sub(at, at) == "}" then
                at = at + 1
                return result
            end
            while true do
                skip()
                if text:sub(at, at) ~= '"' then
                    fail("an object key that is not a string")
                end
                local key = string_value()
                skip()
                if text:sub(at, at) ~= ":" then
                    fail("a missing colon")
                end
                at = at + 1
                local item = value()
                if result.map[key] == nil then
                    table.insert(result.keys, key)
                end
                result.map[key] = item
                skip()
                local separator = text:sub(at, at)
                at = at + 1
                if separator == "}" then
                    return result
                elseif separator ~= "," then
                    fail("a missing comma in an object")
                end
            end
        elseif char == "[" then
            at = at + 1
            local result = {kind = "array", items = {}}
            skip()
            if text:sub(at, at) == "]" then
                at = at + 1
                return result
            end
            while true do
                table.insert(result.items, value())
                skip()
                local separator = text:sub(at, at)
                at = at + 1
                if separator == "]" then
                    return result
                elseif separator ~= "," then
                    fail("a missing comma in an array")
                end
            end
        elseif char == '"' then
            return string_value()
        elseif text:sub(at, at + 3) == "true" then
            at = at + 4
            return true
        elseif text:sub(at, at + 4) == "false" then
            at = at + 5
            return false
        elseif text:sub(at, at + 3) == "null" then
            at = at + 4
            return NULL
        else
            local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", at)
            if not number or number == "" then
                fail("an unexpected character")
            end
            at = at + #number
            return {kind = "number", text = number}
        end
    end

    local result = value()
    skip()
    if at <= length then
        fail("extra data")
    end
    return result
end

local function read_json(file)
    return decode(io.readfile(file, {encoding = "binary"}))
end

local SHORT_ESCAPES = {[8] = "\\b", [9] = "\\t", [10] = "\\n", [12] = "\\f", [13] = "\\r", [34] = '\\"', [92] = "\\\\"}

local function quote(text, ascii)
    local parts = {'"'}
    local at, length = 1, #text
    while at <= length do
        local byte = text:byte(at)
        if SHORT_ESCAPES[byte] then
            table.insert(parts, SHORT_ESCAPES[byte])
            at = at + 1
        elseif byte < 0x20 or (ascii and byte == 0x7f) then
            table.insert(parts, string.format("\\u%04x", byte))
            at = at + 1
        elseif byte < 0x80 or not ascii then
            local stop = at
            while stop + 1 <= length do
                local next_byte = text:byte(stop + 1)
                if SHORT_ESCAPES[next_byte] or next_byte < 0x20 or (ascii and next_byte >= 0x7f) then
                    break
                end
                stop = stop + 1
            end
            table.insert(parts, text:sub(at, stop))
            at = stop + 1
        else
            local code, size
            if byte >= 0xf0 then
                code, size = byte & 0x07, 4
            elseif byte >= 0xe0 then
                code, size = byte & 0x0f, 3
            else
                code, size = byte & 0x1f, 2
            end
            for offset = 1, size - 1 do
                code = (code << 6) | ((text:byte(at + offset) or 0x80) & 0x3f)
            end
            if code >= 0x10000 then
                code = code - 0x10000
                table.insert(parts, string.format("\\u%04x\\u%04x", 0xd800 + (code >> 10), 0xdc00 + (code & 0x3ff)))
            else
                table.insert(parts, string.format("\\u%04x", code))
            end
            at = at + size
        end
    end
    table.insert(parts, '"')
    return table.concat(parts)
end

local function dump(value, ascii)
    local out = {}
    local function emit(item, depth)
        if item == NULL then
            table.insert(out, "null")
        elseif item == true then
            table.insert(out, "true")
        elseif item == false then
            table.insert(out, "false")
        elseif type(item) == "string" then
            table.insert(out, quote(item, ascii))
        elseif item.kind == "number" then
            table.insert(out, item.text)
        elseif item.kind == "object" then
            if #item.keys == 0 then
                table.insert(out, "{}")
                return
            end
            local inner = string.rep("  ", depth + 1)
            table.insert(out, "{")
            for index, key in ipairs(item.keys) do
                table.insert(out, (index > 1 and ",\n" or "\n") .. inner .. quote(key, ascii) .. ": ")
                emit(item.map[key], depth + 1)
            end
            table.insert(out, "\n" .. string.rep("  ", depth) .. "}")
        elseif item.kind == "array" then
            if #item.items == 0 then
                table.insert(out, "[]")
                return
            end
            local inner = string.rep("  ", depth + 1)
            table.insert(out, "[")
            for index, element in ipairs(item.items) do
                table.insert(out, (index > 1 and ",\n" or "\n") .. inner)
                emit(element, depth + 1)
            end
            table.insert(out, "\n" .. string.rep("  ", depth) .. "]")
        else
            raise("JSON: cannot write a value of type %s", type(item))
        end
    end
    emit(value, 0)
    return table.concat(out)
end

local function split(text, separator)
    local parts, at = {}, 1
    while true do
        local stop = text:find(separator, at, true)
        if not stop then
            table.insert(parts, text:sub(at))
            return parts
        end
        table.insert(parts, text:sub(at, stop - 1))
        at = stop + #separator
    end
end

local function lines_of(file)
    local text = io.readfile(file, {encoding = "binary"}):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = split(text, "\n")
    if lines[#lines] == "" then
        table.remove(lines)
    end
    return lines
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_with(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function ends_with(text, suffix)
    return suffix == "" or text:sub(-#suffix) == suffix
end

local function load_corpus(file, framework)
    local rows = {}
    for _, line in ipairs(lines_of(file)) do
        local fields = split(line, "\t")
        if #fields >= 5 and fields[1] == framework then
            if fields[6] == nil then
                raise("%s: the row %s has no deprecated column", file, line)
            end
            table.insert(rows, {kind = fields[2], lang = fields[3], api = fields[4], introduced = fields[5],
                                deprecated = fields[6]})
        end
    end
    return rows
end

local function version_number(text, api)
    local number = text:match("^%s*[-+]?%d*%.?%d+%s*$") and tonumber(text)
    if not number then
        raise("the introduced %q of %s is not a number", text, api)
    end
    return number
end

local function constant_entry(row, carried, facts)
    return object({
        {"api", row.api}, {"kind", "constant"}, {"introduced", row.introduced}, {"minimum", "6.0"},
        {"status", "implemented"}, {"facts", facts},
        {"source", "the value read out of the host's own Intents at runtime by dlsym, and the object's own rung: "
            .. carried.rung .. ", which is the release it first appears in"},
        {"reason", "the header declares it an extern NSString *const and the release has no such symbol in the built "
            .. "libraries or the 6.1.3 cache, so the port has to export it; the SDK's own availability for it is "
            .. carried.introduced},
        {"effect", "the symbol is there and its value is the system's own: a program that reads it gets the same "
            .. "string the host holds, and the object's release rung is " .. carried.rung .. ", so a band gate sees "
            .. "the definition only in the bands that export it"},
    })
end

local function manifest_of(file)
    local held = field(read_json(file), "constants")
    local manifest = {}
    for _, name in ipairs(held.keys) do
        local entry = held.map[name]
        manifest[name] = {introduced = field(entry, "introduced"), rung = field(entry, "rung")}
    end
    return manifest
end

local function write_document(file, document, ascii)
    io.writefile(file, dump(document, ascii) .. "\n", {encoding = "binary"})
end

local function merge_constants(options)
    local manifest = manifest_of(options.constants)
    local corpus = load_corpus(options.corpus, "Intents")
    local target = options["merge-into"]
    local held = read_json(target)
    local entries = held.kind == "object" and held.map.entries or held
    local have = {}
    for index, entry in ipairs(entries.items) do
        have[field(entry, "api")] = index
    end
    local added, replaced = 0, 0
    local to_later = ends_with(target, "ios18.json")
    for _, row in ipairs(corpus) do
        local carried = row.kind == "constant" and manifest[row.api]
        if carried then
            local later = version_number(row.introduced, row.api) >= 17.0
            if later == to_later then
                local entry = constant_entry(row, carried, options["constants-facts"])
                if have[row.api] then
                    entries.items[have[row.api]] = entry
                    replaced = replaced + 1
                else
                    table.insert(entries.items, entry)
                    added = added + 1
                end
            end
        end
    end
    write_document(target, held, false)
    print("  %s: %d constant rows added, %d replaced", path.filename(target), added, replaced)
end

local INIT_GOLDEN

local function init_golden()
    if INIT_GOLDEN then
        return INIT_GOLDEN
    end
    local file = path.join(revenant_root(), "tests", "backports", "host", "intents-init", "expected.txt")
    if not os.isfile(file) then
        raise("gen-registry: no host measurement to cite for a -init row: %s is missing. Run "
              .. "sh tests/backports/host/intents-init/run.sh", file)
    end
    local lines = {}
    for _, line in ipairs(lines_of(file)) do
        if line ~= "" and not starts_with(line, "//") and not starts_with(line, "#") then
            local fields = split(line, "\t")
            lines[fields[1]] = {table.unpack(fields, 2)}
        end
    end
    INIT_GOLDEN = {file = file, lines = lines}
    return INIT_GOLDEN
end

local ANSWERED_WORDS = {object = "an object", ["nil"] = "nil", threw = "an exception it did not catch"}

local function init_source(owner)
    local golden = init_golden()
    local fields = golden.lines[owner]
    if not fields or #fields < 3 then
        raise("gen-registry: %s has no line in %s, so a -[%s init] row would cite a measurement that does not "
              .. "cover it. Run sh tests/backports/host/intents-init/run.sh --write if the host changed, and put "
              .. "the class in init-classes.inc if it is new.", owner, golden.file, owner)
    end
    local word = fields[1]
    local inherits = starts_with(word, "inherit")
    if not starts_with(word, "own") and not inherits then
        raise("gen-registry: %s reads %q in %s, which is neither an `own` nor an `inherit` line. Re-read the "
              .. "header of that file before trusting a row built on it.", owner, word, golden.file)
    end
    local declared = inherits and "INHERITS" or "DECLARES"
    local answered = ANSWERED_WORDS[inherits and word:sub(#"inherit" + 1) or word:sub(#"own" + 1)]
    if not answered then
        raise("gen-registry: %s reads %q in %s, whose answer is not object, nil or threw", owner, word, golden.file)
    end
    local properties, non_nil = fields[2], fields[3]
    local which = fields[4] and trim(fields[4]) or ""
    local named = which ~= "" and which ~= "-"
    local reads
    if named and non_nil ~= "0" then
        reads = non_nil .. " of them read non-nil, and they are " .. which
    elseif named then
        reads = "all " .. non_nil .. " read non-nil"
    else
        reads = "none of them read non-nil"
    end
    local spelled = {owner}
    for _, item in ipairs(fields) do
        table.insert(spelled, item)
    end
    return INIT_SOURCE .. ". Its golden line for this class is " .. table.concat(spelled, "\\t")
        .. ", which says the class " .. declared .. " -init and [[" .. owner .. " alloc] init] through that IMP "
        .. "answered " .. answered .. ", so respondsToSelector:init is 1 by the same lookup, and the " .. properties
        .. " properties the port synthesizes for this class were read off that fresh object: " .. reads
        .. ". The harness's own counts for the whole population, and the argument behind every figure here, "
        .. "are in facts/Intents/Intents.md"
end

local function member_name(api)
    if api:find(" ", 1, true) then
        local last = api:match("^.* (.*)$")
        return last:sub(1, -2)
    end
    local dot = api:find(".", 1, true)
    if dot then
        return api:sub(dot + 1)
    end
end

local function reason_for(causes, vocabulary, api, fallback)
    local name = member_name(api)
    local cause = causes[api]
    if cause == nil or cause == "" then
        cause = name ~= nil and causes[name] or nil
    end
    if cause ~= nil and vocabulary[cause] ~= nil then
        return vocabulary[cause]
    end
    return fallback
end

local function generator_property_names(selector)
    local bracket = selector:find("[", 1, true)
    local after = bracket and selector:sub(bracket + 1) or ""
    local space = after:find(" ", 1, true)
    local body = trim((space and after:sub(space + 1) or ""):gsub("%]+$", ""))
    if body == "" or body:find(":", 1, true) then
        return {}
    end
    local found = {body}
    if starts_with(body, "is") and #body > 2 and body:sub(3, 3):match("%u") then
        table.insert(found, body:sub(3, 3):lower() .. body:sub(4))
    end
    return found
end

local function implemented(api, kind, introduced, owner, facts, where, source, hand)
    local which = where or (hand and "answers it with a body written by hand in the generator's EXTRA_METHODS"
                            or "the class's own generated implementation answers")
    return object({
        {"api", api}, {"kind", kind}, {"introduced", introduced}, {"minimum", "6.0"}, {"status", "implemented"},
        {"facts", facts}, {"reason", "a member of " .. owner .. ", which " .. which}, {"source", source or SOURCE},
    })
end

local function absent(api, kind, introduced, reason, facts)
    return object({
        {"api", api}, {"kind", kind}, {"introduced", introduced}, {"status", "absent"}, {"reason", reason},
        {"effect", ABSENT_EFFECT}, {"facts", facts},
    })
end

local function new_answer()
    return {properties = {}, dynamic = {}, methods = {}, class_properties = {}}
end

local function add_spellings(answer)
    for method in pairs(answer.methods) do
        for _, spelling in ipairs(generator_property_names(method)) do
            answer.properties[spelling] = true
        end
    end
end

local function list_of(value)
    local items = {}
    if type(value) == "table" and value.kind == "array" then
        for _, item in ipairs(value.items) do
            table.insert(items, item)
        end
    end
    return items
end

local function read_reports(files)
    local answered, causes = {}, {}
    for _, file in ipairs(files) do
        local document = read_json(file)
        for _, name in ipairs(document.keys) do
            local report = document.map[name]
            answered[name] = answered[name] or new_answer()
            for _, kind in ipairs({"properties", "dynamic", "methods", "class_properties"}) do
                for _, item in ipairs(list_of(field(report, kind))) do
                    answered[name][kind][item] = true
                end
            end
            local recorded = field(report, "causes")
            if recorded then
                for _, key in ipairs(recorded.keys) do
                    causes[key] = recorded.map[key]
                end
            end
            add_spellings(answered[name])
        end
    end
    return answered, causes
end

local function read_hand_written(answered, group, hand_written)
    local generator = import("gen-intents", {rootdir = os.scriptdir(), anonymous = true})
    local file = path.join(revenant_root(), "..", "packages", "frameworks", "apple-backports", "Intents", hand_written)
    local lines = lines_of(file)
    local names = {}
    for name in pairs(group) do
        names[name] = true
    end
    for name in pairs(D.hand_written) do
        names[name] = true
    end
    for name in pairs(names) do
        local opening = "@implementation " .. name
        local block, start = {}, nil
        for index, line in ipairs(lines) do
            local rest = starts_with(line, opening) and trim(line:sub(#opening + 1))
            if rest == "" or rest == "{" then
                start = index
            elseif start ~= nil then
                if starts_with(line, "@implementation ") or starts_with(line, "@end") then
                    break
                end
                table.insert(block, line)
            end
        end
        if #block > 0 then
            answered[name] = answered[name] or new_answer()
            local report = generator.answer(block, name)
            for _, kind in ipairs({"properties", "dynamic", "methods", "class_properties"}) do
                for _, item in ipairs(report[kind] or {}) do
                    answered[name][kind][item] = true
                end
            end
            add_spellings(answered[name])
        end
    end
end

local function counter_add(missing, key)
    if missing.counts[key] == nil then
        table.insert(missing.order, key)
        missing.counts[key] = 0
    end
    missing.counts[key] = missing.counts[key] + 1
end

local function owner_of(row)
    if row.kind == "method" then
        return row.api:match("^[-+]%[([A-Za-z_0-9]+) ")
    elseif row.kind == "property" then
        local dot = row.api:find(".", 1, true)
        return dot and row.api:sub(1, dot - 1) or row.api
    end
end

local function second_part(api)
    local parts = split(api, ".")
    if parts[2] == nil then
        raise("the property row %s has no . to split its owner from its name", api)
    end
    return parts[2]
end

local function curated_rows(name)
    local file = path.join(os.scriptdir(), "curated-rows.json")
    if not os.isfile(file) then
        return nil
    end
    return field(read_json(file), name)
end

local function apply_curated(entries, curated)
    if not curated or #curated.keys == 0 then
        return 0
    end
    local index = {}
    for position, entry in ipairs(entries) do
        index[field(entry, "api") .. "\t" .. field(entry, "kind")] = position
    end
    local keys = {}
    for _, key in ipairs(curated.keys) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    local replaced, stale = 0, {}
    for _, key in ipairs(keys) do
        local tab = key:find("\t", 1, true)
        local api, kind = tab and key:sub(1, tab - 1) or key, tab and key:sub(tab + 1) or ""
        local where = index[api .. "\t" .. kind]
        if where == nil then
            table.insert(stale, key)
        else
            entries[where] = curated.map[key]
            replaced = replaced + 1
        end
    end
    if #stale > 0 then
        raise("curated-rows.json holds %d row(s) of this file this run emitted no row for: %s", #stale,
              table.concat(stale, "; ", 1, math.min(#stale, 5)))
    end
    return replaced
end

local function sort_entries(entries)
    local decorated = {}
    for position, entry in ipairs(entries) do
        table.insert(decorated, {kind = field(entry, "kind"), api = field(entry, "api"), position = position,
                                 entry = entry})
    end
    table.sort(decorated, function (a, b)
        if a.kind ~= b.kind then
            return byteorder.less(a.kind, b.kind)
        end
        if a.api ~= b.api then
            return byteorder.less(a.api, b.api)
        end
        return a.position < b.position
    end)
    local sorted = {}
    for _, item in ipairs(decorated) do
        table.insert(sorted, item.entry)
    end
    return sorted
end

local function full_regeneration(options)
    local vocabulary = {}
    if options.causes then
        local document = read_json(options.causes)
        for _, key in ipairs(document.keys) do
            vocabulary[key] = document.map[key]
        end
    end
    if not options.report or #options.report == 0 then
        raise("gen-registry: a full regeneration needs at least one --report")
    end
    if not options.classes or #options.classes == 0 then
        raise("gen-registry: a full regeneration needs --classes")
    end
    local answered, causes = read_reports(options.report)
    local group = {}
    for _, file in ipairs(options.classes) do
        for _, line in ipairs(lines_of(file)) do
            local name = trim(line)
            if name ~= "" then
                group[name] = true
            end
        end
    end
    read_hand_written(answered, group, options["hand-written"])
    local hand_written = D.hand_written
    local bodies = D.extra_methods
    local manifest = options.constants and manifest_of(options.constants)
    local facts, fallback_reason = options.facts, options.reason

    local entries = {}
    local missing = {order = {}, counts = {}}
    for _, row in ipairs(load_corpus(options.corpus, options.framework)) do
        local api, kind, intro = row.api, row.kind, row.introduced
        local owner = owner_of(row)
        local done = false
        if kind == "constant" then
            local carried = manifest and manifest[api]
            if carried then
                table.insert(entries, constant_entry(row, carried, options["constants-facts"]))
            end
            done = true
        elseif kind == "enum" or kind == "typealias" then
            done = true
        elseif kind == "protocol" then
            if SWIFT_ONLY_PROTOCOLS[api] then
                done = true
            elseif options["no-protocols"] then
                counter_add(missing, "protocol of another group")
                done = true
            else
                table.insert(entries, object({
                    {"api", api}, {"kind", "protocol"}, {"introduced", intro}, {"minimum", "6.0"},
                    {"status", "implemented"}, {"facts", facts},
                    {"reason", "the protocol is the SDK's own declaration, carried by the header once the availability "
                        .. "of its members is lowered, and the members are the entries of this file"},
                    {"source", SOURCE},
                }))
                done = true
            end
        elseif kind == "swift" or row.lang == "swift" then
            done = true
        elseif owner ~= nil and not group[owner] then
            counter_add(missing, "another group")
            done = true
        elseif owner ~= nil and not answered[owner] then
            counter_add(missing, "later group")
            done = true
        end
        if not done and owner ~= nil and answered[owner] then
            local report = answered[owner]
            if kind == "property" then
                local spelled = second_part(api)
                if report.properties[spelled] then
                    table.insert(entries, implemented(api, "property", intro, owner, facts,
                        hand_written[owner] and (owner .. "'s own @implementation synthesises it") or nil, nil,
                        bodies[owner .. " " .. spelled] ~= nil))
                    done = true
                elseif report.class_properties[spelled] then
                    table.insert(entries, implemented(api, "property", intro, owner, facts, nil, nil, true))
                    done = true
                elseif report.dynamic[spelled] then
                    table.insert(entries, absent(api, "property", intro, reason_for(causes, vocabulary, api, fallback_reason), facts))
                    counter_add(missing, "dynamic")
                    done = true
                end
            elseif kind == "method" then
                local member = member_name(api)
                if NOT_ANSWERED[api] then
                    table.insert(entries, absent(api, "method", intro, NOT_ANSWERED[api], facts))
                    counter_add(missing, "not answered")
                elseif report.methods[api] then
                    local marked_init = api == "-[" .. owner .. " init]"
                    local source
                    if marked_init then
                        source = init_source(owner)
                    else
                        source = HAND_WRITTEN_SOURCE[owner .. " " .. member]
                    end
                    table.insert(entries, implemented(api, "method", intro, owner, facts,
                        hand_written[owner] and (owner .. "'s own @implementation answers it") or nil, source,
                        bodies[owner .. " " .. member] ~= nil))
                elseif ends_with(api, "] init") or api == "-[" .. owner .. " init]" then
                    table.insert(entries, absent(api, "method", intro, reason_for(causes, vocabulary, api, INIT_FALLBACK), facts))
                    counter_add(missing, "init")
                else
                    local absent_reason = reason_for(causes, vocabulary, api, nil)
                    if absent_reason == nil then
                        absent_reason = vocabulary.not_declared
                    end
                    table.insert(entries, absent(api, "method", intro, absent_reason or fallback_reason, facts))
                    counter_add(missing, "skipped")
                end
                done = true
            end
        end
        if not done and kind == "class" then
            if group[api] then
                local reason, effect
                if HAND_WRITTEN_EFFECT[api] then
                    reason, effect = HAND_WRITTEN_REASON, HAND_WRITTEN_EFFECT[api]
                else
                    reason, effect = GENERATED_REASON, STORE_EFFECT[api] or GENERATED_EFFECT
                end
                table.insert(entries, object({
                    {"api", api}, {"kind", "class"}, {"introduced", intro}, {"minimum", "6.0"}, {"status", "implemented"},
                    {"facts", facts}, {"source", SOURCE}, {"reason", reason}, {"effect", effect},
                }))
            else
                counter_add(missing, "another group")
            end
            done = true
        end
        if not done then
            local reason = reason_for(causes, vocabulary, api, nil)
            if reason == nil and owner ~= nil and answered[owner] then
                reason = vocabulary.not_declared
            end
            reason = reason or fallback_reason
            if owner ~= nil and hand_written[owner] then
                reason = "this is a member of a hand written class and " .. owner .. "'s @implementation shows no"
                    .. " accessor of that name for it, so nothing in the package answers it; the"
                    .. " header's declaration alone is not an implementation"
                counter_add(missing, "hand written without an accessor")
            end
            table.insert(entries, absent(api, kind, intro, reason, facts))
            counter_add(missing, "unanswered member")
        end
    end

    local replaced = apply_curated(entries, curated_rows(path.filename(options.out)))
    if replaced > 0 then
        print("  %d row(s) from curated-rows.json", replaced)
    end
    entries = sort_entries(entries)
    write_document(options.out, object({{"framework", options.framework}, {"entries", {kind = "array", items = entries}}}), true)

    local tally = {}
    for _, entry in ipairs(entries) do
        local status = field(entry, "status")
        tally[status] = (tally[status] or 0) + 1
    end
    local statuses, total = {}, 0
    for _, status in ipairs(byteorder.keys(tally)) do
        table.insert(statuses, status .. " " .. tally[status])
    end
    local counted = {}
    for _, key in ipairs(missing.order) do
        total = total + missing.counts[key]
        table.insert(counted, key .. ": " .. missing.counts[key])
    end
    print("%s: %d entries (%s), %d not carried: {%s}", options.out, #entries, table.concat(statuses, ", "), total,
          table.concat(counted, ", "))
end

local VALUED = {corpus = true, out = true, facts = true, ["merge-into"] = true, ["constants-facts"] = true,
                constants = true, release = true, framework = true, ["hand-written"] = true, causes = true,
                reason = true}

local USAGE = "usage: xmake l tools/intents/gen-registry.lua --corpus <surface.tsv> --out <file> --facts <page> "
    .. "--release <release> [--report <report.json> ...] [--classes <file> ...] [--causes <file>] [--reason <text>] "
    .. "[--hand-written <file>] [--no-protocols] [--framework <name>] [--constants <manifest>] "
    .. "[--merge-into <file>] [--constants-facts <page>]"

function options_of(arguments)
    local options = {framework = "Intents", ["hand-written"] = "RevenantIntents100.m",
                     ["constants-facts"] = "facts/Intents/Constants.md", report = {}}
    local index = 1
    while index <= #arguments do
        local key = arguments[index]:match("^%-%-(.+)$")
        if key == "no-protocols" then
            options["no-protocols"] = true
            index = index + 1
        elseif key == "report" and arguments[index + 1] ~= nil then
            table.insert(options.report, arguments[index + 1])
            index = index + 2
        elseif key == "classes" then
            options.classes = {}
            index = index + 1
            while arguments[index] ~= nil and not starts_with(arguments[index], "--") do
                table.insert(options.classes, arguments[index])
                index = index + 1
            end
            if #options.classes == 0 then
                raise(USAGE)
            end
        elseif VALUED[key] and arguments[index + 1] ~= nil then
            options[key] = arguments[index + 1]
            index = index + 2
        else
            raise(USAGE)
        end
    end
    for _, required in ipairs({"corpus", "out", "facts", "release"}) do
        if options[required] == nil then
            raise(USAGE)
        end
    end
    return options
end

function registry(options)
    if options["merge-into"] and options.constants then
        merge_constants(options)
    else
        full_regeneration(options)
    end
end

function main(...)
    registry(options_of({...}))
    return 0
end
