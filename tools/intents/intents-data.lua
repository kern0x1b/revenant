-- The intents generator's tables: which classes are hand written, what each initialiser parameter is for, the
-- causes a member is left out for, the bodies the header does not describe, and the state those bodies keep.
-- tools/intents/gen-intents.lua holds the rules that read them. Each body is the text the generator writes, a
-- Python string made a Lua one: the comments are the Python ones, and a key is "CLASS selector" with one space
-- between the two (and "CLASS selector parameter" for a parameter key).
--
-- data() returns the tables as fields of one table, because the xmake module import exposes functions only.

function data()
    local D = {}

    -- The ten classes whose bodies are hand written in CharonIntents100.m.
    D.hand_written = {
        INParameter = true,
        INIntent = true,
        INIntentResolutionResult = true,
        INInteraction = true,
        INImage = true,
        INSpeakableString = true,
        INVocabulary = true,
        INPreferences = true,
        INExtension = true,
        INPaymentMethod = true,
        INRideCompletionStatus = true,
    }

    -- The base every resolution result shares, and the factories that fill it.
    D.resolution_base = "INIntentResolutionResult"

    -- Where an initialiser parameter goes when the header's own names differ. Each entry names the class, the selector
    -- (false for any selector of that class), the parameter, and the property or properties the value belongs in. Every
    -- line was read off the header of iPhoneOS16.4 and is repeated in facts/Intents/Intents.md.
    D.parameter_properties = {
        -- INBillPayee and INPaymentAccount take the number of an account and expose it as accountNumber; the class has
        -- exactly one NSString property, which is that one.
        {"INBillPayee", "initWithNickname:number:organizationName:", "number", {"accountNumber"}},
        {"INPaymentAccount", "initWithNickname:number:accountType:organizationName:", "number", {"accountNumber"}},
        {"INPaymentAccount", "initWithNickname:number:accountType:organizationName:balance:secondaryBalance:", "number",
         {"accountNumber"}},
        -- INPriceRange: "the lowest of the two prices used to construct this range" is the header's own comment on
        -- minimumPrice, and the highest is maximumPrice, and initWithPrice: gives one price that is both ends of the range.
        {"INPriceRange", "initWithRangeBetweenPrice:andPrice:currencyCode:", "firstPrice", {"minimumPrice"}},
        {"INPriceRange", "initWithRangeBetweenPrice:andPrice:currencyCode:", "secondPrice", {"maximumPrice"}},
        {"INPriceRange", "initWithPrice:currencyCode:", "price", {"minimumPrice", "maximumPrice"}},
        -- INInteraction's designated initialiser spells the response intentResponse.
        {"INInteraction", false, "response", {"intentResponse"}},
    }

    -- Properties whose ownership is copy: the setter copies, the rest retain. A set of base type names.
    D.copied = {
        NSString = true, NSAttributedString = true, NSMutableString = true, NSDictionary = true,
        NSMutableDictionary = true, NSArray = true, NSMutableArray = true, NSSet = true, NSMutableSet = true,
        NSOrderedSet = true, NSMutableOrderedSet = true, NSIndexSet = true, NSData = true, NSDate = true,
        NSURL = true, NSUUID = true, NSCharacterSet = true, NSLocale = true, NSDateComponents = true,
        NSRegularExpression = true, INSpeakableString = true, INImage = true, NSError = true,
    }

    -- A class that must be an object file of its own, with the measurement that says why: INPaymentMethodResolutionResult
    -- is the one class of its group that a release below the group's own already exports (see ALONE_REASON in the
    -- generator, and tools/intents/measure-group.lua).
    D.alone = {
        INPaymentMethodResolutionResult = "10.3",
    }

    -- Why a member is not answered, one cause per way the generator leaves one out. The registry writes the reason
    -- from these, so a reason names the cause and not the owner's group.
    D.causes = {
        later_group = "the class this member's type names is in a later group of this same delivery",
        forward_only_class = "the class this member's type names is a class the SDK's headers only forward declare, so "
            .. "no header of the port's own SDK defines it and a body would not compile against one",
        deferred_value = "an initialiser that takes a value of a class this delivery does not carry is not given a "
            .. "body, because a body that dropped the value would answer with a class that looks filled and is not",
        chain_nonnull = "the superclass's designated initialiser takes a parameter the SDK does not mark nullable and "
            .. "nothing in the headers says where a subclass would get one, so the port refuses to chain rather than "
            .. "make a call the SDK forbids",
        chain_no_designated = "the superclass declares this value read-only and offers no designated initialiser to "
            .. "keep it in, so there is no chain to make",
        unavailable = "the header marks the initialiser unavailable, so a port cannot call it",
        collection_factory = "a factory that answers an array of resolution results is a collection the framework's "
            .. "system builds, and there is no system here to read the values out of one",
        class_property = "a property of the class's own type on the class is the class's own identity, which the "
            .. "runtime holds, and there is no storage for it to keep",
        foreign_class = "the type is a class of a framework this package does not carry, and no header of the port's "
            .. "own SDK declares it, so there is nothing to keep the value in",
        not_declared = "the SDK's own headers do not declare this member, so there is nothing to answer",
        unanswered = "a member of a class of a later group of this same delivery",
    }

    -- The same causes in the short form a @dynamic line in the generated source can carry.
    D.cause_labels = {
        later_group = "a class of a later group",
        forward_only_class = "a class the headers only forward declare",
        class_property = "a property of the class's own type",
        unanswered = "a class of a later group",
    }

    -- The enumerations whose zero case is the one that says nothing, measured from the host: its own framework logs
    -- "Success resolution with <Enum>Unknown will be reformed to notRequired." for a success carrying that case
    -- (observed on the host's own Intents, 2026-09-27, for INCarSignalOptions, INTaskStatus, INRadioType,
    -- INRelativeReference, INRelativeSetting, INTaskPriority, INVisualCodeType, INWorkoutGoalUnitType and
    -- INWorkoutLocationType).
    D.neutral_enumerations = {
        INCallDestinationType = true, INCallRecordType = true, INCallRecordTypeOptions = true,
        INCarAudioSource = true, INCarDefroster = true, INCarSeat = true, INCarSignalOptions = true,
        INDateSearchType = true, INLocationSearchType = true, INMediaAffinityType = true,
        INNoteContentType = true, INPhotoAttributeOptions = true, INRadioType = true,
        INRelativeReference = true, INRelativeSetting = true, INTaskPriority = true, INTaskStatus = true,
        INTemporalEventTriggerTypeOptions = true, INVisualCodeType = true, INWorkoutGoalUnitType = true,
        INWorkoutLocationType = true,
    }

    -- A member whose body is a derivation the header describes rather than a store, written here with
    -- the header's own words for what it builds: a generated body could only put the parameter under
    -- a name of the generator's making, which is not a member of the class.
    D.extra_methods = {
        ["INObjectCollection initWithItems:"] = {
            "- (instancetype)initWithItems:(NSArray *)items",
            "{",
            "    // The header's own two properties say what a collection of items is: allItems is the",
            "    // items, and sections is them under one section with no title. Collation is not",
            "    // indexed, because the items arrive in the order they were given and nothing here",
            "    // sorts them.",
            "    INObjectSection *section =",
            "        [[INObjectSection alloc] initWithTitle:nil items:items ?: [NSArray array]];",
            "    if ((self = [super init])) {",
            "        _sections = @[section];",
            "        _allItems = [items copy] ?: [NSArray array];",
            "        _usesIndexedCollation = NO;",
            "    }",
            "    return self;",
            "}",
        },
        -- The four singleton accessors. Each of these headers names the accessor and says to use it -
        -- "@c Use the @c defaultStore singleton" - so the accessor is the class's whole surface and the
        -- one object for the process is what it answers. dispatch_once is the tree's own spelling of
        -- one instance for the process: packages/a/apple-backports/Intents/CharonIntents100.m's
        -- +[INVocabulary sharedVocabulary] is this body.
        -- And it is measured, not only read: tests/backports/host/intents/intents12-rows.m asks the
        -- system's own Intents for each of the three of this group twice in one process and prints
        -- identical=1 for every one of them (macOS 27.0 build 26A428, arm64). The header's note and the
        -- host's answer are the same claim from two directions.
        ["INRelevantShortcutStore defaultStore"] = {
            "+ (INRelevantShortcutStore *)defaultStore",
            "{",
            "    // The header's own note is to use this singleton, so it is one object for the process;",
            "    // measured on the host's own Intents, two calls return the same object.",
            "    static INRelevantShortcutStore *shared;",
            "    static dispatch_once_t once;",
            "    dispatch_once(&once, ^{",
            "        shared = [[INRelevantShortcutStore alloc] init];",
            "    });",
            "    return shared;",
            "}",
        },
        ["INUpcomingMediaManager sharedManager"] = {
            "+ (INUpcomingMediaManager *)sharedManager",
            "{",
            "    // The header's own note is to use this singleton, so it is one object for the process;",
            "    // measured on the host's own Intents, two calls return the same object.",
            "    static INUpcomingMediaManager *shared;",
            "    static dispatch_once_t once;",
            "    dispatch_once(&once, ^{",
            "        shared = [[INUpcomingMediaManager alloc] init];",
            "    });",
            "    return shared;",
            "}",
        },
        ["INVoiceShortcutCenter sharedCenter"] = {
            "+ (INVoiceShortcutCenter *)sharedCenter",
            "{",
            "    // The header's own note is to use this singleton, so it is one object for the process;",
            "    // measured on the host's own Intents, two calls return the same object.",
            "    static INVoiceShortcutCenter *shared;",
            "    static dispatch_once_t once;",
            "    dispatch_once(&once, ^{",
            "        shared = [[INVoiceShortcutCenter alloc] init];",
            "    });",
            "    return shared;",
            "}",
        },
        -- The three classes of this group whose header marks +new unavailable. NS_UNAVAILABLE is a
        -- compile-time attribute and the runtime never sees it, so the class keeps the +new it
        -- inherits, and the release answers it: measured on the host's own Intents, all three are
        -- answered, all three return an object with no exception, and all three are answered by
        -- NSObject's own +new - their metaclass chain declares the selector there and nowhere else
        -- (tools/intents/probe-host-absent.sh against registry/Intents/ios12.json, control 100 rows
        -- found and 55 answered in the same process). WHICH object each one returns is a second
        -- measurement, by tests/backports/host/intents/intents12-rows.m: each returns an instance of
        -- its own class and not of NSObject. So the answer is NSObject's +new and not a new one,
        -- and it is reached through its IMP for the same reason the -init of each of these three
        -- classes is: the header forbids naming the selector.
        ["INShortcut new"] = {
            "+ (instancetype)new",
            "{",
            "    // The header marks this class's +new unavailable, which the runtime never sees:",
            "    // measured, +[INShortcut new] is answered and returns an INShortcut, and what",
            "    // answers it is NSObject's own +new. So the method is defined here and that one is",
            "    // reached through its IMP, because the header forbids naming the selector.",
            "    Class parent = [NSObject class];",
            "    SEL selector = @selector(new);",
            "    IMP forward = parent ? class_getMethodImplementation(parent, selector) : NULL;",
            "    return forward ? ((id (*)(id, SEL))forward)(self, selector) : nil;",
            "}",
        },
        ["INVoiceShortcut new"] = {
            "+ (instancetype)new",
            "{",
            "    // The header marks this class's +new unavailable, which the runtime never sees:",
            "    // measured, +[INVoiceShortcut new] is answered and returns an INVoiceShortcut, and",
            "    // what answers it is NSObject's own +new. So the method is defined here and that one",
            "    // is reached through its IMP, because the header forbids naming the selector.",
            "    Class parent = [NSObject class];",
            "    SEL selector = @selector(new);",
            "    IMP forward = parent ? class_getMethodImplementation(parent, selector) : NULL;",
            "    return forward ? ((id (*)(id, SEL))forward)(self, selector) : nil;",
            "}",
        },
        ["INVoiceShortcutCenter new"] = {
            "+ (instancetype)new",
            "{",
            "    // The header marks this class's +new unavailable, which the runtime never sees:",
            "    // measured, +[INVoiceShortcutCenter new] is answered and returns an",
            "    // INVoiceShortcutCenter, and what answers it is NSObject's own +new. So the method is",
            "    // defined here and that one is reached through its IMP, because the header forbids",
            "    // naming the selector. The header's note is to use +sharedCenter; +new is answered",
            "    // anyway, and this answers it the way the release does.",
            "    Class parent = [NSObject class];",
            "    SEL selector = @selector(new);",
            "    IMP forward = parent ? class_getMethodImplementation(parent, selector) : NULL;",
            "    return forward ? ((id (*)(id, SEL))forward)(self, selector) : nil;",
            "}",
        },
        ["INFocusStatusCenter defaultCenter"] = {
            "+ (INFocusStatusCenter *)defaultCenter",
            "{",
            "    // The header's own note is to use this singleton, so it is one object for the process.",
            "    static INFocusStatusCenter *shared;",
            "    static dispatch_once_t once;",
            "    dispatch_once(&once, ^{",
            "        shared = [[INFocusStatusCenter alloc] init];",
            "    });",
            "    return shared;",
            "}",
        },
        ["INRelevantShortcutStore setRelevantShortcuts:completionHandler:"] = {
            "- (void)setRelevantShortcuts:(NSArray<INRelevantShortcut *> *)shortcuts",
            "    completionHandler:(void (^ __nullable)(NSError * __nullable error))completionHandler",
            "{",
            "    // The header's own note is that a new set replaces every one provided before, so the",
            "    // whole set is replaced here rather than added to. This release runs no assistant",
            "    // daemon to read the set, so it is kept in the class's own state.",
            "    //",
            "    // The handler is answered AFTER this method returns, which is what the framework does",
            "    // and is measured: tests/backports/host/intents/intents12-rows.m prints",
            "    // before-return=0 and within-5s=1 for -setRelevantShortcuts:completionHandler: on the",
            "    // singleton, and a handler called before the method returned would answer with",
            "    // before-return=1, which the harness now fails on. A caller that sets its own state",
            "    // after the call and reads it in the handler is the caller this keeps working: with a",
            "    // synchronous answer the handler runs before that state exists.",
            "    //",
            "    // ON A BACKGROUND THREAD, and that is measured too rather than assumed: the same run",
            "    // reports isMainThread=0, and the handler fires with NO run loop turning at all, so it",
            "    // is not the main queue and needs no run loop of the caller's. The default global queue",
            "    // is the tree's spelling of a background thread of the port's own; which queue the",
            "    // framework uses is not measurable from outside it, and no claim is made that it is",
            "    // this one - only that this one is likewise not the caller's thread and likewise needs",
            "    // no run loop. GCD is iOS 4.0 and this release is 6.1.3, and dispatch_once above is the",
            "    // same header's.",
            "    //",
            "    // The VALUE is the framework's own: a nil error. On a receiver that is not the",
            "    // singleton the framework never calls this handler at all inside the window",
            "    // (within-5s=0); that is recorded and not imitated, because a handler that never runs",
            "    // is a hang and this port answers every receiver.",
            "    _relevantShortcuts = [shortcuts copy] ?: [NSArray array];",
            "    if (completionHandler) {",
            "        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{",
            "            completionHandler(nil);",
            "        });",
            "    }",
            "}",
        },
        ["INUpcomingMediaManager setSuggestedMediaIntents:"] = {
            "- (void)setSuggestedMediaIntents:(NSOrderedSet<INPlayMediaIntent *> *)intents",
            "{",
            "    // The header calls these the intents to suggest. This release runs no assistant daemon",
            "    // to read them, so they are kept in the class's own state in the order they were given.",
            "    _suggestedMediaIntents = [intents copy] ?: [NSOrderedSet orderedSet];",
            "}",
        },
        ["INUpcomingMediaManager setPredictionMode:forType:"] = {
            "- (void)setPredictionMode:(INUpcomingMediaPredictionMode)mode",
            "    forType:(INMediaItemType)type",
            "{",
            "    // One mode per media item type, which is what the selector says: it takes the type, so",
            "    // the mode asked about a type is that type's own. Nothing here predicts anything -",
            "    // there is no assistant daemon on this release - so the mode is kept to be read back.",
            "    NSNumber *key = [NSNumber numberWithInteger:(NSInteger)type];",
            "    if (!_predictionModes) {",
            "        _predictionModes = [[NSMutableDictionary alloc] init];",
            "    }",
            "    if (mode == INUpcomingMediaPredictionModeDefault) {",
            "        [_predictionModes removeObjectForKey:key];",
            "    } else {",
            "        [_predictionModes setObject:[NSNumber numberWithInteger:(NSInteger)mode] forKey:key];",
            "    }",
            "}",
        },
        ["INVoiceShortcutCenter setShortcutSuggestions:"] = {
            "- (void)setShortcutSuggestions:(NSArray<INShortcut *> *)suggestions",
            "{",
            "    // Suggestions replace the ones before, as the header's discussion describes, with each one shown",
            "    // in the Shortcuts app - which this release has no app for. They are kept",
            "    // in the class's own state in the order they were offered.",
            "    _shortcutSuggestions = [suggestions copy] ?: [NSArray array];",
            "}",
        },
        ["INVoiceShortcutCenter getAllVoiceShortcutsWithCompletion:"] = {
            "- (void)getAllVoiceShortcutsWithCompletion:",
            "    (void (^)(NSArray<INVoiceShortcut *> * _Nullable, NSError * _Nullable))completionHandler",
            "{",
            "    // This release runs no assistant daemon and has no Shortcuts app, so no shortcut was",
            "    // ever added to Siri: the answer is an empty array and no error. Both are the",
            "    // framework's own, measured by tests/backports/host/intents/intents12-rows.m: count=0,",
            "    // the array is not nil, and the error is nil.",
            "    //",
            "    // It is answered AFTER this method returns, on a background thread, and both are",
            "    // measured: before-return=0, isMainThread=0, and the handler fires with no run loop",
            "    // turning at all. The harness now FAILS on before-return=1, so a synchronous answer",
            "    // cannot come back unnoticed; -setRelevantShortcuts:completionHandler: gives why the",
            "    // timing is the whole of the difference that matters to a caller.",
            "    //",
            "    // A nil handler is not called.",
            "    if (completionHandler) {",
            "        NSArray<INVoiceShortcut *> *answer = [NSArray array];",
            "        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{",
            "            completionHandler(answer, nil);",
            "        });",
            "    }",
            "}",
        },
        ["INVoiceShortcutCenter getVoiceShortcutWithIdentifier:completion:"] = {
            "- (void)getVoiceShortcutWithIdentifier:(NSUUID *)identifier",
            "    completion:(void (^)(INVoiceShortcut * _Nullable, NSError * _Nullable))completionHandler",
            "{",
            "    // The same empty store as getAllVoiceShortcutsWithCompletion:, read by the identifier",
            "    // this release was never given one for: nil and no error, which is what the framework",
            "    // answers with too (intents12-rows.m: shortcut=nil error=nil), after the method returns",
            "    // and on a background thread - the same two facts that member gives. A nil handler is",
            "    // not called.",
            "    if (completionHandler) {",
            "        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{",
            "            completionHandler(nil, nil);",
            "        });",
            "    }",
            "}",
        },

        -- INFile: the header says a file holds its data and the name and uniform type identifier it
        -- was given, and that data made from a URL memory maps on access - so the URL is kept and the
        -- data is read through it rather than cached twice. -init is NS_UNAVAILABLE in the header and
        -- the generator emits a body for it anyway (see own_init_unavailable), which is why these two
        -- can allocate.
        ["INFile fileWithData:filename:typeIdentifier:"] = {
            "+ (INFile *)fileWithData:(NSData *)data",
            "    filename:(NSString *)filename",
            "    typeIdentifier:(NSString * __nullable)typeIdentifier",
            "{",
            "    // Data in memory: there is no URL, and the header's own fileURL property answers nil.",
            "    INFile *file = [[INFile alloc] init];",
            "    file->_data = [data copy];",
            "    file->_filename = [filename copy];",
            "    file->_typeIdentifier = [typeIdentifier copy];",
            "    return file;",
            "}",
        },
        ["INFile fileWithFileURL:filename:typeIdentifier:"] = {
            "+ (INFile *)fileWithFileURL:(NSURL *)fileURL",
            "    filename:(NSString * __nullable)filename",
            "    typeIdentifier:(NSString * __nullable)typeIdentifier",
            "{",
            "    // A file on disk: the URL is kept so the data property memory maps it on access, and a",
            "    // filename the caller gave is kept as it is - the header makes it nullable here, so no",
            "    // name is invented for a file whose caller offered none.",
            "    INFile *file = [[INFile alloc] init];",
            "    file->_fileURL = [fileURL copy];",
            "    file->_filename = [filename copy];",
            "    file->_typeIdentifier = [typeIdentifier copy];",
            "    return file;",
            "}",
        },
        -- The accessors the two factories above fill. They are readonly in the header, so nothing
        -- synthesises them: with the fields in EXTRA_IVARS a body reads them directly.
        ["INFile data"] = {
            "- (NSData *)data",
            "{",
            "    // A file made from a URL memory maps its contents on access, as the header says, so the",
            "    // bytes are read where they are rather than copied into a second copy of the file.",
            "    if (!_data && _fileURL) {",
            "        _data = [NSData dataWithContentsOfURL:_fileURL];",
            "    }",
            "    return _data;",
            "}",
        },
        ["INFile filename"] = {
            "- (NSString *)filename",
            "{",
            "    return _filename;",
            "}",
        },
        ["INFile typeIdentifier"] = {
            "- (NSString *)typeIdentifier",
            "{",
            "    return _typeIdentifier;",
            "}",
        },
        ["INFile fileURL"] = {
            "- (NSURL *)fileURL",
            "{",
            "    // A file made from data was never on disk, and the header's property is nullable.",
            "    return _fileURL;",
            "}",
        },
        ["INSendMessageAttachment attachmentWithAudioMessageFile:"] = {
            "+ (INSendMessageAttachment *)attachmentWithAudioMessageFile:(INFile *)audioMessageFile",
            "{",
            "    // The header names this the audio message file of the attachment, and it is the class's",
            "    // only property, so the attachment is that file and nothing else.",
            "    INSendMessageAttachment *attachment = [[INSendMessageAttachment alloc] init];",
            "    attachment->_audioMessageFile = [audioMessageFile copy];",
            "    return attachment;",
            "}",
        },
        ["INSendMessageAttachment audioMessageFile"] = {
            "- (INFile *)audioMessageFile",
            "{",
            "    return _audioMessageFile;",
            "}",
        },
        ["INMediaDestination libraryDestination"] = {
            "+ (instancetype)libraryDestination",
            "{",
            "    // The header's own two properties say what this is: a destination whose type is the",
            "    // library's and whose playlist name is none, which is the difference between it and",
            "    // +playlistDestinationWithName:.",
            "    INMediaDestination *destination = [[INMediaDestination alloc] init];",
            "    destination->_mediaDestinationType = INMediaDestinationTypeLibrary;",
            "    return destination;",
            "}",
        },
        ["INMediaDestination playlistDestinationWithName:"] = {
            "+ (instancetype)playlistDestinationWithName:(NSString *)playlistName",
            "{",
            "    // The same destination type as +libraryDestination with the name kept, which is the one",
            "    // difference the header's two properties can express.",
            "    INMediaDestination *destination = [[INMediaDestination alloc] init];",
            "    destination->_mediaDestinationType = INMediaDestinationTypePlaylist;",
            "    destination->_playlistName = [playlistName copy];",
            "    return destination;",
            "}",
        },
        ["INMediaDestination mediaDestinationType"] = {
            "- (INMediaDestinationType)mediaDestinationType",
            "{",
            "    return _mediaDestinationType;",
            "}",
        },
        ["INMediaDestination playlistName"] = {
            "- (NSString * __nullable)playlistName",
            "{",
            "    return _playlistName;",
            "}",
        },
        ["INUserContext becomeCurrent"] = {
            "- (void)becomeCurrent",
            "{",
            "    // The header marks this unavailable in an extension and calls it nothing else: it tells",
            "    // the system that this context is the current one, and there is no system on this",
            "    // release to tell - no assistant daemon reads a user context - so there is nothing to do",
            "    // and nothing to record. Saying so is the whole of the answer; inventing a current",
            "    // context that nothing reads would be a value that looks filled and is not.",
            "}",
        },
        ["INAddTasksTargetTaskListResolutionResult confirmationRequiredWithTaskListToConfirm:forReason:"] = {
            "+ (instancetype)confirmationRequiredWithTaskListToConfirm:(INTaskList * __nullable)taskListToConfirm",
            "    forReason:(INAddTasksTargetTaskListConfirmationReason)reason",
            "{",
            "    // The same answer the typed task-list factories build, with the task list to confirm as the value to confirm, and",
            "    // the reason kept for confirmationReason: the host reads it back as given (tests/backports/host/resolution-factories).",
            "    return [self confirmationRequiredWithItemToConfirm:taskListToConfirm forReason:reason];",
            "}",
        },
        ["INFocusStatusCenter requestAuthorizationWithCompletionHandler:"] = {
            "- (void)requestAuthorizationWithCompletionHandler:",
            "    (void (^ __nullable)(INFocusStatusAuthorizationStatus status))completionHandler",
            "{",
            "    // The same answer packages/a/apple-backports/Intents/CharonIntents100.m gives for",
            "    // +[INPreferences requestSiriAuthorization:]: this release has no Focus setting to ask",
            "    // about and no prompt to show, so it answers the handler with Restricted rather than",
            "    // leaving the handler waiting for a system that will never call it. A nil handler is not",
            "    // called.",
            "    if (completionHandler) {",
            "        completionHandler(INFocusStatusAuthorizationStatusRestricted);",
            "    }",
            "}",
        },

        ["INCar maximumPowerForChargingConnectorType:"] = {
            "- (NSMeasurement<NSUnitPower *> *)maximumPowerForChargingConnectorType:",
            "    (INCarChargingConnectorType)chargingConnectorType",
            "{",
            "    // The header's own two methods are a pair: this one reads what the setter wrote for",
            "    // that connector type, and answers nil for a type nothing was set for. NSMeasurement",
            "    // and NSUnitPower are Foundation's own and are carried by this delivery (minimum 6.0),",
            "    // so the value has somewhere real to be kept.",
            "    NSNumber *key = [NSNumber numberWithInteger:(NSInteger)chargingConnectorType];",
            "    return [_maximumPowerByConnectorType objectForKey:key];",
            "}",
        },
        ["INCar setMaximumPower:forChargingConnectorType:"] = {
            "- (void)setMaximumPower:(NSMeasurement<NSUnitPower *> *)power",
            "    forChargingConnectorType:(INCarChargingConnectorType)chargingConnectorType",
            "{",
            "    // One maximum per connector type, which is what the selector says. A nil power removes",
            "    // the entry rather than storing a nil, so the reader's nil means \"set to nothing\".",
            "    if (!_maximumPowerByConnectorType) {",
            "        _maximumPowerByConnectorType = [[NSMutableDictionary alloc] init];",
            "    }",
            "    NSNumber *key = [NSNumber numberWithInteger:(NSInteger)chargingConnectorType];",
            "    if (power) {",
            "        [_maximumPowerByConnectorType setObject:power forKey:key];",
            "    } else {",
            "        [_maximumPowerByConnectorType removeObjectForKey:key];",
            "    }",
            "}",
        },
        -- INMediaDestination's two properties are readonly and its -init is NS_UNAVAILABLE, so the two
        -- class methods below are the only way to make one and they fill these.
        ["INMediaDestination"] = {
            "    INMediaDestinationType _mediaDestinationType;  // mediaDestinationType",
            "    NSString * _playlistName;  // playlistName",
        },
    }

    -- The state a hand-written body keeps that the class's own headers declare no property for, so it
    -- has no @synthesize and no coding or copying entry. Each field is named after the method that
    -- writes it, and the body says what it owns.

    -- The state a hand-written body keeps that the class's own headers declare no property for, so it
    -- has no @synthesize and no coding or copying entry. Each field is named after the method that
    -- writes it, and the body says what it owns.
    D.extra_ivars = {
        ["INRelevantShortcutStore"] = {
            "    NSArray * _relevantShortcuts;  // setRelevantShortcuts:completionHandler:",
        },
        ["INUpcomingMediaManager"] = {
            "    NSOrderedSet * _suggestedMediaIntents;  // setSuggestedMediaIntents:",
            "    NSMutableDictionary * _predictionModes;  // setPredictionMode:forType:, by media item type",
        },
        ["INVoiceShortcutCenter"] = {
            "    NSArray * _shortcutSuggestions;  // setShortcutSuggestions:",
        },
        -- INFile and INSendMessageAttachment are NOT here: their properties are readonly but they are
        -- still the class's own, so the generator synthesises the ivar and the accessor for each, and a
        -- second declaration of the same field is "duplicate member" at compile time. Their two
        -- factories only fill what is already there. Listing them cost a red gate: IN16_0.m:1584-1588
        -- and :3978, six errors, all of them this.
        -- The header's two charging-power methods are a read/write pair keyed by connector type, so
        -- the field is a dictionary and neither is a property the header declares.
        ["INCar"] = {
            "    NSMutableDictionary * _maximumPowerByConnectorType;  // maximumPowerForChargingConnectorType:",
        },
    }


