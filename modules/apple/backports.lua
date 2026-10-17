import("macho")
import("dyld")
import("firmware")
import("signing")
import("objc")
import("core.base.json")
import("core.base.scheduler")
import("cache")
-- The byte order of every name sort here (modules/byteorder.lua): Lua's `<` on strings follows the process locale.
import("byteorder", {rootdir = path.join(os.scriptdir(), "..")})

-- A library stands after every library it names in `libraries`: link() finds those in the output folder, so they are built first.
LIBRARIES = {
    -- libicucore carries the four udtitvfmt_* entry points NSDateIntervalFormatter is built on, exported by the
    -- release from iOS 5.0 on and by none before it, so the class floor is 5.0; the imports are weak, so a
    -- release whose libicucore lacks them binds NULL and the class answers nil rather than faulting.
    {name = "FoundationBackports", folder = "Foundation", frameworks = {"Foundation", "CoreFoundation", "SystemConfiguration"}, libraries = {"icucore"}},
    {name = "CloudKitBackports", folder = "CloudKit", frameworks = {"Foundation", "CoreLocation", "CoreGraphics"}, libraries = {"FoundationBackports"}, archives = {"micro-ecc"}, c_archives = {"micro-ecc"}},
    {name = "AppTrackingTransparencyBackports", folder = "AppTrackingTransparency", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AdServicesBackports", folder = "AdServices", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AppClipBackports", folder = "AppClip", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AccountsBackports", folder = "Accounts", frameworks = {"Accounts", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CFNetworkBackports", folder = "CFNetwork", frameworks = {"CFNetwork", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "IOSurfaceBackports", folder = "IOSurface", frameworks = {"IOSurface", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreServicesBackports", folder = "CoreServices", frameworks = {"CoreServices", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "IOKitBackports", folder = "IOKit", frameworks = {"IOKit", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "BrowserKitBackports", folder = "BrowserKit", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreNFCBackports", folder = "CoreNFC", frameworks = {"Foundation", "CoreFoundation"}, libraries = {"FoundationBackports"}},
    {name = "GameKitBackports", folder = "GameKit", frameworks = {"GameKit", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "GraphicsBackports", folder = "Graphics", generated = {"ImageIO", "CoreImage"}, frameworks = {"CoreGraphics", "CoreImage", "CoreVideo", "ImageIO", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "UIKitBackports", folder = "UIKit", frameworks = {"UIKit", "Foundation", "CFNetwork", "CoreGraphics", "QuartzCore", "MobileCoreServices", "ImageIO", "CoreLocation"}, libraries = {"FoundationBackports", "GraphicsBackports"}, archives = {"box2d"}},
    {name = "CoreLocationBackports", folder = "CoreLocation", frameworks = {"CoreLocation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreTextBackports", folder = "CoreText", frameworks = {"CoreText", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreDataBackports", folder = "CoreData", frameworks = {"CoreData", "Foundation"}, libraries = {"FoundationBackports"}},
    -- micro-ecc is the P-256 arithmetic iOS 6 has no way to sign with (SecKeyCreateRandomKey and
    -- SecKeyCreateSignature are iOS 8): Security/SecKeyElliptic10.m signs, verifies and exchanges over it
    -- for the keys this package makes itself. Every name it needs begins with Charon, so
    -- internal_symbol() keeps the curve out of this library's exports.
    --
    -- c_archives, because the archive's API is C and this library keeps no .mm object in any band:
    -- `archives` alone would be dropped by link()'s cxx rule in every band, and
    -- SecKeyElliptic10.o would carry _CharonCKDigestSignES256, _CharonCKDigestVerifyES256 and
    -- _CharonCKSharedSecretES256 undefined, with the wrapper that defines them on the link line
    -- nowhere. Measured before this line: `SecurityBackports sources=28 has .mm=false
    -- archives=micro-ecc on the link line: (empty) dropped: micro-ecc`, and
    -- tests/addon/archive_language_test.lua failing on exactly that. The same shape charon-coding and
    -- monocypher use, for the same reason.
    {name = "SecurityBackports", folder = "Security", frameworks = {"Security", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"micro-ecc"}, c_archives = {"micro-ecc"}},
    {name = "CommonCryptoBackports", folder = "CommonCrypto", frameworks = {"Security"}, libraries = {}},
    -- The constant only: CBAdvertisementDataIsConnectable is a string, so the library links no CoreBluetooth (the central is dlopen'd).
    {name = "CoreBluetoothBackports", folder = "CoreBluetooth", frameworks = {"Foundation"}, libraries = {}},
    -- The codecs are C, with no Objective-C++ object in the band, so they are c_archives (see the note on SecurityBackports above);
    -- the Compression framework itself is none of the release's, so no framework is linked.
    {name = "CompressionBackports", folder = "Compression", frameworks = {}, libraries = {}, archives = {"lzfse", "zlib", "lz4", "xz"}, c_archives = {"lzfse", "zlib", "lz4", "xz"}},
    -- The Spatial functions are C with no Objective-C object in any band. Their SDK availability starts at iOS 16
    -- (spec/Spatial/declarations.tsv), so the library carries them alone: no framework is linked, no archive either.
    {name = "SpatialBackports", folder = "Spatial", frameworks = {}, libraries = {}},
    -- The sqlite3_str builder and the keyword functions are C over libsqlite3 itself (sqlite3_malloc, sqlite3_realloc,
    -- sqlite3_vmprintf and sqlite3_limit, which iOS 6's libsqlite3 has), so the library names the system's sqlite3 and
    -- links no framework: the functions are absent from 6.1.3 and carried here from the release that added them.
    {name = "SQLite3Backports", folder = "SQLite3", frameworks = {}, libraries = {"sqlite3"}},
    -- SpriteKit is absent from iOS 6 and its classes are the port's own, so the library links no SpriteKit framework: a
    -- SpriteKit symbol named here would be a strong import the device cannot satisfy. Its first object is SKUniform of
    -- iOS 8, which needs Foundation alone (SpriteKit/SpriteKit8.m).
    {name = "SpriteKitBackports", folder = "SpriteKit", frameworks = {"Foundation", "CoreGraphics", "UIKit", "QuartzCore", "OpenGLES"}, libraries = {}},
    -- suitesparse-ordering is AMD and COLAMD, the two sparse orderings, as a static archive: the Sparse*
    -- solve family needs an ordering and this stack's own rows must not export one. The archive is not
    -- API of the image, and the archive ITSELF is not a proof of that: AMD and COLAMD mark their entry
    -- points with their own AMD_EXPORT and COLAMD_EXPORT, which is visibility("default") and overrides
    -- the -fvisibility=hidden the recipe compiles with - measured, `nm -gU` on the built
    -- libSuiteSparseOrdering.a counts 28 global amd_* and colamd_* names, where the claim on the archive
    -- would say none. The proof the ruling asks for is on libAccelerateBackports.dylib and cannot be made
    -- until a caller exists: nothing in this tree references an ordering yet, so nothing here exports one
    -- either way, and when the first caller lands it is what the dylib's nm has to show. CHOLMOD,
    -- UMFPACK and the rest of SuiteSparse are not in that package: they are LGPL and GPL and this one is
    -- BSD-3.
    {name = "AccelerateBackports", folder = "Accelerate", frameworks = {"Accelerate", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"suitesparse-ordering"}, c_archives = {"suitesparse-ordering"}},
    {name = "AVFoundationBackports", folder = "AVFoundation", frameworks = {"AVFoundation", "CoreMedia", "CoreVideo", "AudioToolbox", "CoreImage", "ImageIO", "CoreGraphics", "QuartzCore", "Accelerate", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "GraphicsBackports", "AccelerateBackports"}, archives = {"charon-coding"}, c_archives = {"charon-coding"}},
    {name = "AVFAudioBackports", folder = "AVFAudio", frameworks = {"AudioToolbox", "CoreAudio", "AVFoundation", "UIKit", "Foundation", "Accelerate", "QuartzCore"}, libraries = {"FoundationBackports", "GraphicsBackports", "AccelerateBackports", "AVFoundationBackports"}},
    {name = "WebKitBackports", folder = "WebKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "LocalAuthenticationBackports", folder = "LocalAuthentication", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "OpenGLESBackports", folder = "OpenGLES", frameworks = {"OpenGLES", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SafariServicesBackports", folder = "SafariServices", frameworks = {"UIKit", "Foundation", "CoreGraphics", "QuartzCore", "MobileCoreServices"}, libraries = {"FoundationBackports"}},
    {name = "AuthenticationServicesBackports", folder = "AuthenticationServices", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports", "SafariServicesBackports"}},
    {name = "BackgroundTasksBackports", folder = "BackgroundTasks", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PhotosBackports", folder = "Photos", frameworks = {"AssetsLibrary", "AVFoundation", "CoreLocation", "CoreGraphics", "ImageIO", "MobileCoreServices", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "GameControllerBackports", folder = "GameController", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    -- Before Vision, because a library's libraries are linked before it (ld64 is given -l for
    -- each with only the linking library's own directory on its search path), and Vision's Core ML
    -- request is run on a real model: the framework for the headers, this library for the code.
    {name = "CoreMLBackports", folder = "CoreML", frameworks = {"CoreML", "CoreVideo", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "VisionBackports", folder = "Vision", frameworks = {"CoreGraphics", "CoreImage", "CoreVideo", "CoreML", "Foundation"}, libraries = {"FoundationBackports", "CoreMLBackports"}},
    {name = "MetalBackports", folder = "Metal", frameworks = {"QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MetalKitBackports", folder = "MetalKit", frameworks = {"UIKit", "QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports"}},
    {name = "MPSBackports", folder = "MetalPerformanceShaders", frameworks = {"Metal", "QuartzCore", "CoreGraphics", "OpenGLES", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports"}},
    {name = "MPSGraphBackports", folder = "MetalPerformanceShadersGraph", frameworks = {"Metal", "Foundation"}, libraries = {"FoundationBackports", "MetalBackports", "MPSBackports"}},
    {name = "CoreTelephonyBackports", folder = "CoreTelephony", frameworks = {"CoreTelephony", "Foundation"}, libraries = {"FoundationBackports"}},
    -- CoreMIDI's block forms (iOS 9), its Universal MIDI Packets and protocol-aware ports (iOS 14), over the release's MIDI 1.0
    -- CoreMIDI, which carries bytes only: the packets are converted here by the rules in facts/CoreMIDI/Translation.md.
    -- CoreBluetooth is not linked: the Bluetooth central opens it with dlopen on its first use (MIDIBluetooth16.m), so a process
    -- that never uses the central does not load the framework.
    {name = "CoreMIDIBackports", folder = "CoreMIDI", frameworks = {"CoreMIDI", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CallKitBackports", folder = "CallKit", frameworks = {"CoreTelephony", "AVFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "ContactsBackports", folder = "Contacts", frameworks = {"AddressBook", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "HomeKitBackports", folder = "HomeKit", frameworks = {"CoreLocation", "Foundation"}, libraries = {"FoundationBackports"}, archives = {"monocypher"}, c_archives = {"monocypher"}},
    {name = "CoreSpotlightBackports", folder = "CoreSpotlight", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PushKitBackports", folder = "PushKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "JavaScriptCoreBackports", folder = "JavaScriptCore", frameworks = {"JavaScriptCore", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SceneKitBackports", folder = "SceneKit", frameworks = {"UIKit", "QuartzCore", "OpenGLES", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "OpenGLESBackports"}},
    -- AVFoundation, for the one object here whose owner class is not MediaPlayer's:
    -- AVPlayerItem+NowPlayingInfo16.m is a category on AVPlayerItem, and a category's class reference
    -- is a symbol, so a band whose link does not carry AVFoundation leaves _OBJC_CLASS_$_AVPlayerItem
    -- undefined and ld fails - measured, the 6.1.3 armv7 band on exactly that name from
    -- __OBJC_$_CATEGORY_AVPlayerItem_$_CharonMPAdditions. AVPlayerItem is AVFoundation's class on this
    -- release - facts/MediaPlayer/WholeCacheRead.md, and the two armv7 inventories in the gate's own
    -- object store agree - and framework_install_path() below raises rather than quietly dropping a
    -- framework whose two ends of a band disagree, so this is a declaration the linker can bind.
    --
    -- It adds no image to a process, which is the whole cost question and the reason to answer it
    -- this way rather than by leaving the row out. This library links -framework MediaPlayer on
    -- every band, and the release's OWN libMediaPlayer already loads AVFoundation, so dyld has that
    -- image open before this library's first object runs. Measured, `otool -L` on the armv7
    -- MediaPlayer of 6.1.3 (~/.charon/dyld/6.1.3/MediaPlayer, the file that release ships beside
    -- its shared cache, so this is a read of a release file and not of a cache image): 39
    -- LC_LOAD_DYLIB entries, and among them
    --   /System/Library/Frameworks/AVFoundation.framework/AVFoundation (compatibility version 1.0.0, current version 2.0.0)
    -- beside CoreMedia, CoreVideo, CoreGraphics, ImageIO, QuartzCore, AudioToolbox and
    -- MobileCoreServices. So what this line buys is the DECLARATION, not a load: the linker can bind
    -- the category to the release's own AVPlayerItem, which nm -m shows as
    -- "(undefined) external _OBJC_CLASS_$_AVPlayerItem (from AVFoundation)" - the shape check_categories()
    -- accepts - instead of leaving a NULL class pointer in an image the loader never opened.
    -- AVKitBackports declares AVFoundation for the same reason and the same way: its
    -- AVPictureInPictureController.m holds an AVPlayerLayer, and AVPlayerLayer is AVFoundation's.
    {name = "MediaPlayerBackports", folder = "MediaPlayer", frameworks = {"MediaPlayer", "AVFoundation", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MessageUIBackports", folder = "MessageUI", frameworks = {"MessageUI", "MobileCoreServices", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MessagesBackports", folder = "Messages", frameworks = {"MessageUI", "Messages", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "MetricKitBackports", folder = "MetricKit", frameworks = {"MetricKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SensorKitBackports", folder = "SensorKit", frameworks = {"SensorKit", "CoreMedia", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "SecurityUIBackports", folder = "SecurityUI", frameworks = {"SecurityUI", "Security", "UIKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "UserNotificationsUIBackports", folder = "UserNotificationsUI", frameworks = {"UserNotificationsUI", "UserNotifications", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "NotificationCenterBackports", folder = "NotificationCenter", frameworks = {"NotificationCenter", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "AVKitBackports", folder = "AVKit", frameworks = {"UIKit", "AVFoundation", "CoreMedia", "CoreVideo", "CoreImage", "MediaPlayer", "QuartzCore", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}},
    {name = "MapKitBackports", folder = "MapKit", frameworks = {"MapKit", "UIKit", "CoreGraphics", "CoreLocation", "QuartzCore", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "PassKitBackports", folder = "PassKit", frameworks = {"PassKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreMediaBackports", folder = "CoreMedia", frameworks = {"CoreMedia", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreFoundationBackports", folder = "CoreFoundation", frameworks = {"CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "StoreKitBackports", folder = "StoreKit", frameworks = {"StoreKit", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreGraphicsBackports", folder = "CoreGraphics", frameworks = {"CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "AddressBookUIBackports", folder = "AddressBookUI", frameworks = {"AddressBookUI", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "CoreVideoBackports", folder = "CoreVideo", frameworks = {"CoreVideo", "Foundation"}, libraries = {"FoundationBackports"}},
    -- CoreMotion's activity classes arrived in iOS 7 and the device has no motion coprocessor to measure them, so the library
    -- carries the classes and answers as the host answers on hardware without one. CoreMotion itself is the release's own.
    {name = "CoreMotionBackports", folder = "CoreMotion", frameworks = {"CoreMotion", "Foundation"}, libraries = {"FoundationBackports"}},
    -- ReplayKit arrived in iOS 9 and its broadcast family in iOS 10, and the release has no ReplayKit framework. The library
    -- carries the broadcast classes and the NSExtensionContext category an extension calls, and answers as the host answers. It
    -- carries the screen recorder's state and its not-recording answers too, as a device that cannot record (available NO).
    {name = "ReplayKitBackports", folder = "ReplayKit", frameworks = {"UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    -- Speech arrived in iOS 10 and the release has no framework. The request, result, transcription and segment classes are
    -- carried; no recognizer runs on this device, so the recognizer answers as a machine on which speech is not available.
    {name = "SpeechBackports", folder = "Speech", frameworks = {"Speech", "AVFoundation", "Foundation"}, libraries = {"AVFoundationBackports", "FoundationBackports"}},
    {name = "CarPlayBackports", folder = "CarPlay", frameworks = {"CarPlay", "MapKit", "UIKit", "CoreGraphics", "CoreTelephony", "Foundation"}, libraries = {"FoundationBackports"}},
    -- FileProvider arrived in iOS 11.0 and the release has none of it: no framework, and no
    -- extension host to load a provider. The manager, the domain and the requests are the port's
    -- own and answer as a machine with no domains answers, measured on the host and written in the
    -- library's facts.
    {name = "FileProviderBackports", folder = "FileProvider", frameworks = {"FileProvider", "Foundation"}, libraries = {"FoundationBackports"}},
    -- Network.framework does not exist on the releases this port covers, so this library is the only place its
    -- connection surface can be, and it reports the path through the Foundation library's path monitor.
    {name = "NetworkBackports", folder = "Network", frameworks = {"Network", "Foundation", "Security"}, libraries = {"FoundationBackports"}},
    -- Intents arrives with iOS 8 and the armv7 ladder ends at 10.3.4, so no release this package
    -- covers carries it: every band builds this library whole. It links UIKit because an Intents
    -- image is the application's own image and UIKit is where the asset catalogue is on every
    -- release below, and CoreLocation because INPlacemarkResolutionResult resolves a CLPlacemark.
    -- It also links UIKitBackports: +[INImage systemImageNamed:] answers through +[UIImage systemImageNamed:], the one
    -- symbol table of the UIKit band, so the two cannot disagree. UIKitBackports depends on neither Intents library.
    -- It links EventKit for INDateComponentsRange's recurrence rule: EventKitBackports does not exist, and EventKit is on
    -- every release this package covers (iOS 4 on), so the library names the system's own framework.
    {name = "IntentsBackports", folder = "Intents", frameworks = {"Intents", "UIKit", "CoreLocation", "EventKit", "Foundation"}, libraries = {"FoundationBackports", "UIKitBackports"}, archives = {"charon-coding"}, c_archives = {"charon-coding"}},
    -- IntentsUI is the button and the two controllers an application shows to add or edit a
    -- shortcut, so it is a library of its own: a port that only donates interactions never draws
    -- one, and a daemon has no UIKit in its process to begin with. It needs the Intents classes
    -- the controllers hold, and it draws with UIKit.
    -- Accessibility arrived with iOS 3, so the release already has libAccessibility.dylib and its
    -- C API; what it does not have is the Objective-C classes the SDK of 26.2 declares on top of
    -- it, and this library is those. The release carries none of the 30 (measured against the
    -- 6.1.3 armv7 cache, with a control), so every band builds it whole and nothing in it is a
    -- class of its own that the release would answer.
    {name = "AccessibilityBackports", folder = "Accessibility", frameworks = {"Accessibility", "Foundation", "CoreGraphics"}, libraries = {"FoundationBackports"}, archives = {"charon-coding"}, c_archives = {"charon-coding"}},
    {name = "IntentsUIBackports", folder = "IntentsUI", frameworks = {"IntentsUI", "Intents", "UIKit", "Foundation", "CoreGraphics"}, libraries = {"FoundationBackports", "IntentsBackports"}},
    {name = "ARKitBackports", folder = "ARKit", frameworks = {"ARKit", "AVFoundation", "CoreMotion", "CoreLocation", "CoreMedia", "CoreVideo", "CoreGraphics", "ImageIO", "QuartzCore", "OpenGLES", "UIKit", "Foundation"}, libraries = {"FoundationBackports", "AVFoundationBackports", "SceneKitBackports"}},
    {name = "HealthKitBackports", folder = "HealthKit", frameworks = {"UIKit", "Foundation"}, libraries = {"FoundationBackports"}, system = {"sqlite3"}},
    {name = "MLComputeBackports", folder = "MLCompute", frameworks = {"Accelerate", "Foundation"}, libraries = {"FoundationBackports", "AccelerateBackports"}, archives = {"ggml"}},
    -- VideoToolbox arrived with iOS 3 and the armv7 ladder ends at 10.3.4, so every release this
    -- package covers has libVideoToolbox.dylib and its C API; what it does not have is the
    -- seventeen VTFrameProcessor classes 26.2 added on top of it. This library is those classes
    -- and nothing else - it adds no C entry point and holds no .mm object, so it needs no
    -- archive.
    {name = "VideoToolboxBackports", folder = "VideoToolbox", frameworks = {"VideoToolbox", "CoreMedia", "CoreVideo", "CoreFoundation", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "ModelIOBackports", folder = "ModelIO", frameworks = {"ModelIO", "CoreGraphics", "ImageIO", "MobileCoreServices", "Foundation"}, libraries = {"FoundationBackports", "MetalKitBackports"}},
    {name = "GameplayKitBackports", folder = "GameplayKit", frameworks = {"Foundation"}, libraries = {"FoundationBackports"}},
    -- UIKit because two of PDFKit's own classes need it and there is no Foundation class for either:
    -- PDFAppearanceCharacteristics' two colour members are UIColor and PDFAnnotation's three colours and
    -- its font are UIColor and UIFont, which is what the 26.2 header calls PDFKitPlatformColor and
    -- PDFKitPlatformFont.  Both are iOS 2.0, and Apple's own PDFKit on iOS is a UIKit framework - its
    -- PDFView is a UIView - so this is the dependency the port's own header already implies.
    {name = "PDFKitBackports", folder = "PDFKit", frameworks = {"PDFKit", "UIKit", "CoreGraphics", "Foundation"}, libraries = {"FoundationBackports"}},
    {name = "NetworkExtensionBackports", folder = "NetworkExtension", frameworks = {"NetworkExtension", "Foundation", "SystemConfiguration"}, libraries = {"FoundationBackports"}},
}
PACKAGE = "org.charon.apple-backports"
INSTALL_FOLDER = "/usr/lib/charon/" .. PACKAGE
COMPATIBLE = {armv7 = {"armv7", "armv7s"}, armv7s = {"armv7s"}, arm64 = {"arm64"}}
-- What every link here that writes a library or a bundle says about encryption, and why it is said
-- to the linker rather than to anything after it.
--
-- ld64 makes a dynamic library and a dynamic bundle *encryptable* from iOS 7.0 on: in
-- ld64/src/ld/Options.cpp, kDynamicLibrary and kDynamicBundle clear fEncryptable only when the
-- platform's minimum release is older than version2013 (iOS 7.0), with rdar://16293398 next to it -
-- "Add LC_ENCRYPTION_INFO load command to bundled frameworks". A dynamic executable keeps it at every
-- release, which is the FairPlay header an application is built with and which modules/apple/macho.lua
-- leaves alone. What the command carries is cryptid 0, and ld64 sets no MH_CRYPT in the header for it.
--
-- Measured with this machine's own toolchain (llvm 23.1.1's clang, the ld64 956.6 package, the 16.4
-- SDK), one trivial armv7 dylib per release: no command at 6.0, 6.1.3 and below, one at 7.0, 8.0,
-- 8.4.1, 9.0, 9.3, 10.0.1 and 10.3.4, with either clang as the driver. So it is the minimum on the
-- link line that decides it, and every band of one install is linked at that install's own minimum -
-- stage_bands() hands link() the opt it was given, and only the band contents differ - which is why
-- the 6.1.3 and 4.3 installs carry the command in 0 of their dylibs and an install configured at 8.4.1
-- or later carries it in every one, and why macho.lua's refusal then fires on a target carrying a
-- band library (verify_placed) and never on a 6.x install.
--
-- -no_encryption is ld64's own negation of that default (Options.cpp parses it into
-- fEncryptableForceOff), so the linker is told the output is not to be encrypted. Nothing is stripped
-- afterwards, and the tree's check keeps its invariant.
NOT_ENCRYPTED = "-Wl,-no_encryption"

function libraries()
    return LIBRARIES
end

-- Whether this run keeps a library. A caller that names the libraries it links - a package install,
-- where the configs decide what the process needs - keeps those and nothing else; a caller that
-- names none (coordination/build-gate.lua, which links every library) keeps all of them.
--
-- Every step of a run reads this and not its own idea of the answer, because a step that keeps a
-- library another one dropped pays for an object nothing reads, and needs the include directory of
-- an archive the run does not link. Measured on the install of an unmodified package with every
-- config at its default: 1620 objects for 69 libraries (UIKit 532, Foundation 249, one HomeKit
-- object), none of them linked, because the run died on HomeKit's second source with
-- "'monocypher/monocypher.h' file not found" - HomeKit's config was off, so nothing was to link
-- that object, and the recipe's own archive table named no monocypher.
local function keeps(opt, name)
    return not opt.libraries or table.contains(opt.libraries, name)
end

local function staged_libraries(opt)
    local staged = {}
    for _, library in ipairs(LIBRARIES) do
        if keeps(opt, library.name) then
            table.insert(staged, library)
        end
    end
    return staged
end

function package_name()
    return PACKAGE
end

function compatible(architecture)
    return COMPATIBLE[architecture] or {architecture}
end

function held_cache(architecture, release)
    for _, candidate in ipairs(compatible(architecture)) do
        local held = dyld.held_source(path.join(dyld.root(), release), candidate)
        if held then
            return held
        end
    end
end

-- A backport holds more than the API it carries: Charon's own helpers, the
-- classes it invents for itself and the ivars of the classes it implements.
-- None of that is API - a release that already has a class exports its own
-- ivars, not these - so it is neither weighed against a release nor exported.
-- The store key of each object this process placed or compiled (object_key), and the symbols read
-- out of those objects, by key.
local KEYS, SYMBOLS = {}, {}

local function internal_symbol(name)
    -- A protocol object is internal, for the reason tools/release-split.lua gives in its own EXCLUDED
    -- table: a program reaches a protocol by NAME, through objc_getProtocol, and links no symbol to
    -- reach one, so the object is metadata rather than an API a caller can bind to. Apple's own
    -- frameworks keep theirs local for the same reason.
    --
    -- It is NOT internal because the registry check would read an exported one as a symbol with no
    -- entry. check_registry has exempted exactly this prefix since before this rule existed
    -- (protocol_metadata, c4f6fcdb7:1806), so that was never what turned anything red.
    --
    -- What this rule does is stop exported_symbols() from counting a protocol object towards a
    -- release, and it must not be the reason a second definition of one goes unseen. The gate for
    -- that is in tests/addon/registry_test.lua: a library's own sources may not DECLARE a protocol
    -- that has an implemented protocol row, because the generated <Library>Protocols<release>.m
    -- emits that protocol's object too, and two definitions of one protocol that disagree are
    -- resolved by ld64 silently, in link order.
    if name:startswith("_OBJC_IVAR_$_") or name:startswith("_OBJC_PROTOCOL_$_") or name:find("$shim", 1, true) then
        return true
    end
    local bare = name:match("^_OBJC_%u*CLASS_%$_(.+)$") or name:match("^_(.+)$") or name
    return bare:startswith("charon_") or bare:startswith("Charon")
end

local function symbols_where(file, wanted, kind)
    -- an object of the store never changes under its key, and a gate reads each one's symbols three
    -- times over (minimums, the release check, the link)
    local memo = kind and KEYS[file] and (KEYS[file] .. kind)
    if memo and SYMBOLS[memo] then
        return SYMBOLS[memo]
    end
    local found = symbols_of(file, wanted)
    if memo then
        SYMBOLS[memo] = found
    end
    return found
end

function symbols_of(file, wanted)
    local data = macho.read(file)
    local found = {}
    for _, image in ipairs(macho.images(data)) do
        if image.symtab then
            local symoff, nsyms, stroff = image.symtab[1], image.symtab[2], image.symtab[3]
            local entry = image.wide and 16 or 12
            for index = 0, nsyms - 1 do
                local strx, kind, _, _, value = string.unpack(image.wide and "<I4BBI2I8" or "<I4BBI2I4", data, image.base + symoff + index * entry + 1)
                if wanted(kind, value) then
                    local finish = data:find("\0", image.base + stroff + strx + 1, true)
                    found[data:sub(image.base + stroff + strx + 1, finish - 1)] = true
                end
            end
        end
    end
    return table.orderkeys(found)
end

local function defined_symbols(file, hidden)
    return symbols_where(file, function (kind)
        return kind & 0xE0 == 0 and kind & 0x0E == 0x0E and (hidden or (kind & 0x10 == 0 and kind & 0x01 ~= 0))
    end, hidden and "hidden" or "defined")
end

-- What an object needs another file to define (nm -u): external, undefined, and not a common symbol,
-- which an object defines itself.
local function undefined_symbols(file)
    return symbols_where(file, function (kind, value)
        return kind & 0xE0 == 0 and kind & 0x0E == 0 and kind & 0x01 ~= 0 and value == 0
    end, "undefined")
end

local function exported_symbols(file)
    local found = {}
    for _, symbol in ipairs(defined_symbols(file)) do
        if not internal_symbol(symbol) then
            table.insert(found, symbol)
        end
    end
    return found
end

-- A seam is a charon_ function one library of the package defines for another to link against: the
-- Swift Network module reads the interface a zone names through one. internal_symbol() keeps it out of
-- the surface and the registry check, as it keeps every charon_ name, so it needs no registry row; but
-- link() hides every internal name from the dylib, and a seam must stay exported. The declaration says
-- so: CHARON_SEAM first on a line of its own, before the return type, which the header and the definition
-- both carry. A #define of the macro and a comment that names it do not start a line with it, so neither
-- is read. The names come back as "_name", the form defined_symbols() gives, so link() can tell a seam
-- from the rest of the internal names.
function seam_symbols(root, library)
    local found = {}
    -- root is the apple-backports folder, which is opt.root in a build (coordination/build-gate.lua hands it over)
    local folder = path.join(root, library.folder)
    for _, file in ipairs(os.files(path.join(folder, "*"))) do
        if file:endswith(".h") or file:endswith(".m") or file:endswith(".mm") or file:endswith(".c") then
            for line in io.lines(file) do
                local rest = line:match("^%s*CHARON_SEAM(.*)")
                local name = rest and rest:match("([%a_][%w_]*)%s*%(")
                if name then
                    found["_" .. name] = true
                end
            end
        end
    end
    return found
end

-- The clang driver a build runs: the one it was given, or the host's.
-- The archive a name in a library's list refers to.
--
-- The name in a library's list is the **alias** it was written with ("charon-coding"), and the
-- table the build is handed is keyed by the **package** the resolve turned that alias into
-- ("charon@charon-coding 1.0.0"), because that is what the caller that resolves packages can
-- know. So the lookup tries the alias first and the package form second - which is what the
-- `charon@` branch was there for, and it had no caller until compile() started needing the
-- include directory of an archive whose API is C (measured: with the alias-only lookup the header
-- is not found and the Accessibility library does not compile). The recipe's own `common` table
-- keys by the alias, so both spellings occur, and this is where they are joined.
function archive_of(archives, name)
    if not archives then
        return nil
    end
    if archives[name] then
        return archives[name]
    end
    for key, archive in pairs(archives) do
        if (key:match("^(%S+)") or key) == "charon@" .. name then
            return archive
        end
    end
    return nil
end

local function driver(opt, arguments)
    if opt.cc then
        return opt.cc, arguments
    end
    return "xcrun", table.join({"clang"}, arguments)
end

-- What a compile runs through is apple.cache: the backports build runs a compiler thousands of
-- times, and a second copy of "find ccache on the path" is a second thing to keep right. What the
-- cache is and what it was measured to do is written there.
local function clang(opt, arguments, objective_c)
    local given = {"-target", opt.triple, "-isysroot", opt.sdkdir}
    if objective_c then
        table.insert(given, "-fobjc-arc")
        if dyld.compare_versions(opt.deployment, "5.0") < 0 then
            table.join2(given, {"-Xclang", "-fobjc-runtime-has-weak"})
        end
    end
    table.join2(given, arguments)
    return driver(opt, given)
end

-- The object store (opt.store): an object kept under a key of everything its compile reads that can
-- change, so that a build hands back an object it already has without starting a process. A ccache
-- hit is not that: it is a process, which hashes the preprocessor's inputs, stats every SDK header
-- it read and copies the object out - measured 30-60 ms a unit under the fleet's load, 2331 units a
-- gate at four cores, which was the whole of the 21-29 s every gate spent "compiling" a tree nothing
-- in had changed. The key is the compiler, its arguments with the checkout's own path taken out (as
-- ccache's base_dir takes it out, so every worktree shares one entry), the source, and every header
-- of the checkout the source reaches through #include/#import, by content. Headers outside the
-- checkout - the SDK, the compiler's own, an archive's include folder - sit under installdirs whose
-- names are the hash of what they hold, and are in the key through the paths in the arguments.
-- A directive the scan cannot read (a macro in place of a name) leaves the unit out of the store,
-- compiled every time as before. Reading a directive in a block the preprocessor skips only adds a
-- header to the key, which costs a rebuild and never a stale object.
local SCANNED, CONTENT = {}, {}

local function directives(file)
    local found = SCANNED[file]
    if found == nil then
        found = {}
        for line in io.readfile(file):gmatch("[^\n]+") do
            local rest = line:match("^%s*#%s*include_next(.*)$") or line:match("^%s*#%s*include(.*)$") or line:match("^%s*#%s*import(.*)$")
            if rest then
                local open, name = rest:match('^%s*(["<])([^">]+)[">]')
                if not open then
                    found = false
                    break
                end
                table.insert(found, {quoted = open == '"', name = name})
            end
        end
        SCANNED[file] = found
    end
    return found
end

local function content(file)
    CONTENT[file] = CONTENT[file] or hash.strhash128(io.readfile(file))
    return CONTENT[file]
end

-- Every header of the checkout the source reaches, in the order first reached, or nil when a
-- directive on the way cannot be read. A quoted name is looked for beside the file that names it and
-- then in the -I folders, an angled one in the -I folders, as clang looks; every folder that holds
-- the name counts, not only the first, so a header shadowed by another is still in the key.
local function reached(source, folders)
    local seen, order = {}, {}
    local function visit(file)
        local found = directives(file)
        if not found then
            return false
        end
        for _, include in ipairs(found) do
            local candidates = include.quoted and {path.directory(file)} or {}
            table.join2(candidates, folders)
            for _, folder in ipairs(candidates) do
                local header = path.normalize(path.join(folder, include.name))
                if not seen[header] and os.isfile(header) then
                    seen[header] = true
                    table.insert(order, header)
                    if visit(header) == false then
                        return false
                    end
                end
            end
        end
        return true
    end
    if visit(source) == false then
        return nil
    end
    return order
end

local OWN_TEXT

-- This file's text, by content: what a measurement or a link kept in the store was computed by.
local function own_text()
    OWN_TEXT = OWN_TEXT or hash.strhash128(io.readfile(path.join(os.scriptdir(), "backports.lua")))
    return OWN_TEXT
end

-- What the compiler and the linker read from the environment besides their arguments: the include
-- paths clang takes from the environment and the SDK and deployment the driver falls back on. A key
-- without them hands back what a different environment built (measured: a header found only on
-- CPATH, changed between two runs, and the second run took the first run's object).
local ENVIRONMENT = {"CPATH", "C_INCLUDE_PATH", "OBJC_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJCPLUS_INCLUDE_PATH",
                     "SDKROOT", "DEVELOPER_DIR", "IPHONEOS_DEPLOYMENT_TARGET", "MACOSX_DEPLOYMENT_TARGET",
                     "CCC_OVERRIDE_OPTIONS", "LIBRARY_PATH", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"}
local function environment()
    local parts = {}
    for _, name in ipairs(ENVIRONMENT) do
        local value = os.getenv(name)
        if value then
            table.insert(parts, name .. "=" .. value)
        end
    end
    return table.concat(parts, "\n")
end

function object_key(opt, program, arguments, source, object)
    if not opt.store or not opt.root then
        return nil
    end
    local checkout = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))
    local function portable(text)
        local at = text:find(checkout, 1, true)
        return at and text:sub(1, at - 1) .. "@checkout" .. portable(text:sub(at + #checkout)) or text
    end
    local folders = {}
    for index, argument in ipairs(arguments) do
        local folder = argument:match("^%-I(.+)$") or (argument == "-I" and arguments[index + 1])
        if folder then
            folder = path.normalize(path.absolute(folder))
            if folder:startswith(checkout) then
                table.insert(folders, folder)
            end
        end
    end
    local headers = reached(source, folders)
    if not headers then
        return nil
    end
    -- The arguments are the whole of what this file asks of the compiler, so its own text is not here:
    -- an edit that changes a compile changes its arguments.
    local parts = {"charon-object-2", program, environment()}
    for _, argument in ipairs(arguments) do
        table.insert(parts, argument == object and "@object" or portable(argument))
    end
    table.insert(parts, content(source))
    for _, header in ipairs(headers) do
        table.insert(parts, portable(header) .. "=" .. content(header))
    end
    return hash.strhash128(table.concat(parts, "\n"))
end

-- Only C is compiled hidden. The classes of a backport are the API it carries,
-- and the headers of the release declare a Foundation class without the
-- visibility UIKit gives its own, so -fvisibility=hidden makes clang hide every
-- Foundation class it implements: the library exports nothing, a port links its
-- classes as the weak imports that are NULL on the release, and the device says
-- only that the program failed. What the library must not export it hides at
-- the link, where a hidden symbol can still be named.
--
-- Objective-C++ is how a backport reaches a C++ library it links in (LIBRARIES' archives). The
-- archives are built without RTTI, so a class derived here from one of theirs has none either, and
-- the inline functions of their headers stay hidden, as the archives' own symbols are. Every .mm
-- backport is compiled so: one that needs RTTI for another reason (typeid, dynamic_cast) cannot
-- have it here.
-- The flags one source is compiled with. A job may add include roots of its own: a source this build
-- generated sits in the build directory, and its quoted import reaches a header of the tree only when the
-- tree is on the path.
local function unit(opt, source, object)
    -- The source, absolute, and relative to this package rather than to wherever xmake happens to
    -- be: path.absolute() on its own resolves a relative source against the working directory,
    -- which inside package:on_install is xmake's own and not the checkout, so a caller that passed
    -- "UIKit/Foo.mm" would be looked for under xmake's directory. Every caller here already passes
    -- path.join(opt.root, ...), so this is the identity for all of them; it is here for the next one.
    if not source:startswith("/") then
        source = path.join(opt.root, source)
    end
    -- This does NOT close the one-object residue, and nothing a caller passes can. ccache rewrites
    -- the compiler's own -c argument when base_dir is set - heavy.sh sets it in the cache's
    -- ccache.conf - and hands the object back as that run wrote it, so a cached build records the
    -- relative spelling whatever the caller passed and an uncached one the absolute. Measured the
    -- same file three ways straight through ccache, so nothing else was in the way: no cache and
    -- ccache with base_dir unset are byte for byte the same and both record the absolute path;
    -- only base_dir set gives the relative one. That rewrite is the price of the cross-worktree
    -- sharing hash_dir = false buys, and -ffile-prefix-map, which rules/apple-ios already applies
    -- to this repository's own targets, is the follow-up that would collapse both spellings -
    -- measured, and it does not: the map rewrites an absolute spelling and ccache hands the
    -- compiler a relative one, so the gap falls from 84 bytes to 8 and stops
    -- (band-api-prefixmap, d2e15520). What the two lines above close is the other half: a caller
    -- that spelled the source two ways would be two objects under one key, and that is no longer
    -- possible.
    local objective_c = not source:endswith(".c")
    local arguments = {"-Os", "-g0", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability"}
    if objective_c then
        table.insert(arguments, "-Werror=objc-missing-property-synthesis")
    else
        table.insert(arguments, "-fvisibility=hidden")
    end
    if source:endswith(".mm") then
        table.join2(arguments, {"-fno-rtti", "-fvisibility-inlines-hidden"})
    end
    -- Every archive's headers, for every file. A C archive is used by C files, so its headers
    -- cannot wait for a .mm; and a C++ archive's headers are reached from a plain .m too, because
    -- a header of ours can include one of them - measured at UIKit's CharonDynamics.h:15, which
    -- includes <Box2D/Box2D.h> and is included from a .m, so the narrowing to .mm that a review
    -- asked for breaks the 4.3 gate with "Box2D/Box2D.h file not found".
    --
    -- The width that costs is real and is the reason it is written this way: every library's
    -- sources compile with every archive's include directory on the path. That is a few -I flags a
    -- search walks over, and the alternative measured is a build that does not compile.
    for _, name in ipairs(table.orderkeys(opt.archives or {})) do
        table.insert(arguments, "-I" .. opt.archives[name].includedir)
    end
    -- __FILE__ spelled from the checkout, not with it: an object that names its own source (UIDynamicAnimator.mm's
    -- assertion handler) otherwise carries the path of the worktree that built it, which the store's key leaves out on
    -- purpose so every worktree shares one entry - measured, two worktrees, one key, two objects differing in that path.
    if opt.root then
        local checkout = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))
        table.insert(arguments, "-fmacro-prefix-map=" .. checkout .. "/=")
    end
    local program, arguments = clang(opt, table.join(arguments, {"-c", source, "-o", object}), objective_c)
    local key = object_key(opt, program, arguments, source, object)
    KEYS[object] = key
    return program, arguments, key and path.join(opt.store, key:sub(1, 2), key .. ".o")
end

local function store_folder(folder)
    try { function () os.mkdir(folder) end }
    assert(os.isdir(folder), "cannot create the store folder " .. folder)
end

local function place(object, stored)
    -- Removed first either way: the object may be a link into the store from an earlier run, and a
    -- compile must not write through it.
    os.tryrm(object)
    if stored and os.isfile(stored) then
        os.ln(stored, object)
        -- the store is swept by age (sweep_store), and an entry a build still takes is not old
        os.touch(stored)
        return true
    end
    return false
end

function compile_arguments(opt, source)
    local objective_c = not source:endswith(".c")
    local arguments = {"-Os", "-g0", "-Wall", "-Wno-unguarded-availability-new", "-Wno-unguarded-availability"}
    for _, folder in ipairs(opt.includes or {}) do
        table.insert(arguments, "-I" .. folder)
    end
    -- A library folder's own sources and its generated protocol sources import Charon<Folder>Protocols.h, which tools/gen writes into
    -- .gen/<Folder>/ (render.lua), so both the folder and its .gen folder are on the path of a source that lives in either.
    if opt.root then
        local folder = path.filename(path.directory(source))
        for _, dir in ipairs({path.join(opt.root, ".gen", folder), path.join(opt.root, folder)}) do
            if os.isdir(dir) then
                table.insert(arguments, "-I" .. dir)
            end
        end
    end
    if objective_c then
        table.insert(arguments, "-Werror=objc-missing-property-synthesis")
    else
        table.insert(arguments, "-fvisibility=hidden")
    end
    if source:endswith(".mm") then
        table.join2(arguments, {"-fno-rtti", "-fvisibility-inlines-hidden"})
    end
    -- Every archive's headers, for every file. A C archive is used by C files, so its headers
    -- cannot wait for a .mm; and a C++ archive's headers are reached from a plain .m too, because
    -- a header of ours can include one of them - measured at UIKit's CharonDynamics.h:15, which
    -- includes <Box2D/Box2D.h> and is included from a .m, so the narrowing to .mm that a review
    -- asked for breaks the 4.3 gate with "Box2D/Box2D.h file not found".
    --
    -- The width that costs is real and is the reason it is written this way: every library's
    -- sources compile with every archive's include directory on the path. That is a few -I flags a
    -- search walks over, and the alternative measured is a build that does not compile.
    for _, name in ipairs(table.orderkeys(opt.archives or {})) do
        table.insert(arguments, "-I" .. opt.archives[name].includedir)
    end
    -- __FILE__ spelled from the checkout, not with it: an object that names its own source (UIDynamicAnimator.mm's
    -- assertion handler) otherwise carries the path of the worktree that built it, which the store's key leaves out on
    -- purpose so every worktree shares one entry - measured, two worktrees, one key, two objects differing in that path.
    if opt.root then
        local checkout = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))
        table.insert(arguments, "-fmacro-prefix-map=" .. checkout .. "/=")
    end
    return arguments, objective_c
end

function compile(opt, source, object)
    local flags, objective_c = compile_arguments(opt, source)
    local program, arguments = clang(opt, table.join(flags, {"-c", source, "-o", object}), objective_c)
    -- Through the cache, which is apple.cache: it puts the compiler in as the wrapper's first
    -- argument, because os.execv runs a name it cannot execute itself by splitting that name on
    -- spaces, and a checkout under a path with a space in it has to survive that. The link below
    -- goes through driver() and no cache: a cache holds compilations, not links.
    -- From the checkout: ccache (base_dir) hands the compiler every path under the tree relative to where it runs, and
    -- __FILE__ is then spelled from there - from the shared checkout it named the worktree (".agent-work/worktrees/<name>/
    -- packages/..."), which the store's key leaves out; from the checkout itself it is "packages/..." in every worktree.
    local program, argv = cache.wrapped(program, arguments)
    os.vrunv(program, argv, opt.root and {curdir = path.normalize(path.join(path.absolute(opt.root), "..", "..", ".."))} or nil)
    if stored then
        store_folder(path.directory(stored))
        local temporary = stored .. "." .. hash.strhash32(object .. os.mclock()) .. ".tmp"
        os.cp(object, temporary)
        os.mv(temporary, stored)
    end
    return true
end

-- The entries of the store no build has taken for older than seconds, removed: an entry is touched
-- each time a build takes it, so what goes is what no tree still builds. At most once an hour, since
-- a gate is every few minutes and a walk of the store is not free.
function sweep_store(store, seconds)
    -- The store comes from the environment (CHARON_OBJECT_STORE), and a stale value can name any
    -- folder: only what this file writes is removed, an object, a link, a measurement or an
    -- inventory named by its key (or the temporary of one a killed build left), in the four places
    -- it writes them, and nothing else under store is ever looked at.
    local KEY = string.rep("%x", 32)
    local kinds = {
        {"*", "*.o", "^" .. KEY .. "%.o"},
        {"links/*", "*.dylib", "^" .. KEY .. "%.dylib"},
        {"releases/*", "*.lua", "^" .. KEY .. "%.lua"},
        {"inventories", "*.lua", "^" .. KEY .. "%.lua"}}
    local mark = path.join(store, "swept")
    if not os.isdir(store) or (os.isfile(mark) and os.time() - os.mtime(mark) < 3600) then
        return
    end
    io.writefile(mark, "")
    local now, removed = os.time(), 0
    for _, kind in ipairs(kinds) do
        for _, file in ipairs(os.files(path.join(store, kind[1], kind[2] .. "*"))) do
            local name = path.filename(file)
            if name:match(kind[3] .. "$") or name:match(kind[3] .. "%.%x+%.tmp$") then
                if now - os.mtime(file) > seconds then
                    os.tryrm(file)
                    removed = removed + 1
                end
            end
        end
    end
    return removed
end

-- How many units this build may compile at once. The caller may lower it, and heavy.sh raises it
-- for the builds that are not already inside a job: a gate, release-split, the canon build, all of
-- which run from `xmake lua` as the only coroutine of their own.
--
-- One at a time it is, whatever the caller asked for, as soon as xmake is already running a job of
-- its own in this process - a package's on_install, and write_deb() called from it. A job runner
-- started from inside one never returns: measured, every object is written and the run then hangs
-- there for good, on a shared scheduler and on an isolated one alike. The test for that is here and
-- not on a call site, because there are two entries into compiled() from a package install and the
-- next caller would not remember: scheduler.co_count() is 1 for a script's own top level and 2
-- inside a job, so anything above 1 means a job is already driving this process.
local function width(opt)
    if scheduler.co_count() > 1 then
        return 1
    end
    if opt.width then
        return opt.width
    end
    return math.max(1, tonumber(os.getenv("FLEET_HEAVY_CPUS") or "") or 1)
end

-- The units the compiler has actually been run on since the counter was last read. A placed object
-- is not one of these: a unit the cache hands back is an object the build holds and a compile it
-- did not do, and the line build() prints has to say which of the two it is reporting.
local COMPILED

-- The units of a build, compiled. A backport unit is independent of every other one: what it
-- compiles is decided before any of them run, and the objects are only read afterwards, by the
-- link and by the checks that read symbols out of them. So they are handed to the same job runner
-- xmake builds its own targets with, which is what makes the count above a bound rather than a
-- hope - and which re-raises what a unit printed, so a unit that does not compile still fails the
-- build exactly as it did one at a time. Only the compiles run in parallel: the order the objects
-- are numbered in, which the link reads them in, is built before this and never touched here.
local function compile_all(opt, jobs)
    local count = width(opt)
    -- What the store already holds is placed here, in this coroutine, with no process started: only
    -- the rest is handed to the job runner.
    local missing = {}
    for _, job in ipairs(jobs) do
        local _, _, stored = unit(job.opt, job.source, job.object)
        if not place(job.object, stored) then
            table.insert(missing, job)
        end
    end
    COMPILED = COMPILED or 0
    if count <= 1 or #missing < 2 then
        for _, job in ipairs(missing) do
            if compile(job.opt, job.source, job.object, job.library) then
                COMPILED = COMPILED + 1
            end
        end
        return
    end
    import("async.runjobs")("backports", function (index)
        local job = missing[index]
        if compile(job.opt, job.source, job.object, job.library) then
            COMPILED = COMPILED + 1
        end
    end, {comax = count, total = #missing})
end

local function sections_of(file)
    local names = {}
    for _, image in ipairs(macho.images(macho.read(file))) do
        for _, section in ipairs(image.sections) do
            names[section.segment .. "," .. section.name] = true
        end
    end
    return names
end

-- The generated layer (tools/gen.lua, run under xmake) is built, not committed. The snapshot it reads is committed under spec/;
-- the generator writes its output into .gen/ (gitignored) before anything reads that folder, so a clean checkout needs no manual step.
-- The generator is run once per process and per package root. build() is the one caller that runs it: registry() and sources() read
-- .gen/ as it is on disk, so a test that reads a fixture root never runs the generator. A root with no spec/ snapshot is an error here.
local generated = {}
function generate(root)
    local snapshot = path.join(root, "spec")
    if not os.isdir(snapshot) then
        raise("package root %s has no spec/ snapshot (%s): the generated layer in .gen/ cannot be written", root, snapshot)
    end
    if generated[root] then
        return
    end
    generated[root] = true
    local tree = path.absolute(path.join(root, "..", "..", ".."))
    -- gen names the corpus and the spec snapshot by the release of an SDK it is given (dcf205864d made --sdk required): the iPhoneOS SDK
    -- of the snapshot's release, which is CHARON_GEN_SDK
    local sdk = os.getenv("CHARON_GEN_SDK")
    if not sdk or sdk == "" then
        raise("the generated layer needs CHARON_GEN_SDK: the iPhoneOS SDK whose release the spec snapshot is measured on (gen --sdk)")
    end
    os.runv(os.programfile(), {"l", path.join(tree, "tools", "gen.lua"), "gen", "--tree", tree, "--all", "--sdk", sdk})
    -- the Intents class objects (IN<group>.m) are built into .gen/Intents from the same SDK, by their own generator (tools/intents/objects.lua),
    -- and are not committed; a root with no Intents folder has none to build
    if os.isdir(path.join(root, "Intents")) then
        os.runv(os.programfile(), {"l", path.join(tree, "tools", "intents", "objects.lua"), "--sdk", sdk,
            "--out", path.join(root, ".gen", "Intents"), "--work", path.join(tree, ".agent-work", "intents-generation")})
    end
end

function sources(root, library)
    -- .gen/<Framework>/ holds the generated contract layer: its sources are built with the library, and its rows are read from
    -- .gen/<Framework>/rows.tsv by registry() as implementations, so both folders are one library's. build() has run generate().
    local found = table.join(os.files(path.join(root, library.folder, "*.m")), os.files(path.join(root, library.folder, "*.mm")),
                             os.files(path.join(root, library.folder, "*.c")), os.files(path.join(root, ".gen", library.folder, "*.m")),
                             os.files(path.join(root, ".gen", library.folder, "*.c")))
    -- the objects a framework writes into its own .gen folder, for a library whose folder is not the framework's: the Graphics library
    -- builds ImageIO's and CoreImage's objects, which tools/gen writes into .gen/ImageIO (ImageIOMetadata7.m) and .gen/CoreImage (CIFilterBuiltins<tag>.m)
    for _, folder in ipairs(library.generated or {}) do
        found = table.join(found, os.files(path.join(root, ".gen", folder, "*.m")))
    end
    byteorder.sort(found)
    return found
end

-- The protocol metadata a framework carries, which the port does not: on Apple a framework's protocols are
-- in the framework, so NSProtocolFromString and -conformsToProtocol: work on a class an application never saw,
-- and the port emits a protocol's metadata only where a class adopts it. An implemented protocol row nothing
-- adopts is a row no build answers for, and check_registry holds it red (measured 2026-09-28: 73 such rows,
-- coordination/registry-gap-2026-09-28.tsv). So the build writes one object source per library per release
-- band - <Library>Protocols<release>.m - that names every protocol the band carries, which is what makes clang
-- emit __OBJC_PROTOCOL_$_<name> into the object. One file per band, so every symbol in it first appears in one
-- release and release-split has nothing to flag; one io.writefile per file, so no redirection can truncate it.
-- The protocols a folder's own objects emit the metadata object for, and which file emits each.
--
-- What makes clang emit __OBJC_PROTOCOL_$_<name> is a CONFORMANCE - an @interface or an @protocol whose
-- protocol list names it - and nothing else: importing the header that declares it, using id<name>, and
-- naming it in @protocol(name) all emit none of it. So the search is for a protocol list on a declaration
-- line and for nothing else, and each name is looked for inside such a list rather than in the file at
-- large, because a property of type id<name> or NSArray<name *> mentions the name in a line with no
-- declaration in it and would be a second, wrong answer.
--
-- The SDK's own headers are read as well as the folder's, and they have to be: the conformance that makes
-- CoreML's MLFeatureProvider.m emit __OBJC_PROTOCOL_$_MLFeatureProvider is in no source of this
-- repository. It is in Apple's MLFeatureProvider.h, where MLDictionaryFeatureProvider is declared as
-- conforming, and the port gets it by importing <CoreML/CoreML.h>. A search over this repository's sources
-- alone finds nothing there, which is what the first version of this did and why it changed nothing for the
-- framework it was written for.
local function conforms_in(text, wanted, found, filename)
    for declaration in text:gmatch("@interface%s+[%w_]+[^\n]*") do
        local list = declaration:match("<([^>]*)>%s*$") or declaration:match("<([^>]*)>")
        if list then
            for conformed in list:gmatch("[%w_]+") do
                if wanted[conformed] and not found[conformed] then found[conformed] = filename end
            end
        end
    end
    for declaration in text:gmatch("@protocol%s+[%w_]+[^\n]*") do
        local list = declaration:match("<([^>]*)>%s*$") or declaration:match("<([^>]*)>")
        if list then
            for conformed in list:gmatch("[%w_]+") do
                if wanted[conformed] and not found[conformed] then found[conformed] = filename end
            end
        end
    end
    return found
end

function conforming_protocols(opt, library, names, found)
    found = found or {}
    local wanted = {}
    for name in pairs(names) do wanted[name] = true end
    for _, file in ipairs(os.files(path.join(opt.root, library.folder, "*"))) do
        local filename = path.filename(file)
        if filename:endswith(".h") or filename:endswith(".m") or filename:endswith(".c") or filename:endswith(".mm") then
            local text = io.readfile(file)
            if text then conforms_in(text, wanted, found, library.folder .. "/" .. filename) end
        end
    end
    -- The frameworks' own headers, where a framework declares a class that conforms to one of its
    -- protocols: this repository's sources hold the conformance only when they declare the class themselves,
    -- and for the frameworks they do not, the header the port imports is where it is.
    if not opt.sdkdir then return found end
    for _, framework in ipairs(library.frameworks or {}) do
        for _, file in ipairs(os.files(path.join(opt.sdkdir, "System/Library/Frameworks", framework .. ".framework/Headers/*.h"))) do
            local text = io.readfile(file)
            if text then conforms_in(text, wanted, found, framework .. ".framework/Headers/" .. path.filename(file)) end
        end
    end
    return found
end

function protocol_sources(opt, library, folder, umbrella)
    -- Only this library's own rows: a framework's rows live under registry/<folder>/, so the library whose
    -- folder is that framework is the one that carries them, and a framework no library builds (PhotosUI, whose
    -- protocols ride in PhotosBackports) is not read into any library at all. Reading the whole registry put all
    -- 73 rows into every library.
    local root = opt.root
    local bands, floors_of = {}, {}
    for _, file in ipairs(table.join(os.files(path.join(root, "registry", library.folder, "*.json")),
                                 os.files(path.join(root, "registry", library.folder .. ".json")))) do
        local held = json.loadfile(file)
        if type(held) == "table" and held.entries == nil and #held == 0 then
            held = {entries = {}}
        end
        for _, entry in ipairs((held.entries or held)) do
            if entry.kind == "protocol" and entry.status == "implemented" then
                local introduced = entry.introduced or "0"
                bands[introduced] = bands[introduced] or {}
                table.insert(bands[introduced], entry.api)
                -- the file's floor is the highest minimum of its rows, as a source the registry places has
                if entry.minimum and (not floors_of[introduced] or dyld.compare_versions(entry.minimum, floors_of[introduced]) > 0) then
                    floors_of[introduced] = entry.minimum
                end
            end
        end
    end
    -- Which of them this library's own sources already carry, and where. A translation unit emits
    -- __OBJC_PROTOCOL_$_<name> when it CONFORMS to the protocol, not when it merely imports the header or
    -- uses id<name> or @protocol(name) - measured on this tree with three objects compiled for
    -- armv7-apple-ios6.0 against the SDK of iOS 16.4, each reading <CoreML/MLFeatureProvider.h> and nothing
    -- else, and each nm -g-ed: one that declares nothing that uses the protocol exports 0 of the symbol, one
    -- that uses id<name> and @protocol(name) exports 0, and one that declares
    -- @interface X : NSObject <name> exports 1 (facts/CoreML/CoreML.md, "Which translation units emit a
    -- protocol's metadata object").
    --
    -- Forcing the object here as well is what made two objects of one library define the same protocol, both
    -- weak private external, and ld64 keeps whichever comes first on the link line without a word. The two
    -- definitions were the same symbol and the same bytes, so nothing observable depended on the order -
    -- which is exactly why nothing caught it. A protocol one of the library's own sources conforms to is
    -- emitted there and is not forced here; one nothing conforms to is forced here, because nothing else
    -- would emit it and objc_getProtocol and conformsToProtocol: have to answer.
    local wanted = {}
    for _, names in pairs(bands) do
        for _, name in ipairs(names) do wanted[name] = true end
    end
    local carried = conforming_protocols(opt, library, wanted)
    local written, floor = {}, {}
    for introduced, names in pairs(bands) do
        byteorder.sort(names)
        local file = path.join(folder, library.name .. "Protocols" .. introduced .. ".m")
        local text = string.format([[// %sProtocols%s.m — written by modules/apple/backports.lua, not by hand.
// Every @protocol() below is named so clang emits __OBJC_PROTOCOL_$_<name> into this object, which is the
// metadata the release carries for that protocol in %s.framework itself. One file per release the rows
// arrived in, so every symbol here first appears in one release and release-split is clean.
// A protocol this library's own sources already emit is NOT named here, and the comment says which file
// emits it: naming it in both places is what two definers of one symbol meant.
#import "Charon%sProtocols.h"

static void charon_%s_protocols(void) __attribute__((used));
static void charon_%s_protocols(void)
{
]], library.name, introduced, library.name, library.folder, library.name, library.name)
        for _, name in ipairs(names) do
            if carried[name] then
                text = text .. string.format("    // __OBJC_PROTOCOL_$_%s is emitted by %s\n", name, carried[name])
            else
                text = text .. string.format("    (void)@protocol(%s);\n", name)
            end
        end
        text = text .. "}\n"
        io.writefile(file, text)
        table.insert(written, file)
        floor[file] = floors_of[introduced]
    end
    byteorder.sort(written)
    return written, floor
end

local function names_a_class(symbols)
    for _, symbol in ipairs(symbols) do
        if symbol:startswith("_OBJC_CLASS_$_") or symbol:startswith("_OBJC_METACLASS_$_") or symbol:startswith("_OBJC_IVAR_$_") then
            return true
        end
    end
    return false
end

-- A band neither keeps nor re-exports an object below its registry minimum (range.minimums, from
-- minimums() below, for the band's release range.release); those it names as left out, the third answer.
function band(release_exports, objects, arrived, range)
    local kept, reexported, left = {}, {}, {}
    for _, object in ipairs(objects) do
        local minimum = range and range.minimums[object]
        local symbols = exported_symbols(object)
        local present = {}
        for _, symbol in ipairs(symbols) do
            if release_exports[symbol] then
                table.insert(present, symbol)
            end
        end
        if minimum and dyld.compare_versions(range.release, minimum) < 0 then
            table.insert(left, object)
        elseif #present == 0 or (arrived and not names_a_class(present) and arrived(object)) then
            table.insert(kept, object)
        elseif #present == #symbols then
            table.join2(reexported, symbols)
        else
            local absent = {}
            for _, symbol in ipairs(symbols) do
                if not release_exports[symbol] then
                    table.insert(absent, symbol)
                end
            end
            raise("%s defines %s, which the release already exports, together with %s, which it does not; an object carries API that arrived in one release, so split it",
                  path.filename(object), table.concat(present, " "), table.concat(absent, " "))
        end
    end
    return kept, reexported, left
end

local function compiled(opt)
    local attach = path.join(opt.builddir, "objects", "attach.o")
    os.mkdir(path.directory(attach))
    -- the SDK these objects are compiled against, for tools/release-split.lua: which release first exports a symbol depends on
    -- which SDK's stubs say what library it belongs to, and guessing the SDK from what is installed answers for another build
    io.writefile(path.join(opt.builddir, "objects", "sdkdir"), opt.sdkdir)
    compile(opt, path.join(opt.root, "attach.c"), attach)
    local placed = floors(opt)
    local objects, origins, minimums = {}, {}, {}
    local pending = {}
    for _, library in ipairs(LIBRARIES) do
        objects[library.name] = {}
    end
    -- The libraries this run keeps, and no other: the object table above is empty for the rest, so
    -- a link, a band plan or a check that asks for one of those finds no objects to read rather
    -- than a library's worth compiled for a run that drops it at the link.
    for _, library in ipairs(staged_libraries(opt)) do
        -- the protocol metadata the framework carries and the port does not: one generated source per band
        local generated = path.join(opt.builddir, "protocols", library.folder)
        os.mkdir(generated)
        local written, floor = protocol_sources(opt, library, generated, library.frameworks[1])
        for _, source in ipairs(written) do
            local object = path.join(opt.builddir, "objects", library.folder, "protocols", path.filename(source) .. ".o")
            os.mkdir(path.directory(object))
            local job = table.join(opt, {includes = {path.join(opt.root, library.folder)}})
            -- compiled at its rows' registry minimum, as floors() compiles a placed source, and left out of every
            -- band below it: a framework's headers need not compile for a release its rows are not carried to
            -- (ARKit's ARSession.h declares a strong dispatch_queue_t, which is no object before iOS 6)
            local minimum = floor[source]
            if minimum and dyld.compare_versions(minimum, opt.deployment) > 0 then
                job = table.join(job, {deployment = minimum, triple = opt.architecture .. "-apple-ios" .. minimum})
                minimums[object] = minimum
            end
            pending[#pending + 1] = {opt = job, source = source, object = object}
            table.insert(objects[library.name], object)
            origins[object] = source
        end
        for _, source in ipairs(sources(opt.root, library)) do
            local object
            if placed[source] then
                object = placed[source].object
                minimums[object] = placed[source].minimum
            else
                object = path.join(opt.builddir, "objects", library.folder, path.basename(source) .. ".o")
                os.mkdir(path.directory(object))
                table.insert(pending, {opt = opt, source = source, object = object,
                                       library = library})
            end
            table.insert(objects[library.name], object)
            origins[object] = source
        end
    end
    compile_all(opt, pending)
    return attach, objects, origins, minimums
end

local function exported_through(release, install, seen)
    local found = release.libraries[install]
    if not found or seen[install] then
        return {}
    end
    seen[install] = true
    local names = table.keys(found.exports)
    for _, other in ipairs(found.reexports or {}) do
        table.join2(names, exported_through(release, other, seen))
    end
    return names
end

local function provides(release, install, symbol, seen)
    local found = release.libraries[install]
    if not found or seen[install] then
        return false
    end
    seen[install] = true
    if found.exports[symbol] then
        return true
    end
    for _, other in ipairs(found.reexports or {}) do
        if provides(release, other, symbol, seen) then
            return true
        end
    end
    return false
end

-- A .tbd that says a library at `install` exports these symbols and classes: what a link needs to name a
-- library the SDK does not have, or has elsewhere, and what the release's own cache says it holds.
local function write_stub(architecture, folder, install, symbols, classes)
    local target = architecture .. "-ios"
    local file = path.join(folder, path.basename(install) .. ".tbd")
    io.writefile(file, table.concat({"--- !tapi-tbd", "tbd-version: 4", "targets: [ " .. target .. " ]", "install-name: '" .. install .. "'", "exports:",
                                     "  - targets: [ " .. target .. " ]", "    symbols: [ " .. table.concat(symbols, ", ") .. " ]",
                                     "    objc-classes: [ " .. table.concat(classes, ", ") .. " ]", "..."}, "\n") .. "\n")
    return file
end

function stubs(architecture, library, reexported, releases, folder)
    local preferred = {}
    for index, framework in ipairs(library.frameworks) do
        preferred[framework] = index
    end
    local chosen = {}
    for _, symbol in ipairs(reexported) do
        local candidates = {}
        for install in pairs(releases[1].libraries) do
            local everywhere = true
            for _, release in ipairs(releases) do
                everywhere = everywhere and provides(release, install, symbol, {})
            end
            if everywhere then
                table.insert(candidates, install)
            end
        end
        if #candidates == 0 then
            raise("no library exports %s in every release a band of %s is checked against", symbol, library.name)
        end
        table.sort(candidates, function (a, b)
            local left, right = preferred[path.basename(a)] or math.huge, preferred[path.basename(b)] or math.huge
            if left ~= right then
                return left < right
            end
            return byteorder.less(a, b)
        end)
        chosen[candidates[1]] = chosen[candidates[1]] or {}
        table.insert(chosen[candidates[1]], symbol)
    end
    local files = {}
    for _, install in ipairs(table.orderkeys(chosen)) do
        local symbols, classes = {}, {}
        for _, symbol in ipairs(exported_through(releases[1], install, {})) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                table.insert(classes, class)
            elseif not symbol:startswith("_OBJC_METACLASS_$_") then
                table.insert(symbols, symbol)
            end
        end
        byteorder.sort(symbols)
        byteorder.sort(classes)
        table.insert(files, write_stub(architecture, folder, install, symbols, classes))
    end
    return files
end

-- `-framework X` resolves through the SDK's own install-name for X, which is wherever Apple's
-- *current* release keeps it - not necessarily where the band being linked keeps it. JavaScriptCore
-- moved from /System/Library/PrivateFrameworks to /System/Library/Frameworks exactly at iOS 7.0
-- (measured against both ends of the covered range, the only one of this package's 21 frameworks
-- that did): a band before that point links fine because the SDK's path happens to still match iOS
-- 6's, and a band from 7.0 on embeds a load command for a path that release never carried, which
-- only shows up as a bare "which neither the device nor this build provides" at the import check,
-- far from the framework name that would explain it.
--
-- The fix cannot be stubs()'s: a .tbd built from only this band's own exports drops every symbol
-- a later release added that this band's code reaches through a weak, API_AVAILABLE-guarded
-- reference (UTType.m's calls to _UTTypeIsDeclared/_UTTypeIsDynamic, absent on every release this
-- package covers before 11.0, are exactly that shape) - the linker needs a *declaration* to bind
-- those weakly, and a band-scoped stub does not carry one for the same reason the band does not
-- carry the real definition. Answered instead by keeping the ordinary, full-declaration
-- `-framework X` link exactly as before (nothing loses a weak-import declaration it depends on),
-- and rewriting the one load command afterward with install_name_tool -change, from whatever the
-- SDK embedded to the path this band's own cache says the framework actually lives at - the same
-- fact stubs() already reads from the cache, applied to the framework itself instead of only the
-- symbols a band reexports from it. Not a JavaScriptCore special case: framework_install_path is
-- asked for every framework a library links, so the next one Apple relocates is caught here
-- instead of costing another afternoon finding it by hand.
function framework_install_path(library, releases)
    local found = {}
    for _, framework in ipairs(library.frameworks) do
        local suffix = "/" .. framework .. ".framework/" .. framework
        local install
        for candidate in pairs(releases[1].libraries) do
            if candidate:endswith(suffix) then
                install = install or candidate
            end
        end
        if install then
            local everywhere = true
            for _, release in ipairs(releases) do
                everywhere = everywhere and release.libraries[install] ~= nil
            end
            if not everywhere then
                raise("%s is at %s in one release this band covers and not in another: a band spanning both needs the same install path in every release it covers, or it should be split at the release where the framework moved",
                      framework, install)
            end
            found[framework] = install
        end
    end
    return found
end

-- dyld learned to re-export a symbol of another library in iOS 4.2, and ld64
-- refuses -reexported_symbols_list for anything older ("targeted OS version
-- does not support -reexported_symbols_list"). A band for such a release still
-- drops what the release carries - that is the point of the band - it just
-- promises nothing in its place, and the port binds the release's own symbol,
-- which is there. libcxx does the same where it cannot re-export libcxxabi.
function reexports(deployment)
    return dyld.compare_versions(deployment, "4.2") >= 0
end

local INVENTORIES = {}

-- The Objective-C inventory of a release's cache is a function of the cache file and of the code that
-- reads it, and reading it is most of what a gate spends linking (measured: 3.9 s of a quiet machine's
-- time, loaded back in 0.4 s). So a build with a store keeps it there, under the cache's path, size
-- and time and the text of the modules that read it.
local INVENTORY_STORE

local function release_inventory(cache)
    if not INVENTORIES[cache] and INVENTORY_STORE and os.isfile(cache) then
        local parts = {"charon-inventory-1", cache, tostring(os.filesize(cache)), tostring(os.mtime(cache))}
        for _, name in ipairs({"objc.lua", "dyld.lua", "macho.lua"}) do
            table.insert(parts, hash.strhash128(io.readfile(path.join(os.scriptdir(), name))))
        end
        local key = hash.strhash128(table.concat(parts, "\n"))
        local file = path.join(INVENTORY_STORE, "inventories", key .. ".lua")
        local saved = os.isfile(file) and io.load(file)
        if saved then
            os.touch(file)
        else
            saved = objc.inventory(cache)
            store_folder(path.directory(file))
            local temporary = file .. "." .. hash.strhash32(cache .. os.mclock()) .. ".tmp"
            io.save(temporary, saved)
            os.mv(temporary, file)
        end
        INVENTORIES[cache] = saved
    end
    INVENTORIES[cache] = INVENTORIES[cache] or objc.inventory(cache)
    return INVENTORIES[cache]
end

local function carried_classes(cache)
    return release_inventory(cache).classes
end

-- The C++ runtime a band's objects link: libc++ where every release of the band has it, from iOS 5.0. Below
-- that the Itanium C++ ABI they need (operator new and delete, the personality routine, terminate) is
-- libstdc++.6's, which every release of the band must carry (checked for each) and the SDK does not, so the stub is
-- written from what the first release's cache says it exports.
function cxx_runtime(opt, library, releases, folder)
    local libcxx, libstdcxx = "/usr/lib/libc++.1.dylib", "/usr/lib/libstdc++.6.dylib"
    local without = false
    for _, release in ipairs(releases) do
        without = without or not release.libraries[libcxx]
    end
    if not without then
        return {"-lc++"}
    end
    for _, release in ipairs(releases) do
        if not release.libraries[libstdcxx] then
            raise("%s keeps C++ objects, and a release of its band has neither %s nor %s", library.name, libcxx, libstdcxx)
        end
    end
    local symbols = exported_through(releases[1], libstdcxx, {})
    byteorder.sort(symbols)
    os.mkdir(folder)
    return {write_stub(opt.architecture, folder, libstdcxx, symbols, {})}
end

-- The key of one link for the store: the linker's arguments with the run's own folders taken out,
-- every file they name by content (an object by its store key, which is its content's cause), and the
-- install paths the link rewrites afterwards. What the link then checks is checked on the copy too.
function linked_key(opt, program, arguments, real_paths, outputdir, output)
    if not opt.store then
        return nil
    end
    -- This file's text too: what it does to a library after the linker (the install paths it rewrites)
    -- is its code and not an argument.
    local parts = {"charon-link-2", program, environment(), own_text()}
    local folders = {{outputdir, "@outputdir"}, {opt.builddir, "@builddir"}}
    for _, argument in ipairs(arguments) do
        local text = argument
        for _, folder in ipairs(folders) do
            if folder[1] then
                local at = text:find(folder[1], 1, true)
                while at do
                    text = text:sub(1, at - 1) .. folder[2] .. text:sub(at + #folder[1])
                    at = text:find(folder[1], at + #folder[2], true)
                end
            end
        end
        table.insert(parts, text)
        local file = argument:match("^%-Wl,%-[%w_]+,(.+)$") or argument
        if file ~= output and os.isfile(file) then
            table.insert(parts, KEYS[file] or hash.strhash128(io.readfile(file)))
        end
        local other = argument:match("^%-l(.+)$")
        if other then
            local dylib = path.join(outputdir, "lib" .. other .. ".dylib")
            table.insert(parts, os.isfile(dylib) and hash.strhash128(io.readfile(dylib)) or "none")
        end
    end
    for _, framework in ipairs(table.orderkeys(real_paths)) do
        table.insert(parts, framework .. "=" .. real_paths[framework])
    end
    return hash.strhash128(table.concat(parts, "\n"))
end

local function link(opt, library, attach, objects, releases, outputdir, checked)
    local release = checked and checked.release or opt.deployment
    local kept, reexported, left = band(releases[1].exports, objects, checked and later_than(opt, checked.release), {release = release, minimums = opt.minimums or {}})
    if #left > 0 then
        local named = {}
        for _, object in ipairs(left) do
            table.insert(named, string.format("%s (%s)", path.filename(opt.origins[object]), opt.minimums[object]))
        end
        cprint("${color.warning}note:${clear} the band for iOS %s leaves %d objects of %s out below their registry minimum: %s",
               release, #named, library.name, table.concat(named, " "))
    end
    if not reexports(opt.deployment) then
        reexported = {}
    end
    if checked then
        local told = duplicated(kept, carried_classes(checked.cache))
        if #told > 0 then
            raise("the band for iOS %s keeps %s, which the release has and does not export: the band cannot leave a class out that nothing says is there, and a process would hold two classes of that name, one of which the runtime picks. Ask the release for the class where it has one, or carry it under a name of Charon's own.",
                  checked.release, table.concat(told, " "))
        end
    end
    local output = path.join(outputdir, "lib" .. library.name .. ".dylib")
    os.mkdir(outputdir)
    -- -Wno-incompatible-sysroot: clang's own notice that the sysroot is a newer SDK than the deployment
    -- target, which is every link this file does - the port compiles a current SDK for releases from 2.0 on -
    -- and the gate reads a diagnostic at this step as a failure. The same flag with the same reason is in
    -- packages/m/matter/xmake.lua:69 and packages/s/swift-runtime/xmake.lua:899, so this is the house
    -- spelling and not a new one.
    local arguments = {"-target", opt.triple, "-isysroot", opt.sdkdir, "-fuse-ld=" .. opt.ld, "-fobjc-arc",
                       "-dynamiclib", "-Wno-incompatible-sysroot", NOT_ENCRYPTED,
                       "-install_name", path.join(INSTALL_FOLDER, path.filename(output)),
                       "-Wl,-rename_section,__DATA,__objc_catlist,__DATA,__charon_catlist", "-o", output, attach}
    table.join2(arguments, kept)
    if #reexported > 0 then
        local folder = path.join(opt.builddir, "stubs", path.filename(outputdir), library.name)
        os.tryrm(folder)
        os.mkdir(folder)
        table.join2(arguments, stubs(opt.architecture, library, reexported, releases, folder))
    end
    for _, other in ipairs(library.libraries or {}) do
        table.join2(arguments, {"-L" .. outputdir, "-l" .. other})
    end
    -- C++ reaches a library only through its Objective-C++ objects: the archives' API is C++, and so
    -- is the runtime they need. A band that keeps none of those objects, because its release carries
    -- the classes they define, links neither, since ld64 keeps a load command for every dylib it is
    -- given, used or not, and libc++ is exported only from iOS 5.0 on.
    local cxx = false
    for _, object in ipairs(kept) do
        cxx = cxx or opt.origins[object]:endswith(".mm")
    end
    -- **This is a change to the machinery, not to one framework.** Every archive in `archives` was
    -- taken to be C++, because every archive these packages held was C++, and the C++ ones are
    -- the only ones a band without a .mm object may skip: they need the C++ runtime, which is
    -- exported only from iOS 5.0 on, and ld64 keeps a load command for a dylib it is given
    -- whether the band used it or not. An archive whose API is **C** is the case that rule gets
    -- wrong, and there is one: charon-coding holds the secure coding, the copying and the archive
    -- allow-list that the Intents, IntentsUI and Accessibility classes share, and no two of those
    -- libraries can borrow it from another, because internal_symbol() hides a helper out of every
    -- dylib. A library that keeps no C++ object in any band therefore had no way to have a C
    -- helper at all, which is what the link said on `_charon_intents_decode` referenced from
    -- [AXBrailleTable initWithCoder:], which is where the link said it.
    --
    -- The language is a second list of the same names, `c_archives`, and not a table inside
    -- `archives`, because coordination/build-gate.lua reads `library.archives` for the names and
    -- a band does not change a script the coordinator owns.
    --
    -- tests/addon/archive_language_test.lua is the check: it fails on any library whose archives a
    -- band that keeps no C++ object could not link, which is the state without this.
    -- One list of the archives this band keeps, and the order they go on the link line in: the
    -- C ones always, the C++ ones only for a band that kept a .mm object, and each name once.
    local wanted_archives = {}
    for _, name in ipairs(library.archives or {}) do
        wanted_archives[name] = cxx
    end
    for _, name in ipairs(library and library.c_archives or {}) do
        wanted_archives[name] = true
    end
    for _, language in ipairs(table.orderkeys(wanted_archives)) do
        if wanted_archives[language] then
            local archive = archive_of(opt.archives, language)
            if not archive then
                raise("%s links the static library of the package %s, and the build was given none: pass archives = {%s = {linkdir = ..., link = ..., includedir = ...}}, from the package's installdir",
                      library.name, language, language)
            end
            table.insert(arguments, path.join(archive.linkdir, "lib" .. archive.link .. ".a"))
        end
    end
    if cxx then
        table.join2(arguments, cxx_runtime(opt, library, releases, path.join(opt.builddir, "stubs", path.filename(outputdir), library.name)))
    end
    -- A system library the band's own sources call into, a SQLite the HealthKit store is: it is linked
    -- as -l and the SDK carries its .tbd, and every release a band that keeps those sources runs on
    -- has it, which the import check below reads off the cache and would otherwise name as unresolved.
    for _, name in ipairs(library.system or {}) do
        table.insert(arguments, "-l" .. name)
    end
    -- A framework the band's release does not have is not linked: it could not load there. What the
    -- band keeps then needs none of it, or the link names the symbols that do.
    local real_paths = framework_install_path(library, releases)
    local absent = {}
    for _, framework in ipairs(library.frameworks) do
        if real_paths[framework] then
            table.join2(arguments, {"-framework", framework})
        else
            table.insert(absent, framework)
        end
    end
    if #absent > 0 then
        cprint("${color.warning}note:${clear} the band for iOS %s links %s without %s, which the release does not have", release, library.name, table.concat(absent, " "))
    end
    if #reexported > 0 then
        local list = path.join(opt.builddir, library.name .. ".reexported")
        io.writefile(list, table.concat(reexported, "\n") .. "\n")
        table.insert(arguments, "-Wl,-reexported_symbols_list," .. list)
    end
    local internal = {}
    local seams = opt.root and seam_symbols(opt.root, library) or {}
    for _, object in ipairs(kept) do
        for _, symbol in ipairs(defined_symbols(object)) do
            if internal_symbol(symbol) and not seams[symbol] then
                table.insert(internal, symbol)
            end
        end
    end
    if #internal > 0 then
        local list = path.join(opt.builddir, library.name .. ".internal")
        io.writefile(list, table.concat(table.unique(internal), "\n") .. "\n")
        table.insert(arguments, "-Wl,-unexported_symbols_list," .. list)
    end
    local program, argv = driver(opt, arguments)
    local stored = linked_key(opt, program, argv, real_paths, outputdir, output)
    stored = stored and path.join(opt.store, "links", stored:sub(1, 2), stored .. ".dylib")
    if stored and os.isfile(stored) then
        os.cp(stored, output)
        os.touch(stored)
    else
        os.vrunv(program, argv)
        local embedded
        for _, framework in ipairs(library.frameworks) do
            local real = real_paths[framework]
            if real then
                embedded = embedded or macho.images(macho.read(output))[1].libraries
                local suffix = "/" .. framework .. ".framework/" .. framework
                for _, current in ipairs(embedded) do
                    if current:endswith(suffix) and current ~= real then
                        os.vrunv("xcrun", {"install_name_tool", "-change", current, real, output})
                    end
                end
            end
        end
        if stored then
            store_folder(path.directory(stored))
            local temporary = stored .. "." .. hash.strhash32(output .. os.mclock()) .. ".tmp"
            os.cp(output, temporary)
            os.mv(temporary, stored)
        end
    end
    if sections_of(output)["__DATA,__objc_catlist"] then
        raise("%s kept __objc_catlist: the linker did not rename it, so the runtime would attach every backported method over the system's own", output)
    end
    local held = {}
    for _, symbol in ipairs(defined_symbols(output)) do
        held[symbol] = true
    end
    local missing = {}
    for _, object in ipairs(kept) do
        for _, symbol in ipairs(exported_symbols(object)) do
            if not held[symbol] then
                table.insert(missing, symbol)
            end
        end
    end
    if #missing > 0 then
        byteorder.sort(missing)
        raise("%s holds %d API it does not export, and a port that links against it takes the weak import of the release instead, which is NULL there: %s",
              output, #missing, table.concat(table.slice(missing, 1, math.min(8, #missing)), " ") .. (#missing > 8 and (" and %d more"):format(#missing - 8) or ""))
    end
    return output
end

local function loaded(cache, architecture)
    local release = dyld.load(cache)
    if not table.contains(compatible(architecture), release.architecture) then
        raise("%s holds %s libraries, which an %s build does not run on", cache, release.architecture, architecture)
    end
    return release
end

-- A category's class reference is NULL on a release that has the class without exporting
-- it, and is a class of Charon's own where charon_alias.h exports the release's name; in
-- both cases attach.c attaches the category to the release's class of that name, which it
-- finds only where the class is in an image the library loads. A category whose class is
-- neither exported nor there is dropped on the very release it is for, while its methods
-- still count as built. An alias of charon_alias.h is held to the same, with one more answer
-- the release's class is not the only one of: the proxy it defines is a class of this band
-- too, and on a release that carries no class of the name it is the class the name stands for.
local function loaded_images(release, binaries, binary, architecture)
    local own = {}
    for _, other in ipairs(binaries) do
        own[path.join(INSTALL_FOLDER, path.filename(other))] = other
    end
    local seen, pending = {}, {path.join(INSTALL_FOLDER, path.filename(binary))}
    while #pending > 0 do
        local install = table.remove(pending)
        if not seen[install] then
            seen[install] = true
            local dependents = release.libraries[install] and release.libraries[install].dependents
            if own[install] then
                for _, image in ipairs(macho.images(macho.read(own[install]))) do
                    if image.architecture == architecture then
                        dependents = image.libraries
                    end
                end
            end
            table.join2(pending, dependents or {})
        end
    end
    return seen
end

function unattached_categories(release, inventory, binaries, architecture)
    local defined, aliases = {}, {}
    for _, binary in ipairs(binaries) do
        -- With the symbols a compiler hid, because the class behind an alias is exactly what a library
        -- hides: nothing in the image names it (every reference goes to the alias), so ld64 makes it a
        -- private external and it is there all the same. measured 2026-10-04 over the library a package
        -- install of this tree linked: `nm -m` reads
        --   non-external (was a private external) _OBJC_CLASS_$_CharonNSURLSessionStreamTask
        -- where the object had it external. duplicated() reads its objects the same way.
        for _, symbol in ipairs(defined_symbols(binary, true)) do
            defined[symbol] = true
        end
    end
    local found = {}
    for _, binary in ipairs(binaries) do
        local images
        for proxy, name in pairs(objc.binary_aliases(binary, architecture) or {}) do
            aliases[proxy] = name
            -- The alias's class is the release's where the release has one in an image this library
            -- loads, and otherwise it is the proxy: a name a release carries in SOME of the releases a
            -- band is built for and in none of the others (NSURLSessionStreamTask, which CFNetwork
            -- carries from 8.0 on and nothing below carries at all) leaves the proxy as the class the
            -- name stands for, the alias's own class methods answer as the proxy's own there, and the
            -- members ld64 merged into the proxy are already on it. So a band that defines the proxy
            -- carries the alias. What it does not carry is an alias whose proxy is in no binary of
            -- the band: there the name stands for a class nothing of this band has.
            local carried = inventory.classes[name]
            images = images or loaded_images(release, binaries, binary, architecture)
            if not (carried and carried.image and images[carried.image]) and not defined["_OBJC_CLASS_$_" .. proxy] then
                table.insert(found, string.format("%s, which %s aliases in %s, and which no release this band is built for carries where the library's loader can give it what the alias adds", name, proxy, path.filename(binary)))
            end
        end
    end
    -- A category's class reference is filled when the class is this binary's own, an alias, or
    -- exported by the release or by a library of the package; otherwise dyld leaves it NULL
    -- and the loader has no class to attach it to, even where the release carries the class.
    -- ld64 merges a library's categories on one class into one, named after one of them, so a
    -- category is named with the members it adds: they, not its name, find every file behind it.
    for _, binary in ipairs(binaries) do
        for _, category in ipairs(objc.binary_categories(binary, architecture) or {}) do
            local bound = category.bound and category.bound:match("^_OBJC_CLASS_%$_(.+)$")
            local class = category.class and (aliases[category.class] or category.class) or bound
            local attached = category.class ~= nil or (category.bound ~= nil and (release.exports[category.bound] or defined[category.bound]))
            if not attached then
                local members = {}
                for kind, sign in pairs({instance = "-", class_methods = "+"}) do
                    for selector in pairs(category[kind]) do
                        table.insert(members, sign .. selector:sub(2))
                    end
                end
                byteorder.sort(members)
                local named = string.format("%s(%s: %s) in %s", class or "a class this check cannot name", category.name or "?",
                                            table.concat(members, " "), path.filename(binary))
                local carried = class and inventory.classes[class]
                if carried and carried.image then
                    table.insert(found, string.format("%s (the release carries %s in %s without exporting it: alias it through charon_alias.h)",
                                                      named, class, carried.image))
                else
                    table.insert(found, named)
                end
            end
        end
    end
    byteorder.sort(found)
    return found
end

function check_categories(release, inventory, binaries, architecture, version)
    local found = unattached_categories(release, inventory, binaries, architecture)
    if #found > 0 then
        raise("categories whose class neither iOS %s nor the package exports, and aliases whose class it does not carry in an image the library loads, so the library's loader has no class to give what they add and nothing of it is there: %s",
              version, table.concat(found, " "))
    end
end

-- The members a binary's categories add to classes it does not define itself: the API a category
-- carries, as the registry spells it.
local function class_image(inventory, name)
    local class = inventory and inventory.classes and inventory.classes[name]
    return class and class.image or false
end

local function members_of(inventory, classes)
    local found = {}
    for name, class in pairs(inventory and inventory.classes or {}) do
        if classes(name) then
            for kind, sign in pairs({instance = "-", class = "+"}) do
                for selector in pairs(class[kind]) do
                    local plain = selector:sub(2)
                    if not plain:startswith(".cxx_") and plain ~= "load" and not internal_symbol(plain) then
                        table.insert(found, string.format("%s[%s %s]", sign, name, plain))
                    end
                end
            end
        end
    end
    return found
end

-- What the band machinery places an object by: the members a category adds to a class the object does not
-- define. A member the port adds in a category is not defined by the object that carries it - a member of
-- a class the release already carries belongs to that class - and counting it here moved the carrying object
-- out of the band its own minimum says: measured 2026-09-28 by bisecting the 4.3 gate over 2fde39f4, which
-- widened this for check_registry, and put 16 objects above iOS 4.3.
function added_members(inventory, ours)
    return members_of(inventory, function (name)
        return not class_image(inventory, name) and not ours[name]
    end)
end

-- The API the port carries in its categories, which is a wider question than what any one object defines: a
-- member the port adds to a class the release already carries is API the port carries, and check_registry asks
-- whether a row says so. The port's own classes are its machinery and it names them. This is the set 2fde39f4
-- widened, kept for that reader alone.
--
-- **AND THE PROTOCOLS THE PORT ITSELF DEFINES, which is the same blindness the branch above records for
-- classes, and for the same reason: a protocol is not a class.** collect() keeps the two in separate tables
-- (`modules/apple/objc.lua:251` returns `classes` and `protocols` apart), so a method of `@protocol P` was in
-- neither `found.classes` nor `found.members` and every row spelled `-[P method]` was unbuildable however
-- much of P there was. Measured 2026-10-04 on the Metal 4 queue: the protocol transcribed, the class
-- conforming, `__OBJC_PROTOCOL_$_MTL4CommandQueue` emitted with its method list, and check_registry still
-- answered "listed as implemented, but nothing of that name is built" for all eight members and both
-- properties - the same finding the branch above records for a protocol with no image, and the same answer:
-- the row was right and the CHECK was blind.
--
-- **AND ONLY THE PROTOCOLS THE PORT DEFINES, which is the half that took a second measurement.** A protocol
-- record is per image, not exported: a linked library carries a `protocol_t` for every protocol it adopts OR
-- MERELY REFERENCES, so reading `inventory.protocols` whole counted the system's protocols as the port's. The
-- 6.1.3 gate on land-w19 answered "built, but no entry in registry/" for `-[NSObject retain]`,
-- `-[UITableViewDelegate tableView:didSelectRowAtIndexPath:]`, `-[MPSNNPadding label]`, `-[CAMetalDrawable
-- layer]` and four hundred more, every one of them Apple's.
--
-- The test is the one this file already has for "the port declares it": `declared_protocols()` reads every
-- header the package installs and keeps a protocol declared WITH A BODY, dropping a forward declaration
-- because the SDK's umbrella supplies that body and a port that redeclares it declares nothing. Over the
-- package that is 47 protocols - its own `Charon*` ones and the transcriptions in the Charon*Protocols.h
-- headers - and `MTL4CommandQueue` is one of them while `NSObject`, `UITableViewDelegate`, `CAMetalDrawable`,
-- `MPSNNPadding` and `GKRandom` are none of them.
--
-- **AND, OF THOSE, ONLY THE MEMBERS THE REGISTRY NAMES** - the rule the loop below states where it applies.
-- Declaring a protocol is not carrying it: a port header transcribes `UIMutableTraits` so that a method
-- taking `id<UIMutableTraits>` compiles, the port class adopts it, the protocol is emitted, and the port
-- implements none of its thirty-nine members and the corpus names none of them. What the loop keeps is what
-- the port claims, and what it keeps is still held to the build.
--
-- `added_members()` above is deliberately NOT changed: it places an OBJECT by the members a category adds to
-- a class, and a protocol is not an object and carries no band.
function carried_api(inventory, declared, documented)
    local found = members_of(inventory, function (name)
        return not name:startswith("Charon")
    end)
    declared = declared or {}
    documented = documented or {}
    for name, protocol in pairs(inventory and inventory.protocols or {}) do
        if declared[name] and not name:startswith("Charon") then
            for kind, sign in pairs({instance = "-", class = "+"}) do
                for selector in pairs(protocol[kind] or {}) do
                    local plain = selector:sub(2)
                    local spelling = string.format("%s[%s %s]", sign, name, plain)
                    -- AND ONLY WHERE THE REGISTRY NAMES IT: a protocol the package declares in order to
                    -- satisfy Apple's own signatures is adopted by a port class and so is emitted, and the
                    -- port implements not one of its members. A row that names one is still HELD to the
                    -- build - it reads unbuilt when the protocol is not emitted, which is what the Metal 4
                    -- queue's ten rows measured on 2026-10-04.
                    if documented[spelling] and not plain:startswith(".cxx_") and plain ~= "load"
                       and not internal_symbol(plain) then
                        table.insert(found, spelling)
                    end
                end
            end
        end
    end
    return found
end


-- `declared` is the set declared_protocols() returns - the protocols the package's own headers declare
-- with a body - and `documented` is the set of names registry/ carries. Both are what carried_api() below
-- needs to tell a protocol the port carries from one it declares to satisfy Apple's own signatures.
function surface(binaries, architecture, declared, documented)
    local found = {classes = {}, members = {}, symbols = {}, defined = {}, registered = {}, answered = {}, protocols = {}}
    for _, binary in ipairs(binaries) do
        local ours = {}
        if macho.imported_symbols(binary, architecture)["objc_allocateClassPair"] then
            for literal in pairs(macho.text_literals(binary, architecture)) do
                found.registered[literal] = true
            end
        end
        for _, symbol in ipairs(exported_symbols(binary)) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class then
                ours[class] = true
                found.classes[class] = true
            elseif not symbol:startswith("_OBJC_METACLASS_$_") and not symbol:startswith("_OBJC_IVAR_$_") then
                found.symbols[symbol:sub(2)] = true
                found.defined["_" .. symbol:sub(2)] = true
            end
        end
        local inventory = objc.binary_inventory(binary, architecture)
        -- A protocol the port defines and emits is carried, whatever its inventory entry lacks. Found
        -- 2026-10-01: six UIKit rows (UIDragSession, UIDragSessionDelegate-ish names, UITextDragRequest and
        -- friends) sat `absent` with "the name is not there" while the build emitted _OBJC_PROTOCOL_$_X for
        -- each - found.classes only takes a name whose class.image is set, and a protocol the port
        -- declares carries no image, so the branch below never saw them. Recorded here rather than in the
        -- row, because the row was right and the CHECK was blind.
        for symbol in pairs(found.defined) do
            local proto = symbol:match("^_OBJC_PROTOCOL_%$_(.+)$") or symbol:match("^_OBJC_LABEL_PROTOCOL_%$_(.+)$")
            if proto and not proto:startswith("Charon") then
                found.protocols[proto] = true
            end
        end
        for name, class in pairs(inventory and inventory.classes or {}) do
            if class.image and not name:startswith("Charon") then
                found.classes[name] = true
            end
            if (class.image or (found.protocols or {})[name]) and not name:startswith("Charon") then
                found.classes[name] = true
            end
            if not name:startswith("Charon") then
                for kind, sign in pairs({instance = "-", class = "+"}) do
                    for selector in pairs(class[kind]) do
                        found.answered[string.format("%s[%s %s]", sign, name, selector:sub(2))] = true
                    end
                end
            end
        end
        for _, member in ipairs(carried_api(inventory, declared, documented)) do
            found.members[member] = true
        end
    end
    return found
end

-- The four answers. `implemented` is the port's behaviour, and where the device lacks the part it is the answer the
-- real system gives there (an availability query that says NO, a generator that does nothing). `owed` is the work
-- still to do: the API is not there yet, and the port will build it. `absent` is the release's own window only: a
-- `maximum` from which the release carries the API itself, so the port must not answer it. `ignored` is a call the
-- release's own implementation takes. There is no other resting place: a decision not to build is `owed`.
local STATUSES = {implemented = true, absent = true, ignored = true, owed = true}

-- The accessor that reads or writes a property by the property's own name, as the other spelling of that one
-- API: -[Class name] or +[Class name] for Class.name, and Class.name for either. The setter is deliberately not
-- one of them: a property can be carried while its setter is left out or left inert, which is what a row of its
-- own is for, and spelling() would pair them and refuse an answer that is right.
local function accessor_of(api)
    local sign, owner, name = api:match("^([-+])%[([%w_]+) ([%w_]+)%]$")
    if sign then
        return owner .. "." .. name
    end
    return api:match("^([%u][%w_]*)%.([%w_]+)$") and api
end

-- The registry of a package root: listed (API -> entry), incomplete (the refusals), the frameworks it has a file for, and
-- unlibraried (the generated folders no LIBRARIES entry builds, by folder and row count). Reads what is on disk; build() runs generate().
function registry(root)
    local listed, told, incomplete, frameworks = {}, {}, {}, {}
    local unlibraried = {}
    local files = table.join(os.files(path.join(root, "registry", "*.json")), os.files(path.join(root, "registry", "*", "*.json")))
    byteorder.sort(files)
    for _, file in ipairs(files) do
        -- registry/<Framework>.json or registry/<Framework>/<part>.json, named from the package root so that a
        -- name named twice names two paths a reader can open
        local folder = path.filename(path.directory(file))
        local named = folder == "registry" and path.filename(file) or folder .. "/" .. path.filename(file)
        named = "registry/" .. named
        frameworks[folder == "registry" and path.basename(file) or folder] = true
        local held = json.decode(io.readfile(file))
        for _, entry in ipairs(held.entries or held) do
            if told[entry.api] then
                table.insert(incomplete, entry.api .. " is named by both " .. told[entry.api] .. " and " .. named)
            end
            told[entry.api] = named
            listed[entry.api] = entry
            -- a method or a property is told by -[Class selector:], +[Class selector:] or Class.name: the generator's
            -- rule (tools/gen/target_availability.lua) and the check of releases read no other spelling, and a member
            -- spelled Class.selector: is asked for as a bare name, found nowhere and left as it was
            local plain = entry.api:gsub("%(%)$", "")
            if (entry.kind == "method" or entry.kind == "property") and not (plain:match("^[-+]%[[%w_]+ .+%]$") or plain:match("^[%w_]+%.[%w_]+$")) then
                table.insert(incomplete, entry.api .. " is a " .. entry.kind .. " not spelled -[Class selector:], +[Class selector:] or Class.name")
            elseif (entry.kind == "class" or entry.kind == "protocol") and not plain:match("^[%u_][%w_]*$") then
                -- the other way round: a class or a protocol is matched against an ObjCInterfaceDecl or an
                -- ObjCProtocolDecl of that name, so a member spelling is a name no dump can ever answer
                table.insert(incomplete, entry.api .. " is a " .. entry.kind .. " spelled " .. entry.api ..
                                          ", and a " .. entry.kind .. " is named by its interface or its protocol, not by a member")
            end
            if not STATUSES[entry.status] then
                table.insert(incomplete, entry.api .. " says " .. tostring(entry.status) .. ", which is not one of the four answers")
            elseif entry.status == "absent" and entry.maximum == nil then
                table.insert(incomplete, entry.api .. " is absent without a release window (maximum): absent is the release's own window, and a decision not to build the API is owed")
            elseif entry.status ~= "implemented" then
                if not entry.effect then
                    table.insert(incomplete, entry.api .. " is " .. entry.status .. " without an effect")
                elseif entry.status ~= "ignored" and not entry.reason then
                    table.insert(incomplete, entry.api .. " is " .. entry.status .. " without a reason")
                elseif entry.status == "ignored" and not entry.facts then
                    table.insert(incomplete, entry.api .. " is ignored without a file of facts")
                end
            end
        end
    end
    -- .gen/<Framework>/rows.tsv: the rows the generator emits for the contract layer, in the fields of a registry row. A generated
    -- row is an implementation and is listed as one, but only for a folder a LIBRARIES entry builds: sources() compiles no other
    -- folder, so no shipped library carries its symbols. The other folders are returned as unlibraried, and are not refused or
    -- listed. The row has to name the source that defines it, and a name the registry also holds is refused: an override is a
    -- registry row only, and the index must not contain it. The folders are read in byte order, so the refusal of a name two folders
    -- both name says the same thing on every machine.
    local built = {}
    for _, library in ipairs(LIBRARIES) do
        built[library.folder] = true
    end
    local index = {}
    for _, file in ipairs(os.files(path.join(root, ".gen", "*", "rows.tsv"))) do
        index[path.filename(path.directory(file))] = file
    end
    local read = {}
    for _, folder in ipairs(byteorder.keys(index)) do
        if built[folder] then
            table.insert(read, folder)
        else
            local rows = -1
            for _ in io.readfile(index[folder]):gmatch("[^\n]+") do
                rows = rows + 1
            end
            if rows > 0 then
                table.insert(unlibraried, {folder = folder, rows = rows})
            end
        end
    end
    for _, folder in ipairs(read) do
        local file = index[folder]
        local named = ".gen/" .. folder .. "/rows.tsv"
        frameworks[folder] = true
        local header
        for line in io.readfile(file):gmatch("[^\n]+") do
            local cells = {}
            for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
                table.insert(cells, cell)
            end
            if not header then
                header = cells
            else
                local row = {}
                for column, name in ipairs(header) do
                    row[name] = cells[column]
                end
                local source = row.source ~= "" and row.source or nil
                local text = source and os.isfile(path.join(root, source)) and io.readfile(path.join(root, source)) or nil
                local pattern = "%f[%w_]" .. row.api:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "%f[^%w_]"
                if row.owner ~= "generated" then
                    table.insert(incomplete, row.api .. " is in " .. named .. " with owner " .. tostring(row.owner) .. ", not generated")
                elseif row.status ~= "implemented" then
                    table.insert(incomplete, row.api .. " is in " .. named .. " as " .. tostring(row.status) .. "; a generated row is implemented")
                elseif not source then
                    table.insert(incomplete, row.api .. " is a generated row with no source")
                elseif not text then
                    table.insert(incomplete, row.api .. " is a generated row whose source " .. source .. " does not exist")
                elseif not text:find(pattern) then
                    table.insert(incomplete, row.api .. " is a generated row, but its source " .. source .. " does not define it")
                end
                if told[row.api] then
                    table.insert(incomplete, row.api .. " is named by both " .. told[row.api] .. " and " .. named)
                end
                told[row.api] = named
                listed[row.api] = {api = row.api, kind = row.kind, introduced = row.introduced, minimum = row.minimum,
                                   maximum = row.maximum, status = row.status, facts = row.facts, source = row.source,
                                   owner = row.owner, declhash = row.declhash}
            end
        end
    end
    -- Two rows that name one API in two spellings are one API and must answer alike: the port's headers carry the
    -- implemented one and lower its availability, and an implicit accessor carries its property's attribute,
    -- so a status that disagreed between a property and the accessor that reads it has one of them say the
    -- call is not there and the other lower it anyway. Said here, the registry is refused in the second it is read.
    local told_pair = {}
    for api, entry in pairs(listed) do
        local other = accessor_of(api)
        local twin = other and other ~= api and listed[other] or nil
        if twin and twin.status ~= entry.status then
            local pair = api < other and (api .. " " .. other) or (other .. " " .. api)
            if not told_pair[pair] then
                told_pair[pair] = true
                table.insert(incomplete, string.format("%s is %s and %s is %s, and they are one API in two spellings (%s and %s), which the port's headers would carry and lower together",
                                                      api, entry.status, other, twin.status, told[api], told[other]))
            end
        end
    end
    return listed, incomplete, byteorder.keys(frameworks), unlibraried
end

-- The property names a selector may be the accessor of, most specific first: setFoo: and isFoo are the accessor
-- spellings of foo, and a selector that is neither may be a property's own name. Both are answers on purpose: the
-- SDK decides which, by the getter= attribute on the property, and a row here may name either. A property whose own
-- name really is isSomething is covered by the literal answer, so nothing is lost by the guess.
local function property_of(selector)
    local found = {}
    local setter = selector:match("^set(%u[%w_]*):$")
    if setter then
        table.insert(found, setter:sub(1, 1):lower() .. setter:sub(2))
    end
    local getter = selector:match("^is(%u[%w_]*)$")
    if getter then
        table.insert(found, getter:sub(1, 1):lower() .. getter:sub(2))
    end
    -- a property whose own name already starts lower-case and continues upper-case, the way Apple spells an
    -- acronym at the front: NSProcessInfo.h:247-248 declare iOSAppOnMac and iOSAppOnVision with
    -- getter=isiOSAppOnMac and getter=isiOSAppOnVision, so the property is what follows "is", unchanged. The
    -- upper-case second letter is the condition, so a selector such as -issue is not read as a property "sue".
    local acronym = selector:match("^is(%l%u[%w_]*)$")
    if acronym then
        table.insert(found, acronym)
    end
    local literal = selector:match("^([%w_]+)$")
    if literal then
        table.insert(found, literal)
    end
    return found
end

spellings = function(api)
    local plain = api:gsub("%(%)$", "")
    local found = {[plain] = true, [plain .. "()"] = true}
    local class, member = plain:match("^([%u][%w_]*)%.(.+)$")
    if class then
        local accessors = {member, "set" .. member:sub(1, 1):upper() .. member:sub(2) .. ":"}
        -- and the getter a property the SDK declares getter=isXxx for is read through, which is the other
        -- direction property_of() pairs: a row spelled with the property's own name and a port that carries
        -- exactly the -isXxx the header names are one declaration, and without this the check reads such a
        -- port as carrying nothing at all (AVCaptureVideoPreviewLayer.previewing, whose header declares
        -- getter=isPreviewing and whose port defines -isPreviewing and no selector named -previewing). Only
        -- for a bare name: a member that is itself an accessor is spelled as itself, and property_of() has
        -- already paired it with the property name it belongs to.
        if member:match("^[%a][%w_]*$") and not member:match("^is%u") then
            table.insert(accessors, "is" .. member:sub(1, 1):upper() .. member:sub(2))
        end
        -- and a name that begins with a lower-case acronym keeps its case after "is": NSProcessInfo.h:247-248
        -- declare iOSAppOnMac and iOSAppOnVision with getter=isiOSAppOnMac and getter=isiOSAppOnVision, the
        -- spelling property_of() reads back the other way
        if member:match("^%l%u[%w_]*$") then
            table.insert(accessors, "is" .. member)
        end
        for _, selector in ipairs(accessors) do
            found[string.format("-[%s %s]", class, selector)] = true
            found[string.format("+[%s %s]", class, selector)] = true
        end
        -- and the property names it may be an accessor of, so a row spelled with the getter and a row spelled with
        -- the property's name answer each other whichever way the row is written
        for _, property in ipairs(property_of(member)) do
            found[class .. "." .. property] = true
        end
    end
    local sign, owner, selector = plain:match("^([-+])%[([%w_]+) (.+)%]$")
    if sign then
        found[owner .. "." .. selector] = true
        -- every property name this selector may be an accessor of, so a row spelled with a getter and a row
        -- spelled with the property name are the same declaration to the check and to the generator's rule
        for _, property in ipairs(property_of(selector)) do
            found[owner .. "." .. property] = true
        end
    end
    return found
end

local ORDER = {ignored = 0, owed = 1, absent = 2}

function advice(root, used)
    local listed = registry(root)
    local found = {}
    for api, entry in pairs(listed) do
        if ORDER[entry.status] then
            for spelling in pairs(spellings(api)) do
                local selector = spelling:match("^[-+]%[[%w_]+ (.+)%]$")
                if used[spelling] or (selector and used[selector]) then
                    found[api] = entry
                end
            end
        end
    end
    local named = table.orderkeys(found)
    table.sort(named, function (a, b)
        if ORDER[found[a].status] ~= ORDER[found[b].status] then
            return ORDER[found[a].status] < ORDER[found[b].status]
        end
        return byteorder.less(a, b)
    end)
    local advised = {}
    for _, api in ipairs(named) do
        table.insert(advised, {api = api, status = found[api].status, effect = found[api].effect, introduced = found[api].introduced})
    end
    return advised
end

local function carried_by_release(entry, inventory)
    -- A member the OWNER does not declare can still be answered, because the release carries it on a
    -- superclass, so a test of the owner's own table alone reports the release as lacking it. That
    -- is what made `ignored` unsayable: the check's rule for an `ignored` row is that the release
    -- DOES carry the name, and a row about a member inherited from a superclass was refused with
    -- "ignored because the release carries it, but the release does not" - the check being wrong
    -- rather than the row. Every family inherits members, so this is the check's defect.
    --
    -- UISearchBar.enabled is the case measured end to end, and it is the property branch's setter
    -- spelling that finds it: at 6.1.3 UISearchBar declares neither -enabled, -isEnabled nor
    -- -setEnabled: of its own, its superclass is UIView, and UIView owns -isEnabled and -setEnabled:.
    --
    -- What this does NOT reach, and it is the same measurement: a property whose getter the header
    -- spells getter=isXxx and which the release carries ONLY as that getter is still read as absent,
    -- because this branch asks for the property's own name and its setter and not for the `is` form
    -- that spellings() pairs elsewhere in this file (AVCaptureVideoPreviewLayer.previewing is the
    -- case named there). AVAssetTrack at 6.1.3 owns -isEnabled and no -setEnabled:, and
    -- AVMutableCompositionTrack inherits through AVCompositionTrack from it, so
    -- AVMutableCompositionTrack.enabled reads false here and would be false with the walk too.
    -- Widening the property branch is a separate change with its own row count, and it is measured
    -- with the same harness rather than guessed.
    --
    -- The walk stops at a class this binary's own inventory does not have, because the inventory is
    -- per binary: a superclass carried by another image cannot be read here, and stopping there is
    -- the old answer rather than a wrong one. `seen` guards a cycle, which a malformed image can have.
    local function has(class, selector, sign)
        local wanted = sign == "-" and "instance" or "class"
        local seen = {}
        while class ~= nil and inventory.classes[class] ~= nil and not seen[class] do
            seen[class] = true
            local carried = inventory.classes[class]
            if carried[wanted]["-" .. selector] ~= nil then
                return true
            end
            class = carried.superclass
        end
        return false
    end
    if entry.kind == "class" then
        return inventory.classes[entry.api] ~= nil
    elseif entry.kind == "protocol" then
        return nil
    elseif entry.kind == "method" then
        local sign, class, selector = entry.api:match("^([-+])%[([%w_]+) (.+)%]$")
        if sign ~= nil and inventory.classes[class] == nil and (inventory.protocols or {})[class] ~= nil then
            return nil
        end
        return sign ~= nil and has(class, selector, sign)
    elseif entry.kind == "property" then
        local class, property = entry.api:match("^([%w_]+)%.([%w_]+)$")
        return class ~= nil and (has(class, property, "-") or has(class, "set" .. property:sub(1, 1):upper() .. property:sub(2) .. ":", "-"))
    end
    return nil
end

local function in_range(entry, deployment)
    if not deployment then
        return false
    end
    return not (entry.minimum and dyld.compare_versions(deployment, entry.minimum) < 0)
        and not (entry.maximum and dyld.compare_versions(deployment, entry.maximum) >= 0)
end

-- The registry entry a built name answers to: its own spelling, else the entry of the class that owns it.
-- Exported, not local: modules/apple/backports.lua's own registry_test reads backports.entry_of, and a
-- forward declaration main added reads it too. The inventory is optional and defaults to what the
-- caller has: a name whose class the release itself carries needs a row of its own.
function entry_of(listed, name, inventory)
    for spelling in pairs(spellings(name)) do
        if listed[spelling] then
            return listed[spelling]
        end
    end
    local owner = name:match("^[-+]%[([%w_]+) ") or name:match("^([%u][%w_]*)%.")
    if not owner then
        return nil
    end
    -- A class row answers for the members of a class the port defines wholly. It does not answer for a class
    -- the release itself carries: -[UIView foo] that the port adds in a category is API the port carries, and
    -- UIView's row says nothing about foo, so the member needs its own row (measured 2026-09-28: with the
    -- class row answering, 1,452 members of classes the port carries had no row of their own and passed).
    local carried = inventory and inventory.classes and inventory.classes[owner]
    if carried and carried.image then
        return nil
    end
    return listed[owner]
end

-- The folders whose headers the package declares names in: the package's own, the folders of its libraries, and the generated
-- .gen/<Folder>/ ones, where tools/gen writes a library's protocol header (Charon<Folder>Protocols.h).
local function header_folders(root)
    return {root, path.join(root, "*"), path.join(root, ".gen", "*")}
end

-- Every name the headers the build reads declare: the tree's own - a Charon header, generated or written - and
-- the SDK the package compiled against. A type, an enumeration or a struct has no symbol by nature, so an entry
-- of kind "type" or "case" is implemented when a header declares it, and the declaration is read, never taken on
-- trust: a name no header here or there declares is the same as a class nothing exports. The SDK holds tens of
-- thousands of headers, so its pass is kept beside the caches and read again for nothing.
local function declared_names(root, sdkdir)
    local names, ours = {}, {}
    for _, file in ipairs(os.files(path.join(root, "*.h"))) do
        for word in io.readfile(file):gmatch("[%w_]+") do
            ours[word] = true
        end
    end
    for _, folder in ipairs(header_folders(root)) do
        for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
            for word in io.readfile(file):gmatch("[%w_]+") do
                ours[word] = true
            end
        end
    end
    if sdkdir and os.isdir(sdkdir) then
        -- named by a key over everything its content depends on, the reader included: a tag for how the
        -- words are gathered, so a change here is a different file and nothing is ever invalidated by hand
        -- (the rule dyld.lua's own kept files are written to). Without the tag a fixed SDK path keeps serving
        -- the words an earlier reader gathered - and an earlier reader that gathered none.
        -- named by a key over everything its content depends on: the SDK's own path spelled as text,
        -- and a tag for how the words are gathered. hash.sha256 of a table is the empty-string hash -
        -- opt.sdkdir is a table where the build resolves it - so every SDK's words landed on one 51 MB
        -- file and answered for a header they do not declare. Measured: e3b0c44298fc1c14 is sha256 of
        -- the empty string, and that file was 51,197,631 bytes of a different SDK.
        local spelling = type(sdkdir) == "table" and table.concat(sdkdir, " ") or tostring(sdkdir)
        -- hash.sha256 takes bytes, and a Lua string hashed as one reads as no bytes at all: measured
        -- 2026-09-28, sha256(spelling) is e3b0c44298fc1c14, the empty string, for every SDK - and the
        -- one file that key names was 51,197,631 bytes of some other SDK's words.
        local kept = path.join(dyld.root(), "cache", "sdk-header-names-v1-"
                              .. hash.strhash128(spelling):sub(1, 16) .. ".txt")
        local text = os.isfile(kept) and io.readfile(kept) or nil
        if not text then
            -- os.execv's stdout is a file to write, not a buffer: grep's words go to a temporary file, and
            -- the words themselves are kept in the cache by io.writefile, which is what this tree has
            local found = os.tmpfile()
            for _, folder in ipairs({path.join(sdkdir, "usr/include"), path.join(sdkdir, "System/Library/Frameworks")}) do
                if os.isdir(folder) then
                    os.execv("grep", {"-rhoE", "[A-Za-z_][A-Za-z0-9_]*", folder}, {stdout = found})
                end
            end
            text = io.readfile(found) or ""
            os.tryrm(found)
            io.writefile(kept, text)
        end
        for word in text:gmatch("[%w_]+") do
            names[word] = true
        end
    end
    -- table.keys, not pairs: xmake's pairs(t) calls t:pairs() when t has a field of that name, and a header
    -- of this package holds the word "pairs" (HomeKit's CharonHapCrypto.h), so ours.pairs is true and pairs(ours)
    -- raised "attempt to call a boolean value (method 'pairs')" - the stack 14 gate at 6.1.3, the first run
    -- with a type row to ask
    for _, word in ipairs(table.keys(ours)) do
        names[word] = true
    end
    return names
end

-- Whether the protocol a member's owner names is declared - with a body, not a forward declaration - by a
-- header this package installs or by the SDK the backport is compiled against. The owner's being a protocol
-- is not the answer: a protocol nothing declares answers nothing, and the member of one is then implemented
-- nowhere. The release's own inventory answers for a protocol the release itself carries.
local SDK_DECLARATIONS = {}

-- The SDK's own protocol declarations, once per SDK: 51 MB of words over tens of thousands of headers, and
-- the SDK at a given path does not change under us. Keyed by that path and nothing else.
function sdk_protocol_declarations(sdkdir)
    if not sdkdir or not os.isdir(sdkdir) then
        return {}
    end
    local seen = SDK_DECLARATIONS[sdkdir]
    if not seen then
        seen = {}
        local function scan(folder)
            for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
                for line in io.lines(file) do
                    for protocol in line:gmatch("@protocol%s+([%w_]+)") do
                        if not line:find("@protocol%s+" .. protocol .. "%s*;") then
                            seen[protocol] = true
                        end
                    end
                end
            end
        end
        scan(path.join(sdkdir, "usr/include"))
        -- every framework, resolved: one of them is a symlink into the Cryptex, and os.files does not
        -- follow a symlinked directory, so the glob missed its headers and the protocols in them
        for _, framework in ipairs(os.dirs(path.join(sdkdir, "System/Library/Frameworks", "*"))) do
            local resolved = framework
            if os.islink(framework) then
                local target = os.readlink(framework) or ""
                if target:sub(1, 1) ~= "/" then
                    target = path.join(path.directory(framework), target)
                end
                resolved = path.absolute(target)
            end
            scan(path.join(resolved, "Headers"))
        end
        SDK_DECLARATIONS[sdkdir] = seen
    end
    return seen
end

-- Whether the protocol a member's owner names is declared - with a body, not a forward declaration - by a
-- header this package installs or by the SDK the backport is compiled against. The owner's being a protocol is
-- not the answer: a protocol nothing declares answers nothing, and the member of one is then implemented
-- nowhere (ef271700 on ARKit, 5a505a9b on MXDiagnostic). The release's own inventory answers for a protocol
-- the release itself carries. The tree's own headers are read every call: 87 files, and they change under a
-- build, which a memo keyed on the folder cannot see.
-- Whether a header of the package defines the function with a body, in the shape a real definition has:
-- a return type, the name, a balanced (…), then a brace - with whatever sits between the parameter list and
-- the brace, a CF_REFINED_FOR_SWIFT or a CF_SWIFT_UNAVAILABLE("..."), being an attribute. Apple's own inlines
-- are not counted: an SDK inline is Apple's code in the consumer and the port carries none of it, and a
-- declaration without a body is not a definition. The name is the registry's spelling without its ().
-- This reads and writes nothing: it cannot reorder a declaration, and a header that stops compiling is a
-- different check.
function inline_bodies_of(root)
    local seen = {}
    -- a definition, with the comments stripped and the whitespace folded, so whatever sits between the
    -- parameter list and the brace - a CF_REFINED_FOR_SWIFT, a CF_SWIFT_UNAVAILABLE("...") - is an attribute
    local function normalise(text)
        text = text:gsub("/%*.-%*/", " "):gsub("//[^\n]*", " ")
        return (text:gsub("%s+", " "))
    end
    for _, folder in ipairs(header_folders(root)) do
        for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
            for before, after in normalise(io.readfile(file) or ""):gmatch(
                    "([%w_<>%* ]+)%s+([%w_]+)%s*%b()%s*[%w_(),\"%s]*{") do
                seen[after] = true
            end
        end
    end
    return seen
end

function protocol_declared(root, owner, inventory, sdkdir)
    if inventory and inventory.protocols and inventory.protocols[owner] ~= nil then
        return true
    end
    if sdk_protocol_declarations(sdkdir)[owner] then
        return true
    end
    for _, folder in ipairs(header_folders(root)) do
        for _, file in ipairs(os.files(path.join(folder, "*.h"))) do
            for line in io.lines(file) do
                for protocol in line:gmatch("@protocol%s+([%w_]+)") do
                    if protocol == owner and not line:find("@protocol%s+" .. protocol .. "%s*;") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- The registry check as build() runs it, in one place: release_inventory takes the cache directory and
-- nothing else, and check_registry the SDK the objects were compiled against. A test that calls this with
-- build()'s own option shape is what keeps a wrong argument here from reaching a gate: the light guard's
-- fixtures call check_registry directly and never did.
-- Every protocol a header the package installs declares with a body, and every one it only names.
-- Objective-C emits a protocol's metadata into the image that uses or adopts it, and the runtime
-- deduplicates it, so a library need not carry a protocol for a caller to get it: what a caller needs is
-- the declaration, and a forward declaration (@protocol X;) is not one.
function declared_protocols(root)
    local declared = {}
    for _, pattern in ipairs({"*.h", "*/*.h", path.join(".gen", "*", "*.h")}) do
        for _, file in ipairs(os.files(path.join(root, pattern))) do
            for line in io.lines(file) do
                for name in line:gmatch("@protocol%s+([%w_]+)") do
                    if not line:find("@protocol%s+" .. name .. "%s*;") then
                        declared[name] = true
                    end
                end
            end
        end
    end
    return declared
end

-- EVERY SPELLING check_registry ASKS A ROW BY, keyed true: a property row is written `Class.name` and asked as
-- `-[Class name]`, a method row is written `-[Class selector:]` and asked as itself, and spellings() is the
-- one place that knows both directions. carried_api() below needs this, because the spelling a protocol's
-- method list produces is always a `-[Class selector:]` one even when the row that claims it is a property.
function documented_names(root)
    local listed = registry(root)
    local names = {}
    for api in pairs(listed) do
        for spelling in pairs(spellings(api)) do
            names[spelling] = true
        end
    end
    return names
end

function registry_step(opt, built, complete, exports)
    return check_registry(opt.root, built, complete, opt.deployment, exports,
                          release_inventory(opt.cache), opt.sdkdir, declared_protocols(opt.root))
end

function check_registry(root, found, complete, deployment, exports, inventory, sdkdir, declared)
    local listed, incomplete = registry(root)
    local unlisted, undocumented = {}, {}
    -- per call, not a module global: an earlier check in the same process filled it from a tree with no SDK
    -- and the next one reused that answer instead of asking declared_names about its own
    local declared_by_header
    local inline_bodies
    for _, carried in ipairs({found.classes, found.members, found.symbols}) do
        for name in pairs(carried) do
            -- the protocol metadata symbols answer for the protocol rows and are not API of their own
            local protocol_metadata = name:startswith("_OBJC_PROTOCOL_$_") or name:startswith("_OBJC_LABEL_PROTOCOL_$_")
            if not protocol_metadata and not entry_of(listed, name, inventory) then
                table.insert(unlisted, name)
            end
        end
    end
    -- What is built under an absent row answers it, which is a refusal. What is built under an owed row is a stand-in:
    -- the real behaviour is owed, and the stand-in is a visible fact the check reports as a note, never as an error.
    local answered, stand_ins = {}, {}
    for name, entry in pairs(listed) do
        if entry.status == "absent" or entry.status == "owed" then
            local present = entry.kind == "class" and found.classes[name] or false
            present = present or ((entry.kind == "constant" or entry.kind == "function") and found.symbols[name:gsub("%(%)$", "")]) or false
            for spelling in pairs(spellings(name)) do
                present = present or (spelling:match("^[-+]%[") and (found.answered or {})[spelling]) or false
            end
            if present then
                table.insert(entry.status == "absent" and answered or stand_ins, name)
            end
        end
    end
    local held, missing = {}, {}
    if inventory then
        for name, entry in pairs(listed) do
            local natively = deployment and entry.introduced and dyld.compare_versions(deployment, entry.introduced) >= 0
            if (entry.status == "absent" or entry.status == "owed") and in_range(entry, deployment) and not natively and carried_by_release(entry, inventory) then
                table.insert(held, name)
            elseif entry.status == "ignored" and in_range(entry, deployment) and carried_by_release(entry, inventory) == false then
                table.insert(missing, name)
            end
        end
    end
    local unbuilt = {}
    -- What the owner-class line below takes on trust, kept where a reader can see it: an `implemented` member
    -- row that no member answers and that the class being exported answers on its own. It is right for the five
    -- ways a port answers a member with no method of its own - the release's own class above the port's
    -- (-init and +new are NSObject's), a member inherited from a superclass, a class the port publishes by
    -- alias and lays no metadata of out, a protocol's requirement answered by its declaration, a type or a case
    -- a header declares - and wrong for the sixth, a row with nothing behind it. Measured 2026-10-04 over the 69
    -- libraries of the 6.1.3 gate on land-w26: 213 rows stand in that state, 128 of them -init and +new, and 43
    -- name a selector no source file of the tree spells at all. So every run names them, and the count is what
    -- says whether the five ways are being read as the sixth: a note and not a refusal, because the population
    -- belongs to the frameworks that own those rows - Metal, MPSGraph, UIKit, Vision, CoreImage, Foundation,
    -- AVFoundation, HomeKit - and a refusal would refuse their next gate rather than this row's. Each of them is
    -- a row to make true or a status to set, and the list says which, once per run, by name.
    local class_only = {}
    if complete ~= false then
        for name, entry in pairs(listed) do
            local built, by_member = false, false
            for spelling in pairs(spellings(name)) do
                built = built or found.classes[spelling] or found.members[spelling] or found.symbols[spelling] or false
                by_member = by_member or (found.members[spelling] or false)
            end
            local owner = name:match("^[-+]%[([%w_]+) ") or name:match("^([%u][%w_]*)%.")
            local by_owner = (owner and found.classes[owner]) or false
            built = built or by_owner or false
            built = built or (entry.kind == "class" and (found.registered or {})[name]) or false
            local carried = deployment and entry.introduced and dyld.compare_versions(entry.introduced, deployment) <= 0
            carried = carried or (exports and exports["_" .. name:gsub("%(%)$", "")]) or false
            local ours = not deployment or in_range(entry, deployment)
            -- A protocol has no accessors, so nothing else in this loop can answer for it: the row is
            -- implemented when the objects carry the protocol's own metadata and it names.
            -- a protocol row is answered by a declaration a caller compiles against: a header this package installs,
            -- or the SDK, or the release itself - the same three protocol_declared asks for a member's owner
            local declared = entry.kind == "protocol" and ((declared or {})[name] or protocol_declared(root, name, inventory, sdkdir)) or
                (owner and listed[owner] and listed[owner].kind == "protocol" and
                 protocol_declared(root, owner, inventory, sdkdir)) or
                (owner and inventory and inventory.protocols and inventory.protocols[owner] ~= nil) or false
            -- where the three answers below did not answer it and the class did, which is the one case the note
            -- is for: a row the check asked about, in this band, that no member and no declaration carries
            if entry.status == "implemented" and by_owner and by_member == false and ours and not carried and not declared then
                table.insert(class_only, name)
            end
            if entry.kind == "function" and not built then
                -- the port's own body, in a header of the package: a symbol will never answer for an inline,
                -- and Apple's own inlines are not counted - an SDK inline is Apple's code in the consumer
                inline_bodies = inline_bodies or inline_bodies_of(root)
                local bare = (name:gsub("%(%)$", ""))
                if inline_bodies[bare] then
                    built = true
                end
            end
            if (entry.kind == "type" or entry.kind == "case") and not built then
                -- no symbol will ever answer for a type or an enumeration case, so the header is the build
                declared_by_header = declared_by_header or declared_names(root, sdkdir)
                built = declared_by_header[name] or false
            end
            if entry.status == "implemented" and not built and not carried and ours and not declared then
                table.insert(unbuilt, name)
            elseif entry.status == "implemented" and not entry.facts then
                table.insert(undocumented, name)
            end
        end
    end
    byteorder.sort(unlisted)
    byteorder.sort(unbuilt)
    byteorder.sort(answered)
    byteorder.sort(stand_ins)
    byteorder.sort(held)
    byteorder.sort(missing)
    byteorder.sort(class_only)
    -- printed before any refusal below, so a red registry still shows its stand-ins: the real behaviour is owed, and the
    -- build answering the name is a visible fact, never a refusal and never hidden
    if #stand_ins > 0 then
        cprint("${color.warning}note:${clear} %d owed rows have a stand-in built (the real behaviour is owed)", #stand_ins)
        for _, name in ipairs(stand_ins) do
            cprint("  ${color.warning}%s${clear}", name)
        end
    end
    if #unlisted > 0 or #unbuilt > 0 or #answered > 0 or #held > 0 or #missing > 0 or #incomplete > 0 then
        local lines = {"the registry does not describe what the backports carry:"}
        for _, described in ipairs(incomplete) do
            table.insert(lines, "  " .. described)
        end
        if #unlisted > 0 then
            table.insert(lines, "  built, but no entry in registry/: " .. table.concat(unlisted, "; "))
        end
        if #unbuilt > 0 then
            table.insert(lines, "  listed as implemented, but nothing of that name is built: " .. table.concat(unbuilt, "; "))
        end
        if #answered > 0 then
            table.insert(lines, "  listed as absent, but what is built answers it: " .. table.concat(answered, "; "))
        end
        if #held > 0 then
            table.insert(lines, "  listed as absent, but the release carries it itself, so it is the release's own and not absent: " .. table.concat(held, "; "))
        end
        if #missing > 0 then
            table.insert(lines, "  listed as ignored because the release carries it, but the release does not: " .. table.concat(missing, "; "))
        end
        raise(table.concat(lines, "\n"))
    end
    -- two counts, and the second is the note the owner-class line above earns its place with: the entries with
    -- no file of facts, and the member rows only their exported class answers
    return #undocumented, #class_only, class_only, stand_ins
end


-- The names one object carries as API: its exported classes, functions and constants, and the members
-- its categories add. An object that carries none is a helper of the objects that do.
local function carried_names(object, architecture)
    local names, ours = {}, {}
    for _, symbol in ipairs(exported_symbols(object)) do
        local class = symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
        if class then
            ours[class] = true
        end
        names[class or symbol:sub(2)] = true
    end
    for _, member in ipairs(added_members(objc.binary_inventory(object, architecture), ours)) do
        names[member] = true
    end
    return table.orderkeys(names)
end

local function lower(a, b)
    if a == nil or b == "" then
        return b
    end
    if a == "" or b == nil then
        return a
    end
    return dyld.compare_versions(a, b) <= 0 and a or b
end

local LADDERS = {}

-- The cache ladder for one architecture, oldest release first: dyld.held_ladder(), which
-- release-split.lua walks as well, so this check answers to the same measurement instead of a
-- second copy of it.
local function ladder(architecture)
    LADDERS[architecture] = LADDERS[architecture] or dyld.held_ladder(compatible(architecture))
    return LADDERS[architecture]
end

-- The release each of symbols first-appears exporting, walking the real cache ladder oldest to newest --
-- the same measurement release-split.lua makes, not the SDK header's own availability annotation.
-- A header can name a later release than the one that actually already exports the symbol (measured
-- for UIKeyboardIsLocalUserInfoKey: the SDK 16.4 header says ios(9.0), the real armv7 cache of 8.0
-- already exports it), and this function exists so the same object-splitting rule answers to the
-- fact, not the annotation. A symbol counts only where a client binds it, in the library the SDK
-- puts it in (dyld.exported_at). {symbol = release}, with no entry for a symbol no held release
-- exports, where the header/registry fallback in releases_in() below is the only source left.
local function measured_introduced(opt, symbols)
    return dyld.first_releases(ladder(opt.architecture), opt.sdkdir, symbols)
end

-- The release from which a band links no object of a file although the registry places that file at
-- or below the deployment: band() re-exports the release's own symbols and leaves the object out
-- from the release that first exports ALL of its API on, and no registry field says so. Defined
-- below, beside the measurement it is made of.
local reexported_from

-- The latest release a band can be opened on: the last one the firmware catalog holds for the
-- architectures an armv7 build is compatible with, which is the same list band_plan() picks a band's
-- first release out of. A release past it has no band, so band() is never asked about it and a build
-- of this machine never links one.
local function last_openable(architecture)
    local last
    for _, one in ipairs(compatible(architecture)) do
        for _, version in ipairs(firmware.versions(one)) do
            if not last or dyld.compare_versions(version, last) > 0 then
                last = version
            end
        end
    end
    return last
end

local function latest(a, b)
    if a == nil or a == "" then
        return b
    end
    if b == nil or b == "" then
        return a
    end
    return dyld.compare_versions(a, b) >= 0 and a or b
end

-- The release each object is carried from, {object = version}: the `minimum` of the registry entries
-- its API answers to, and no key for an object without one. An object whose entries name different
-- minimums (an entry without one names none) is refused, as misplaced() refuses mixed releases: the
-- earliest would carry API below its minimum, the latest would drop API the registry carries earlier.
-- A helper takes the lowest minimum among the objects that name a symbol it defines (nm -u), through
-- other helpers as well; the third answer lists the objects that carry nothing the registry can place
-- and that no object names, such as an installer whose +load adds its API at run time. Such an object
-- takes the highest minimum among the objects it names, through others of its kind as well, since it
-- links only where every one of them is carried; the fourth answer says which, {object = {minimum,
-- from, symbol}}. With nothing to take, every band keeps it. An object the registry or its callers
-- place below an object it names is refused as well: it would not link in the bands between. A minimum
-- at or below the deployment bounds nothing, so it mixes with none.
--
-- The floor is the registry's `minimum` or, where the registry says none, the release from which
-- band() itself leaves the object out, which is what a definer this build's callers reach actually
-- is: the definer's API is what the release exports, so no band links it from that release on while
-- every band still links its callers. A definer the release exports nothing of is in every band, as
-- before, and a name the release binds at or before the same release is nothing for the definer to
-- provide, so neither is a trap.
function minimums(listed, objects, architecture, deployment, opt)
    local found, problems, bounds, helpers = {}, {}, {}, {}
    for _, object in ipairs(objects) do
        local names = carried_names(object, architecture)
        if #names == 0 then
            table.insert(helpers, object)
        else
            local by, order = {}, {}
            for _, name in ipairs(names) do
                local entry = entry_of(listed, name)
                if entry then
                    local minimum = entry.minimum or ""
                    if minimum ~= "" and deployment and dyld.compare_versions(minimum, deployment) <= 0 then
                        minimum = ""
                    end
                    if not by[minimum] then
                        by[minimum] = {}
                        table.insert(order, minimum)
                    end
                    table.insert(by[minimum], name)
                end
            end
            if #order > 1 then
                table.sort(order, function (a, b) return lower(a, b) == a and a ~= b end)
                local described = {}
                for _, minimum in ipairs(order) do
                    table.insert(described, string.format("%s with %s", table.concat(by[minimum], " "), minimum == "" and "no registry minimum" or ("registry minimum " .. minimum)))
                end
                table.insert(problems, string.format("%s defines %s; an object is carried from one release on, so split it", path.filename(object), table.concat(described, " and ")))
            end
            bounds[object] = #order == 1 and order[1] or ""
        end
    end
    local definer, helper = {}, {}
    for _, object in ipairs(objects) do
        for _, symbol in ipairs(defined_symbols(object, true)) do
            definer[symbol] = object
        end
    end
    for _, object in ipairs(helpers) do
        helper[object] = true
    end
    local changed = true
    while changed do
        changed = false
        for _, object in ipairs(objects) do
            if bounds[object] then
                for _, symbol in ipairs(undefined_symbols(object)) do
                    local named = definer[symbol]
                    if named and named ~= object and helper[named] then
                        local bound = lower(bounds[named], bounds[object])
                        if bound ~= bounds[named] then
                            bounds[named] = bound
                            changed = true
                        end
                    end
                end
            end
        end
    end
    local unreached = {}
    for _, object in ipairs(objects) do
        if bounds[object] == nil then
            table.insert(unreached, object)
        elseif bounds[object] ~= "" then
            found[object] = bounds[object]
        end
    end
    local needs, inherited = {}, {}
    for _, object in ipairs(unreached) do
        needs[object] = undefined_symbols(object)
    end
    changed = true
    while changed do
        changed = false
        for _, object in ipairs(unreached) do
            for _, symbol in ipairs(needs[object]) do
                local named = definer[symbol]
                local minimum = named and named ~= object and found[named]
                if minimum and (not found[object] or dyld.compare_versions(minimum, found[object]) > 0) then
                    found[object] = minimum
                    inherited[object] = {minimum = minimum, from = named, symbol = symbol}
                    changed = true
                end
            end
        end
    end

    -- The release every object of this build stops being linked from, and the release each name is
    -- bound by itself from, both measured over the held ladder the way band() decides the same
    -- question. An object the release exports none of the API of is in every band, which is what a
    -- nil answer here means, and a definer's floor alone says nothing about whether its callers are
    -- still linked to reach it.
    local dropped, exported = {}, {}
    local openable = opt and last_openable(architecture) or nil
    if opt then
        local wanted = {}
        for _, object in ipairs(objects) do
            if bounds[object] ~= nil then
                for _, symbol in ipairs(exported_symbols(object)) do
                    wanted[symbol] = true
                end
                for _, symbol in ipairs(needs[object] or undefined_symbols(object)) do
                    local other = definer[symbol]
                    if other and other ~= object then
                        wanted[symbol] = true
                    end
                end
            end
        end
        exported = measured_introduced(opt, table.orderkeys(wanted))
        for _, object in ipairs(objects) do
            if bounds[object] ~= nil then
                dropped[object] = reexported_from(exported, object)
            end
        end
    end

    local unreachable = {}
    for _, object in ipairs(objects) do
        local minimum_of = found[object]
        local dropped_from = dropped[object]
        for _, symbol in ipairs(needs[object] or undefined_symbols(object)) do
            local named = definer[symbol]
            local minimum = named and named ~= object and found[named]
            local from
            if not minimum and named and named ~= object then
                from = dropped[named]
                local bound = exported[symbol]
                if from and bound and dyld.compare_versions(bound, from) <= 0 then
                    from = nil
                end
            end
            if minimum and (not minimum_of or dyld.compare_versions(minimum, minimum_of) > 0) then
                table.insert(problems, string.format("%s is carried %s and names %s, which %s defines only from %s on; it would not link below that, so give its entries that minimum or move the symbol to a file of its own",
                                                     path.filename(object), minimum_of and ("from " .. minimum_of) or "by every band", symbol, path.filename(named), minimum))
            end
            -- The same refusal where the registry places the definer nowhere, and for the
            -- objects the registry places nowhere either - a helper is carried by every band, so
            -- this is the caller it usually is. A band from the release the definer stops being
            -- linked from, and below the release this caller stops being linked from, would link the
            -- caller without it. A caller the release exports all of its API from below that release
            -- is never linked there, which is what a nil dropped[object] or an empty interval says.
            if from and deployment then
                local first = latest(minimum_of, from)
                if not dropped_from or dyld.compare_versions(first, dropped_from) < 0 then
                    if not openable or dyld.compare_versions(first, openable) <= 0 then
                        table.insert(problems, string.format("%s is carried %s and names %s, which %s defines only from %s on, the release it exports itself from; a band at or above that release would link this object without it, so give its entries that minimum or move the symbol to a file of its own",
                                                             path.filename(object), minimum_of and ("from " .. minimum_of) or "by every band", symbol, path.filename(named), from))
                    else
                        table.insert(unreachable, string.format("%s names %s, which %s defines only from %s on, and the band that would link this object without it starts at iOS %s, past the last firmware in the catalog for %s",
                                                                 path.filename(object), symbol, path.filename(named), from, first, architecture))
                    end
                end
            end
        end
    end
    local kept = {}
    for _, object in ipairs(unreached) do
        if not found[object] then
            table.insert(kept, object)
        end
    end
    return found, problems, kept, inherited, unreachable
end

function build(opt)
    -- the generated layer is written first, so registry() and sources() read a .gen/ that is current; a root with no spec/ is refused here
    generate(opt.root)
    INVENTORY_STORE = opt.store
    local release = loaded(opt.cache, opt.architecture)
    opt = table.join(opt, {triple = opt.architecture .. "-apple-ios" .. opt.deployment})
    -- What the run spent, in the run's own output. A build that prints only its verdict cannot be
    -- improved: the split of compile, link and checks is what says where a machine's time went,
    -- and it is only comparable between runs if every run measures it the same way. The first
    -- number is compiles this run made and the second is objects it holds, and they differ by
    -- however much the compiler cache served - a line that said "compiled 969 objects in 0.4s"
    -- would be the one number a band would quote and the one that would be wrong.
    COMPILED = 0
    local compiling = os.mclock()
    local attach, objects, origins, minimums = compiled(opt)
    opt = table.join(opt, {origins = origins, minimums = minimums})
    local compiled_at = os.mclock()
    local compiled, placed = COMPILED, 0
    for _, library in ipairs(staged_libraries(opt)) do
        placed = placed + (objects[library.name] and #objects[library.name] or 0)
    end
    check_releases(opt, objects, origins)
    local checked_at = os.mclock()
    -- generated rows of a folder no library builds are not implementations: said here in full, by folder and count, not dropped
    local _, _, _, unlibraried = registry(opt.root)
    if #unlibraried > 0 then
        local rows, named = 0, {}
        for _, item in ipairs(unlibraried) do
            rows = rows + item.rows
            table.insert(named, string.format("%s (%d)", item.folder, item.rows))
        end
        cprint("${color.warning}note:${clear} %d generated row(s) in %d folder(s) with no library are not implemented, as no library builds the folder (generated, no library): %s",
               rows, #unlibraried, table.concat(named, ", "))
    end
    local built = {}
    for _, library in ipairs(staged_libraries(opt)) do
        table.insert(built, link(opt, library, attach, objects[library.name], {release}, opt.outputdir,
                                 {cache = opt.cache, release = opt.deployment}))
    end
    local linked_at = os.mclock()
    dyld.check(opt.cache, built)
    check_categories(release, release_inventory(opt.cache), built, opt.architecture, opt.deployment)
    if #built == #LIBRARIES then
        check_band_caches(opt, objects)
        -- registry_step, not check_registry: it hands the check the SDK the objects were compiled against and the
        -- protocols the headers declare, without which every member of a protocol the SDK declares reads unbuilt
        local undocumented, class_only, class_only_names = registry_step(opt, surface(built, opt.architecture,
            declared_protocols(opt.root), documented_names(opt.root)), opt.registry, release.exports)
        if undocumented > 0 then
            cprint("${color.warning}note:${clear} %d of the registry's entries name no file of facts yet", undocumented)
        end
        if class_only > 0 then
            -- in full, one per line and sorted: every name here is a row whose owner class is exported and whose
            -- member nothing in the build carries, so the class alone is what answers it. The count is the trend
            -- and the names are the work, and neither is a failure until the frameworks that own them say so.
            cprint("${color.warning}note:${clear} %d implemented member row(s) are answered by their owner class alone," ..
                   " with no member of that name in the build:", class_only)
            for _, name in ipairs(class_only_names or {}) do
                cprint("  ${color.warning}%s${clear}", name)
            end
        end
    end
    print(string.format("build: %s compiled %d of %d objects in %.1fs, measured their releases in %.1fs, linked %d libraries in %.1fs, checked in %.1fs",
                        opt.deployment, compiled, placed, (compiled_at - compiling) / 1000,
                        (checked_at - compiled_at) / 1000, #built, (linked_at - checked_at) / 1000,
                        (os.mclock() - linked_at) / 1000))
    return built
end

function introduced_version(dump, name)
    local found, current
    for line in dump:gmatch("[^\n]+") do
        local dumping = line:match("^Dumping (.-):$")
        if dumping then
            current = dumping
        elseif current == name then
            local version = line:match("^[|`]%-AvailabilityAttr.- ios (%d+[%.%d]*) ")
            if version and (not found or dyld.compare_versions(version, found) < 0) then
                found = version
            end
        end
    end
    return found
end

function availability_names(symbols)
    local names = {}
    for _, symbol in ipairs(symbols) do
        names[symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
              or symbol:match("^_OBJC_IVAR_%$_(.-)%.") or symbol:sub(2)] = true
    end
    return names
end

local LISTED = {}

local function listed(root)
    LISTED[root] = LISTED[root] or registry(root)
    return LISTED[root]
end

-- The sources whose registry minimum is above the deployment, {source = {minimum, object}}: a band
-- below that release neither compiles nor keeps them, and the bands from it on carry the object
-- compiled for the minimum itself. Which entries an object answers to is known only once it is
-- compiled, so below the highest minimum the registry names, every source is compiled once for that
-- release first; a deployment at or above it has every source in range and compiles nothing extra.
-- The libraries this run keeps, for the reason keeps() gives: a source of a library the run drops
-- is not this run's to place.
--
-- WHAT THIS FUNCTION IS ALSO THE ONLY PLACE minimums() IS ASKED, and therefore where its refusals are
-- made: a run whose deployment is at or above the highest minimum the registry names returns at the
-- top of this function, compiles nothing for a floor and asks nothing. That is this function's own
-- scope since before the release-export floor was added to minimums() (a band-placement check needs
-- objects placed at a floor to have anything to say), and the deployment such a run builds is a band
-- no trap below it reaches - but it is a hole, and it is named here rather than left for a reader to
-- find: a build at or above the highest registry minimum runs no placement check of any kind.
function floors(opt)
    local top
    for _, entry in pairs(listed(opt.root)) do
        if entry.minimum and dyld.compare_versions(entry.minimum, opt.deployment) > 0 and (not top or dyld.compare_versions(entry.minimum, top) > 0) then
            top = entry.minimum
        end
    end
    if not top then
        return {}
    end
    local function at(release)
        return table.join(opt, {deployment = release, triple = opt.architecture .. "-apple-ios" .. release})
    end
    local objects, origins, pending = {}, {}, {}
    for _, library in ipairs(staged_libraries(opt)) do
        for _, source in ipairs(sources(opt.root, library)) do
            local object = path.join(opt.builddir, "objects-" .. top, library.folder, path.basename(source) .. ".o")
            os.mkdir(path.directory(object))
            table.insert(pending, {opt = at(top), source = source, object = object})
            table.insert(objects, object)
            origins[object] = source
        end
    end
    compile_all(opt, pending)
    local found, problems, unreached, inherited, unreachable = minimums(listed(opt.root), objects, opt.architecture, opt.deployment, opt)
    if #problems > 0 then
        raise("%d objects cannot be placed by their registry minimum above iOS %s:\n  %s", #problems, opt.deployment, table.concat(problems, "\n  "))
    end
    if #unreachable > 0 then
        cprint("${color.warning}note:${clear} %d object(s) name a definition no band of this machine links, the release that exports the definers' API having no firmware in the catalog: %s",
               #unreachable, table.concat(unreachable, "\n  "))
    end
    local taken = {}
    for _, object in ipairs(objects) do
        local from = inherited[object]
        if from then
            table.insert(taken, string.format("%s (%s, from %s by %s)", path.filename(origins[object]), from.minimum, path.filename(origins[from.from]), from.symbol))
        end
    end
    if #taken > 0 then
        cprint("${color.warning}note:${clear} %d objects carry no API the registry can place and take the highest minimum of the objects they name: %s",
               #taken, table.concat(taken, " "))
    end
    if #unreached > 0 then
        local named = {}
        for _, object in ipairs(unreached) do
            table.insert(named, path.filename(origins[object]))
        end
        cprint("${color.warning}note:${clear} %d objects carry no API the registry can place and no other object names them, so every band from iOS %s keeps them: %s",
               #named, opt.deployment, table.concat(named, " "))
    end
    local placed, pending = {}, {}
    for _, object in ipairs(objects) do
        local minimum = found[object]
        if minimum and dyld.compare_versions(minimum, opt.deployment) > 0 then
            local source = origins[object]
            if minimum ~= top then
                object = path.join(opt.builddir, "objects-" .. minimum, path.filename(path.directory(object)), path.filename(object))
                os.mkdir(path.directory(object))
                table.insert(pending, {opt = at(minimum), source = source, object = object})
            end
            placed[source] = {minimum = minimum, object = object}
        end
    end
    compile_all(opt, pending)
    return placed
end

-- The release from which band() links no object of this one, and nil when it never does: the
-- latest of the releases that first export each of the object's API symbols, since band() re-exports
-- the release's own symbols and leaves the object out only where the release exports all of them
-- (measured_introduced()'s own answer, the one tools/release-split.lua makes), and nothing at all
-- for an object no held release exports anything of - an object with no API symbol is in every band
-- by definition, which is the case where reexported_from() returns nil for want of a symbol.
function reexported_from(first, object)
    local from
    for _, symbol in ipairs(exported_symbols(object)) do
        local release = first[symbol]
        if not release then
            return nil
        end
        if not from or dyld.compare_versions(release, from) > 0 then
            from = release
        end
    end
    return from
end

-- The releases one object's exported API arrived in, {version = {names}}, and the names no source
-- can place at all. Measured, not judged: an object mixing releases is reported by the caller, so
-- one pass can name every such object instead of stopping at the first. A name arrives with the
-- first of its symbols: a release can export a class without its metaclass (NaturalLanguage of
-- 12.0 exports _OBJC_CLASS_$_NLTokenizer, and its metaclass only from 16.0), and the class is the API.
-- What releases_in() measures of one object before the registry is asked: its names in the order
-- of its symbols, and for each the release the held caches or the SDK's header place it at, or false.
-- It is a function of the object, the source and the headers it was compiled from and the held
-- ladder, so an object of the store keeps it beside itself; the registry, which a stack changes
-- more often than any of those, is asked again every time.
local function measured_names(opt, source, object)
    local file
    if opt.store and KEYS[object] then
        local signature = {}
        for _, step in ipairs(ladder(opt.architecture)) do
            table.insert(signature, step.release .. "=" .. step.architecture .. "=" .. step.source)
        end
        -- the measurement's own inputs (its code, the SDK's .tbd files, the rungs), and this file, whose
        -- rules name the symbols and read the header's answer
        local key = hash.strhash128("charon-releases-2\n" .. KEYS[object] .. "\n" .. opt.sdkdir .. "\n" .. table.concat(signature, "\n")
                                    .. "\n" .. dyld.first_release_key(ladder(opt.architecture), opt.sdkdir) .. "\n" .. own_text())
        file = path.join(opt.store, "releases", key:sub(1, 2), key .. ".lua")
        local saved = os.isfile(file) and io.load(file)
        if saved then
            os.touch(file)
            return saved.names, saved.earliest
        end
    end
    local names, earliest = {}, {}
    local symbols = exported_symbols(object)
    local first = measured_introduced(opt, symbols)
    for _, symbol in ipairs(symbols) do
        local name = symbol:match("^_OBJC_CLASS_%$_(.+)$") or symbol:match("^_OBJC_METACLASS_%$_(.+)$")
                     or symbol:match("^_OBJC_IVAR_%$_(.-)%.") or symbol:sub(2)
        if earliest[name] == nil then
            table.insert(names, name)
            earliest[name] = false
        end
        local version = first[symbol]
        if version and (not earliest[name] or dyld.compare_versions(version, earliest[name]) < 0) then
            earliest[name] = version
        end
    end
    for _, name in ipairs(names) do
        if not earliest[name] then
            -- The include roots the compile of this source had, archives' included: a source that
            -- imports an archive's header (CharonMLCGraph.mm: <ggml/ggml.h>) does not parse without them,
            -- and the dump of a file that does not parse is empty, so the symbol got no release.
            local includes = {}
            for _, flag in ipairs(compile_arguments(opt, source)) do
                if flag:startswith("-I") then
                    table.insert(includes, flag)
                end
            end
            -- The dump PARSES the source, and a source whose rows carry it from a later release than
            -- this band's does not parse for this band: SDK 16.4's Matter.h declares a strong
            -- dispatch_queue_t, which is no object before iOS 6, so parsing a Matter source for 4.3 is
            -- `property with 'retain (or strong)' attribute must be of object type` and the run dies on
            -- the parse rather than on anything it was asked to check. It is therefore parsed at the release
            -- its own rows place it at, which is the compile floors() already made of it and the reason
            -- protocol_sources() gives for the same headers and the same property (its comment names
            -- ARKit's ARSession.h).
            --
            -- The dump itself DOES depend on the deployment target - Accelerate's CharonLAObject is 0 lines
            -- of AST at 4.3 and 22 at 6.0, which is this tree's own OS_OBJECT_DECL case from
            -- CharonLinearAlgebra.h:4-8, that macro reading __IPHONE_OS_VERSION_MIN_REQUIRED - and that is
            -- why the answer is the same at both: what introduced_version() reads is an AVAILABILITY
            -- ANNOTATION, a property of the header's text, and no declaration in this tree or in the 16.4
            -- SDK's Matter headers is gated on __IPHONE_OS_VERSION_MIN_REQUIRED, whose only appearances here
            -- are prose. Where the old parse succeeded it read the same header and got the same value; where
            -- it failed it produced no value at all, so this can add a date and cannot move one. The release
            -- an object is PLACED in comes from its registry minimum either way - this number reaches only
            -- arrived() and later_than(), the keep-versus-reexport decision.
            local minimum = opt.minimums and opt.minimums[object]
            local at = opt
            if minimum and minimum ~= "" and opt.deployment and dyld.compare_versions(minimum, opt.deployment) > 0 then
                at = table.join(opt, {deployment = minimum, triple = opt.architecture .. "-apple-ios" .. minimum})
            end
            local dump = os.iorunv(clang(at, table.join(includes, {"-fsyntax-only", "-w", "-Xclang", "-ast-dump", "-Xclang", "-ast-dump-filter", "-Xclang", name, source}), true))
            earliest[name] = introduced_version(dump, name) or false
        end
    end
    if file then
        store_folder(path.directory(file))
        local temporary = file .. "." .. hash.strhash32(object .. os.mclock()) .. ".tmp"
        io.save(temporary, {names = names, earliest = earliest})
        os.mv(temporary, file)
    end
    return names, earliest
end

function releases_in(opt, source, object)
    local names, measured = measured_names(opt, source, object)
    local earliest = {}
    for _, name in ipairs(names) do
        local version = measured[name] or nil
        if not version then
            -- API that is Foundation's own and in no header of the SDK, which a
            -- backport still carries under Apple's name because an archive holds
            -- it: the registry is what says when it arrived.
            -- Through entry_of, not a raw lookup: the registry spells a function with its
            -- parentheses and a member with its class, and the name here is the symbol's, so
            -- `listed[name]` misses every function the registry carries. An 18.2 function on a
            -- port whose held caches end at 18.0 is exactly that case: no cache places it, the
            -- source says nothing, and the registry is the only thing that knows.
            local entry = entry_of(listed(opt.root), name)
            version = entry and entry.status == "implemented" and entry.introduced or nil
        end
        earliest[name] = version or false
    end
    local releases, unplaced = {}, {}
    for _, name in ipairs(names) do
        local version = earliest[name] or nil
        if version then
            releases[version] = releases[version] or {}
            table.insert(releases[version], name)
        else
            table.insert(unplaced, name)
        end
    end
    return releases, unplaced
end

-- What is wrong with one object's releases, or nil when it holds API of exactly one.
local function misplaced(source, releases, unplaced)
    if #unplaced > 0 then
        return string.format("neither the SDK, the registry nor a held release's own cache says which iOS release %s arrived in, and %s defines it, so no band can hold it",
                             table.concat(unplaced, " "), path.filename(source))
    end
    local found = table.orderkeys(releases)
    table.sort(found, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    if #found > 1 then
        local described = {}
        for _, version in ipairs(found) do
            table.insert(described, string.format("%s from iOS %s", table.concat(releases[version], " "), version))
        end
        return string.format("%s defines %s; an object carries API that arrived in one release, so split it", path.filename(source), table.concat(described, " and "))
    end
end

local INTRODUCED = {}

local function measured(opt, source, object)
    local key = object .. ":" .. (KEYS[object] or hash.sha256(object))
    if not INTRODUCED[key] then
        local releases, unplaced = releases_in(opt, source, object)
        INTRODUCED[key] = {releases = releases, unplaced = unplaced, problem = misplaced(source, releases, unplaced)}
    end
    return INTRODUCED[key]
end

function introduced_in(opt, source, object)
    local found = measured(opt, source, object)
    if found.problem then
        raise(found.problem)
    end
    return table.orderkeys(found.releases)[1]
end

function later_than(opt, release)
    return function (object)
        return dyld.compare_versions(introduced_in(opt, opt.origins[object], object), release) > 0
    end
end

-- Every object of every library is measured before anything is refused, so a tree with several
-- mixed objects names all of them in one run rather than one per build.
function check_releases(opt, objects, origins)
    local problems = {}
    for _, library in ipairs(staged_libraries(opt)) do
        for _, object in ipairs(objects[library.name]) do
            if #exported_symbols(object) > 0 then
                local problem = measured(opt, origins[object], object).problem
                if problem then
                    table.insert(problems, string.format("  %s: %s", library.name, problem))
                end
            end
        end
    end
    if #problems > 0 then
        raise("%d objects hold API no single release introduced:\n%s", #problems, table.concat(problems, "\n"))
    end
end

-- A class the release carries but does not export is one a band cannot drop:
-- nothing says it is there in the symbols, and it cannot be re-exported. The
-- library would define a second class of that name, and the runtime would take
-- one of the two, so the band asks the release's Objective-C metadata as well
-- and refuses what it would duplicate. What it lets through is a proxy: an
-- object that defines the class under a name of Charon's own and exports the
-- release's name as an alias of it, for a port to link against while messages
-- go to the release's class.
function duplicated(objects, classes)
    local found = {}
    for _, object in ipairs(objects) do
        local defined = {}
        for _, symbol in ipairs(defined_symbols(object, true)) do
            defined[symbol] = true
        end
        for _, symbol in ipairs(exported_symbols(object)) do
            local class = symbol:match("^_OBJC_CLASS_%$_(.+)$")
            if class and classes[class] and not defined["_OBJC_CLASS_$_Charon" .. class] then
                found[class] = path.filename(object)
            end
        end
    end
    local named = table.orderkeys(found)
    local told = {}
    for _, class in ipairs(named) do
        table.insert(told, string.format("%s (%s)", class, found[class]))
    end
    return told
end

function band_ranges(points, listed)
    local ranges = {}
    for index, point in ipairs(points) do
        local following = points[index + 1]
        local first, last
        for _, version in ipairs(listed) do
            if dyld.compare_versions(version, point) >= 0 and (not following or dyld.compare_versions(version, following) < 0) then
                first = first or version
                last = version
            end
        end
        if not first and index == 1 then
            raise("no firmware in the catalog runs iOS %s or later%s, so its API has no band", point, following and (" and before " .. following) or "")
        end
        if first then
            table.insert(ranges, {point = point, first = first, last = last})
        end
    end
    return ranges
end

local function release_cache(opt, architectures, release)
    local held = held_cache(opt.architecture, release)
    if held then
        return held
    end
    local cache, found = firmware.ensure(architectures[release], release, {tool = opt.tool})
    if found ~= release then
        raise("the band of iOS %s is checked against that release, and the %s firmware nearest to it is %s", release, architectures[release], tostring(found))
    end
    return cache
end

-- The bands the package stages, {point, first, last} each, and the architecture of every firmware
-- the catalog lists by release: a band point is every release an object's API arrived in after the
-- deployment and every registry minimum above it, and a band is checked against the first and the
-- last release it runs on.
local function band_plan(opt, objects)
    local points = {[opt.deployment] = true}
    for _, library in ipairs(staged_libraries(opt)) do
        for _, object in ipairs(objects[library.name]) do
            if #exported_symbols(object) > 0 then
                local version = introduced_in(opt, opt.origins[object], object)
                if dyld.compare_versions(version, opt.deployment) > 0 then
                    points[version] = true
                end
            end
            if (opt.minimums or {})[object] then
                points[opt.minimums[object]] = true
            end
        end
    end
    points = table.orderkeys(points)
    table.sort(points, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    local architectures = {}
    for _, architecture in ipairs(compatible(opt.architecture)) do
        for _, version in ipairs(firmware.versions(architecture)) do
            architectures[version] = architectures[version] or architecture
        end
    end
    local listed = table.orderkeys(architectures)
    table.sort(listed, function (a, b) return dyld.compare_versions(a, b) < 0 end)
    return band_ranges(points, listed), architectures
end

-- Staging every band checks its imports against the caches of its first and last release, which a
-- build of the deployment's band alone never opens: a new band point (7.1, from one registry row)
-- passed the gate and stopped the canon on a cache nobody held. A complete build names every such
-- release up front, with its band and the command that fetches it. The answer holds for the ladder
-- as it is held: a band point is the first held release that exports an object's API, so a fetched
-- cache can move a point earlier and end the band before it on another release (measured: fetching
-- 7.1, 8.1.2 and 9.2 moved the ends to 7.0.6, 8.1.1 and 9.1, and fetching those moved them to 8.1
-- and 9.0.2). Only the whole ladder would fix the points; its size keeps it unheld. A cache is not the
-- whole release either: a public framework can ship as a file beside it (PushKit on 8.0 and 8.1.3),
-- so a band end is held only with the libraries fetch takes from outside its cache.
function check_band_caches(opt, objects)
    local ranges, architectures = band_plan(opt, objects)
    local missing = {}
    for _, range in ipairs(ranges) do
        for _, release in ipairs(table.unique({range.first, range.last})) do
            local held = held_cache(opt.architecture, release)
            local cached = held and path.filename(held):match("^dyld_shared_cache_(.+)$")
            if not held then
                table.insert(missing, string.format("  iOS %s, an end of the band of iOS %s (%s to %s): xmake firmware --arch=%s fetch %s",
                                                    release, range.point, range.first, range.last, architectures[release], release))
            elseif cached and not os.isdir(dyld.outside_source(path.directory(held), cached)) then
                table.insert(missing, string.format("  iOS %s, an end of the band of iOS %s (%s to %s), without the libraries it carries outside its shared cache: xmake firmware --arch=%s fetch %s",
                                                    release, range.point, range.first, range.last, cached, release))
            end
        end
    end
    if #missing > 0 then
        raise("the staged bands cannot have their imports checked: %s does not hold all of %d releases they are checked against\n%s",
              dyld.root(), #missing, table.concat(missing, "\n"))
    end
    return ranges
end

function stage_bands(opt)
    opt = table.join(opt, {triple = opt.architecture .. "-apple-ios" .. opt.deployment})
    local attach, objects, origins, minimums = compiled(opt)
    opt = table.join(opt, {origins = origins, minimums = minimums})
    check_releases(opt, objects, origins)
    local ranges, architectures = band_plan(opt, objects)
    local home = path.join(opt.stage, INSTALL_FOLDER)
    local lines = {}
    for _, range in ipairs(ranges) do
        local releases, signatures, caches = {}, {}, {}
        for _, release in ipairs(table.unique({range.first, range.last})) do
            local file = release_cache(opt, architectures, release)
            local found = loaded(file, opt.architecture)
            table.insert(releases, found)
            table.insert(caches, {cache = file, release = release})
            local reexported = {}
            for _, library in ipairs(staged_libraries(opt)) do
                local _, symbols = band(found.exports, objects[library.name], later_than(opt, release), {release = release, minimums = opt.minimums})
                table.join2(reexported, symbols)
            end
            signatures[release] = table.concat(reexported, " ")
        end
        if signatures[range.first] ~= signatures[range.last] then
            raise("iOS %s and %s export different backported symbols (%s, and %s), although the SDK says nothing the backports define arrived between them",
                  range.first, range.last, signatures[range.first], signatures[range.last])
        end
        local built = {}
        for _, library in ipairs(staged_libraries(opt)) do
            table.insert(built, link(opt, library, attach, objects[library.name], releases, path.join(home, "bands", range.first), caches[1]))
        end
        for index, release in ipairs(table.unique({range.first, range.last})) do
            dyld.check(release_cache(opt, architectures, release), built)
            check_categories(releases[index], release_inventory(caches[index].cache), built, opt.architecture, release)
        end
        for index = #built, 1, -1 do
            os.vrunv("xcrun", {"strip", "-x", built[index]})
            signing.sign(opt.ldid, built[index])
        end
        table.insert(lines, range.first .. " " .. range.last)
    end
    io.writefile(path.join(home, "bands", "ranges"), table.concat(lines, "\n") .. "\n")
    return ranges
end

POSTINST = [[
#!/bin/sh
set -e
root="${DPKG_ROOT:-}"
home="$root@HOME@"
version=$(sed -n '/<key>ProductVersion<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$root/System/Library/CoreServices/SystemVersion.plist" 2>/dev/null || true)
if [ -z "$version" ]; then
    echo "@PACKAGE@ cannot read ProductVersion from $root/System/Library/CoreServices/SystemVersion.plist, so it cannot pick the libraries for this iOS" >&2
    exit 1
fi
older() {
    left=$1 right=$2
    while [ -n "$left$right" ]; do
        a=${left%%.*} b=${right%%.*}
        if [ "$left" = "$a" ]; then left=; else left=${left#*.}; fi
        if [ "$right" = "$b" ]; then right=; else right=${right#*.}; fi
        if [ "${a:-0}" -lt "${b:-0}" ]; then return 0; fi
        if [ "${a:-0}" -gt "${b:-0}" ]; then return 1; fi
    done
    return 1
}
band=
while read -r first last; do
    if ! older "$version" "$first" && ! older "$last" "$version"; then
        band=$first
    fi
done < "$home/bands/ranges"
if [ -z "$band" ]; then
    echo "@PACKAGE@ holds no libraries built and checked for iOS $version; it holds them for iOS $(sed 's/ / to /' "$home/bands/ranges" | tr '\n' ',' | sed 's/,$//;s/,/, /g')" >&2
    exit 1
fi
for library in "$home/bands/$band"/*.dylib; do
    ln -sf "bands/$band/${library##*/}" "$home/${library##*/}"
done
]]

PRERM = [[
#!/bin/sh
set -e
if [ "$1" = remove ]; then
    for library in "${DPKG_ROOT:-}@HOME@"/*.dylib; do
        if [ -L "$library" ]; then
            rm -f "$library"
        fi
    done
fi
]]

function write_scripts(folder)
    os.tryrm(folder)
    os.mkdir(folder)
    for name, text in pairs({postinst = POSTINST, prerm = PRERM}) do
        io.writefile(path.join(folder, name), (text:gsub("@HOME@", INSTALL_FOLDER):gsub("@PACKAGE@", PACKAGE)))
    end
end

-- The 12th search bundle isn't a band: it carries none of this port's own API, only a bridge from
-- CharonSpotlightStore (libCoreSpotlightBackports.dylib, resolved by name at runtime, not linked -
-- see CharonSearchDatastore.m) to Search.framework's own SPSearchDatastore, so it needs no
-- per-release symbol-availability logic and is built once, at the port's own deployment minimum,
-- for /System/Library/SearchBundles/ - the directory
-- .agent-work/handoffs/2026-09-23-corespotlight-searchbundle-measurement.md measured
-- Search.framework's own -_loadSearchBundles to scan - rather than staged per band like the dylibs.
local function corespotlight_staged(opt)
    for _, library in ipairs(staged_libraries(opt)) do
        if library.name == "CoreSpotlightBackports" then
            return true
        end
    end
    return false
end

-- write_deb compiles the bundle, so its source keeps being checked, but does not place it in the
-- package: sending -appendResults: from -performQuery:withResultsPipe: puts searchd into
-- uninterruptible sleep until kill -9, measured on an iPad 2 (6.1.3) and recorded in
-- facts/CoreSpotlight/CoreSpotlight.md. A package carrying it hangs the system search on every
-- device that installs it. It goes back into the stage only once that hang is fixed and the query
-- path is measured green on the device; until then write_deb says so, with the reason.
local SEARCHBUNDLE_WITHHELD = "sending -appendResults: hangs searchd (measured on an iPad 2, facts/CoreSpotlight/CoreSpotlight.md)"

function write_searchbundle(opt)
    if not corespotlight_staged(opt) then
        return
    end
    local folder = path.join(opt.builddir, "searchbundle", "org.charon.corespotlight.searchBundle")
    os.tryrm(folder)
    os.mkdir(folder)
    local source = path.join(opt.root, "CoreSpotlight", "SearchBundle", "CharonSearchDatastore.m")
    local output = path.join(folder, "org.charon.corespotlight")
    local triple = opt.architecture .. "-apple-ios" .. opt.deployment
    os.vrunv(driver(opt, {"-target", triple, "-isysroot", opt.sdkdir, "-fuse-ld=" .. opt.ld, "-fobjc-arc",
                          "-bundle", "-Os", "-g0", "-Wall", NOT_ENCRYPTED,
                          "-DCHARON_BACKPORTS_INSTALL_FOLDER=\"" .. INSTALL_FOLDER .. "\"", "-o", output, source, "-framework", "Foundation"}))
    os.vrunv("xcrun", {"strip", "-x", output})
    signing.sign(opt.ldid, output)
    os.cp(path.join(opt.root, "CoreSpotlight", "SearchBundle", "Info.plist"), path.join(folder, "Info.plist"))
    cprint("${color.warning}withheld:${clear} org.charon.corespotlight.searchBundle is built at %s but not packaged: %s", folder, SEARCHBUNDLE_WITHHELD)
end

function write_deb(opt)
    local debian = import("debian", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})
    local stage = path.join(opt.builddir, "stage")
    os.tryrm(stage)
    local ranges = stage_bands(table.join(opt, {stage = stage}))
    write_searchbundle(table.join(opt, {stage = stage}))
    local covered = {}
    for _, range in ipairs(ranges) do
        table.insert(covered, range.first == range.last and range.first or (range.first .. " to " .. range.last))
    end
    local control = path.join(opt.builddir, "control")
    io.writefile(control, table.concat({
        "Package: " .. PACKAGE,
        "Name: Apple API backports",
        "Architecture: iphoneos-arm",
        "Section: System",
        "Description: Objective-C classes and methods of later iOS releases for the releases that lack them, as the libraries ports built with Charon load from " .. INSTALL_FOLDER .. "; libraries built and checked for iOS " .. table.concat(covered, ", ")
    }, "\n") .. "\n")
    local scripts = path.join(opt.builddir, "scripts")
    write_scripts(scripts)
    return debian.write({control = control, version = opt.version, root = stage, scripts = scripts, outputdir = opt.outputdir}), ranges
end