-- Charon's OWN readers for the stores the headers ask to be written. They are not in
-- EXTRA_METHODS because EXTRA_METHODS is consulted while walking the header's OWN declared
-- methods, and a reader no header declares is never visited there: the four of these were
-- written to EXTRA_METHODS and silently emitted nowhere. They are emitted from here instead,
-- after the declared members, and only for a class this file generates.
    D.charon_readers = {
        -- A reader for each store the headers ask to be written. A setter whose value nothing can read
        -- back is a field that only grows, and a port that offered a shortcut has no way to see that it
        -- did - which is the state this delivery is meant to keep. The name is Charon's own, so it
        -- collides with nothing Apple has and it is hidden at the link, and each class row's `effect`
        -- names it the way INVocabulary's names charon_vocabularyStringsOfType:.
        ["INRelevantShortcutStore charon_relevantShortcuts"] = {
            "- (NSArray *)charon_relevantShortcuts",
            "{",
            "    // What setRelevantShortcuts:completionHandler: was last given, in the order it was",
            "    // given, or an empty array before anything was. Where a port reads back what it",
            "    // offered: on a release with Siri the system is the reader instead.",
            "    return _relevantShortcuts ?: [NSArray array];",
            "}",
        },
        ["INUpcomingMediaManager charon_suggestedMediaIntents"] = {
            "- (NSOrderedSet *)charon_suggestedMediaIntents",
            "{",
            "    // What setSuggestedMediaIntents: was last given, in the order it was given, or an empty",
            "    // ordered set before anything was.",
            "    return _suggestedMediaIntents ?: [NSOrderedSet orderedSet];",
            "}",
        },
        ["INVoiceShortcutCenter charon_shortcutSuggestions"] = {
            "- (NSArray *)charon_shortcutSuggestions",
            "{",
            "    // What setShortcutSuggestions: was last given, in the order it was given, or an empty",
            "    // array before anything was.",
            "    return _shortcutSuggestions ?: [NSArray array];",
            "}",
        },
        ["INUpcomingMediaManager charon_predictionModeForType:"] = {
            "- (INUpcomingMediaPredictionMode)charon_predictionModeForType:(INMediaItemType)type",
            "{",
            "    // What setPredictionMode:forType: recorded for that media item type, and the enumeration",
            "    // own zero case - Default - for a type nothing was set for, which is what a dictionary",
            "    // with no entry for it answers.",
            "    NSNumber *mode = [_predictionModes objectForKey:[NSNumber numberWithInteger:(NSInteger)type]];",
            "    return mode ? (INUpcomingMediaPredictionMode)[mode integerValue] : INUpcomingMediaPredictionModeDefault;",
            "}",
        },
    }

    return D
end
