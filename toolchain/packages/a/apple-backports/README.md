# What the backports carry, release by release

How the package is built, banded and checked is in the repository's README, and
the four answers an entry can give - `implemented`, `inert`, `absent`,
`ignored` - are in `registry/README.md`. The registry is the list: every API
considered has an entry there, and the build refuses a class or selector that
has none. This file is the reasoning behind the answers, a section per range of
releases, so that a port can see at a glance what it gets, what it gets with a
difference, and what it will never get here and why.

## iOS 8

### SceneKit's physics world, kept and not simulated

A `.scn` scene can carry an `SCNPhysicsWorld`, and it is decoded: `coin.scn`'s gravity of
(0, 1.75, 0) reads back as the authored value, not the class default. Nothing steps a simulation,
though, because no `SCNPhysicsBody` is carried, so the world is **inert**: gravity, speed, the time
step, behaviors and the contact delegate are kept and read back and never act, and the first time
an application sets one the log says so once. Its queries answer an empty array, which is the true
answer with no body to hit.

### Metal's blits, mip chains and fences, over OpenGL ES 2.0

A blit is a copy, and every resource the port has is already CPU memory: a buffer is its own bytes, a
texture is an OpenGL ES 2.0 texture the port reads and writes a region at a time. So `MTLBlitCommandEncoder`
is real: buffer to buffer is a `memmove`, buffer to texture writes the region in the texture's own
format, texture to buffer reads it back and repacks it into the texture's own channel count, texture to
texture reads the source first and writes the destination from it, `fillBuffer:range:value:` is a `memset`,
and `generateMipmapsForTexture:` is `glGenerateMipmap` over a chain the texture was really made with —
textures carry the mip levels their descriptor asked for, each allocated at its own size, so a level below
the first is a texture the driver can sample, blit to and read back. The 9.0 `options:` variants, the 10.0
fences and the 13.0 whole-surface copies are carried with them, and every range is checked against the
resource it names before a byte moves: a copy the port cannot make writes one line in the log naming the
reason and copies nothing.

A fence here is the signal value of a shared event, and `updateFence:` records how many commands the
encoder has encoded — which is how far the work has been brought on a device where a command is a call
into OpenGL ES 2.0 that has already been made. `MTLSharedEvent` and `MTLSharedEventListener` are carried
as that value and the queue its notifications run on, so a value signalled on one thread ends a wait on
another for real. A handle round-trips: the value and the wait live in a state of their own,
`MTLSharedEventHandle` is carried and names that state, and `newSharedEventWithHandle:` hands
back a different event over the same one — so a value signalled through the first is seen by the
second. `-newSharedEventHandle` is not nullable in Apple's header, and the port answers it with a
handle rather than with nil. What a handle cannot do is be opened in another process, because the
port runs one; nothing else about it is affected.

`optimizeContentsFor{CPU,GPU}Access:` are **inert**, and say so once in the log: the API is a hint to a
memory migrator, and every resource of the port is CPU-resident already, so there is no residency to move
between. The API asks for a performance, not for a value, and the performance is the one it asks for.

`-[MTLCommandEncoder barrierAfterQueueStages:beforeStages:]` (26.0) is **absent** for a mechanical reason
worth naming: it takes an `MTLStages`, a type that arrived with the SDK of iOS 26, and the backports of this
package build against the SDK of 16.4, where the type does not exist to be written. It would have been a
no-op on this device in any case. `facts/Metal/Blits.md` has the whole of it, including the blits of 12.0,
13.0, 14.0 and 26.0 that wait for the indirect command buffers, the counter sample buffers and the tensors.

### Heaps, one allocation resources are taken out of

`MTLHeap` and `MTLHeapDescriptor` (10.0) are carried, and on this device a heap is literally what a heap
can be where every resource is already CPU memory: one allocation, out of which a buffer is a view and a
texture takes its size. That is not a reduced stand-in for a GPU heap — a GPU heap exists to place
resources in memory the GPU reads, and every resource here *is* memory the GPU reads, because it is one
address space — and it is why the accounting is exact: `size` is the size asked for, `usedSize` is the
offset the next allocation starts at, `currentAllocatedSize` is the sum of what was handed out,
`maxAvailableSizeWithAlignment:` is what is left, and an explicit offset (13.0) is the offset asked for
once it is aligned to the heap's 256 bytes and once it fits. An allocation that does not fit is refused
with a line in the log, not made past the end of the memory.

A **placement** heap is carried and behaves as one: the two allocations that carry no offset refuse, and
say why, because a placement heap that quietly allocated anyway would hand the application a resource at
an offset it did not choose. A **sparse** heap is refused at creation with an error: a sparse heap maps
its pages in on demand, and one allocation of the size asked for is not that.

`hazardTrackingMode` and `storageMode` are stored and read back, and `resourceOptions` is the storage mode
as a resource's options say the same thing. Nothing tracks hazards with the first, because a command here
is a call into OpenGL ES 2.0 that has already been made by the time it is encoded, so no resource can be
read while another writes it; `stages` changes nothing for the same reason, which `facts/Metal/Heaps.md`
says rather than leaving the argument ignored silently. `-setPurgeableState:` answers NO, as a buffer's
does: this device has no purgeable memory.

**One difference, named rather than hidden:** a texture taken out of a heap is a real texture whose
pixels are the texture's own, and the heap's span it was given holds nothing — an ES 2.0 texture is
copied into and cannot be backed by memory the heap hands out, which is what a placement heap buys on a
Metal device. The size taken out of the heap, the offset and the accounting are all exact, and the port
says the rest once per texture in the log. `facts/Metal/Heaps.md` names what a native fix would be (the
pixels living in the span, with the ES 2.0 texture kept in step at every boundary) and what it would
cost. `-useHeap:`/`-useHeaps:count:` (11.0, 13.0) record the heaps, and a resource bound afterwards that
came from another one is named in the log with them, because Metal leaves that case undefined and passing
it by in silence would be worse.

## iOS 9

### Contacts, over the address book the release already has

There is no wall in front of Contacts. iOS 6.1.3 carries the whole C API of
`AddressBook` - `ABAddressBookCreate`, `ABAddressBookCopyArrayOfAllPeople`,
`ABAddressBookSave`, `ABPersonCopyLocalizedPropertyName`, the multi-value family
and both halves of the vCard pair are exported by the armv7 shared cache - and
Contacts of iOS 9 is an Objective-C surface over that same local store. So
`CNContactStore` is an `ABAddressBook`, a `CNContact` is an `ABRecord`, a
`CNLabeledValue` is one entry of a multi-value, and `CNPhoneNumber`,
`CNPostalAddress`, `CNSocialProfile` and `CNInstantMessageAddress` are the values
those entries hold.

What is carried is the whole of the reading and writing path an application of
the corpus uses: the sixteen classes above with every property of iOS 9 on them,
the ninety-two constants of iOS 9 and the three iOS 10 keys, each defined with
the string the release itself holds; the permission, out of
`ABAddressBookGetAuthorizationStatus` and
`ABAddressBookRequestAccessWithCompletion`; the fetches, the six predicates, the
unification of linked people, the formatter, the vCard pair and the user
defaults; and `CNSaveRequest`, written into the book in one `ABAddressBookSave`.
Groups and containers are the same translation over `ABGroup` and `ABSource` -
`CNGroup`, `CNMutableGroup`, `CNContainer`, the predicates over both,
`groupsMatchingPredicate:error:`, `containersMatchingPredicate:error:` and the
group and membership operations of `CNSaveRequest` are all carried;
`facts/Contacts/Groups.md`. `CNContactProperty` and `CNPostalAddressFormatter`
are carried too - a value object the real SDK itself exposes no public
initializer for, and a multi-line address formatter that does not read
`ABAddressFormats.plist` for per-locale field order, a written-down divergence
rather than a silent one. `CNFetchResult` and the eleven
`CNChangeHistoryEvent` subclasses of iOS 13 are real classes, so a strong
reference to any of them does not crash dyld;
`enumeratorForContactFetchRequest:error:` hands one back for a plain fetch, no
history needed. The one wall left is the history itself: the release keeps
none, so `enumeratorForChangeHistoryFetchRequest:error:` and
`currentHistoryToken` stay `absent` in `registry/Contacts/ios9.json`, and a
call raises an unrecognised selector instead of handing back an empty answer;
`facts/Contacts/History.md`.

Two properties have nowhere to live in the release's store and are written down
rather than faked: `previousFamilyName`, for which the release exports no
maiden-name property, and `nonGregorianBirthday`, for which it has no alternate
birthday at all. `subLocality` and `subAdministrativeArea` of iOS 10.3 are empty
for the same reason. The rest of the differences - the case of the social service
names, the UUID a labeled value hands out beside the integer the book keeps, and
what a localized name answers - are in `facts/Contacts/Values.md` and
`facts/Contacts/CNContactStore.md`.

## iOS 10

### Feedback that is a vibration, not a haptic

The three feedback generators are implemented against the motor the iPhone 4S
has, and one of the four is not implemented at all. Both halves of that are
measurements rather than opinions, and `facts/UIKit/UIFeedbackGenerator.md`
carries the numbers.

iOS 10 tells `light`, `medium` and `heavy` apart by which Taptic waveform it
plays, not by how hard - the volumes of the three differ by a tenth. An
eccentric rotating mass has no waveforms, only amplitude and length, so this
port separates the three by strength and duration instead. It is the same API
and the same three steps of emphasis; it is not the same sensation, and nothing
here pretends otherwise. On hardware with no motor at all, such as the iPad 2,
every call plays nothing, which is what iOS 10 itself does on a device without a
Taptic Engine.

`UISelectionFeedbackGenerator` is there and **does nothing**. Measured on an
iPhone4,1, a pulse of 20 ms does not start the motor and 40 ms is the shortest
that moves it, while full amplitude needs upwards of 200 ms. A tick per detent of
a turning picker is faster than that floor, so the class cannot make the
sensation it stands for; what iOS 10 does on a device without a Taptic Engine,
where the class exists and `-selectionChanged` plays nothing, is what it does
here. A program that names the class then finds it, as it would on iOS 10.

The motor is reached through
`AudioServicesPlaySystemSoundWithVibration`, the path the system itself uses, so
mediaserverd keeps its own arbitration; the port does not write the IORegistry
node behind its back. `-prepare` has nothing to warm and does nothing, which is
also what iOS 10 does when there is no engine.

### Notifications through the scheduler iOS 6 already has

`UNUserNotificationCenter` is carried as a facade over the local notifications
of iOS 6: a request becomes a `UILocalNotification`, the pending requests are
read back from the ones scheduled, and the delegate hears of a notification
through the application delegate, whose `-application:didReceiveLocalNotification:`
the center takes over for its own notifications only. The triggers find their
dates as the newest release does, held on 5760 dates on the host and on iOS
6.1.3.

What the release cannot show is kept rather than faked. The title and subtitle
travel with the request everywhere and are never shown, since a local
notification of iOS 6 has no title; the one place that would hand the title to
the release is a single switch, off. Categories and actions are values, measured
against the host's own `UNNotificationAction`, `UNTextInputNotificationAction` and
`UNNotificationCategory`, and the category set the application registers is stored
and read back. The banner does not draw their actions yet, which is owed.
`UNTextInputNotificationResponse` and `UNNotificationServiceExtension` stay inert, and
threads are kept and change nothing. A repeat iOS 6 cannot follow - every 90 seconds, the 31st of every
month - is refused with an error rather than scheduled to fire on other dates.
The settings report what the application asked for, since iOS 6 tells it
nothing of what the user set. Attachments, location
triggers and the delivered notifications are absent: the
last live in BulletinBoard, which answers no application on this jailbreak.

### Core Data's container, in a library of its own

`NSPersistentContainer` and `NSPersistentStoreDescription` are carried in
`libCoreDataBackports.dylib`, built with the `coredata` config, so that only a
port that keeps its data with Core Data loads Core Data. With them come the
members iOS 10 gave the classes iOS 6 has: `-initWithContext:`, `+entity` and
`+fetchRequest` of a managed object, `-execute:` of a fetch request,
`automaticallyMergesChangesFromParent` of a context, the description-taking way
to add a store, and the merge policies as class properties. `-execute:` needs
to know the context whose block is running, which iOS 6 does not record, so
the library records it around `-performBlock:` and `-performBlockAndWait:`.
Query generations are carried without a snapshot to read: a context can be pinned to the
current generation and reads the latest rows, as an in-memory store does in the newest
Core Data, because the store of iOS 6 keeps a rollback journal and no write-ahead log
(`facts/CoreData/QueryGeneration.md`).

### WKWebView, over the UIWebView of the release, in a library of its own

`WKWebView` and the classes around it - the configuration, the preferences, the user
content controller with its scripts and message handlers, the navigation actions and
the back-forward list - are carried in `libWebKitBackports.dylib`, built with the
`webkit` config. The view holds a `UIWebView` and turns what that reports into what a
`WKNavigationDelegate` is sent, in the order WebKit sends it: the decision, the start,
the commit, the finish, with `URL`, `title` and `loading` observable. `evaluateJavaScript`
answers numbers, strings, dates, arrays, dictionaries, `nil` and the two errors as
WebKit does, and `window.webkit.messageHandlers` reaches the handlers. What the
`UIWebView` cannot tell is absent or inert and listed: a script at document start runs at
the end of the document, the response of a navigation is never offered to the delegate,
and a redirect, an authentication challenge and the UI delegate's panels never reach the
application. `facts/WebKit/WKWebView.md` has the whole table.

### LocalAuthentication, answered as a device with no fingerprint sensor

`LAContext` is carried in `libLocalAuthenticationBackports.dylib`, built with the `localauthentication` config. The devices
iOS 6 runs on have no biometric sensor and give an application no way to ask for the passcode, so it answers as a device
without a sensor: biometry is not available (`LAErrorBiometryNotAvailable`), the passcode cannot be asked for
(`LAErrorNotInteractive`), and an evaluation is answered with that error and never succeeds. An application that asks
first and falls back to its own passcode works; one that cannot do without the sensor says so. See
`facts/LocalAuthentication/LAContext.md`.

### Blocks for timers, threads and run loops, and what stays out

`NSTimer` gets the block factories and `-initWithFireDate:interval:repeats:block:`,
`NSThread` gets `-initWithBlock:` and `+detachNewThreadWithBlock:`, `NSRunLoop`
gets `-performBlock:` and `-performInModes:block:`, `NSFileManager` gets
`temporaryDirectory`, `UIImage` gets `-imageWithHorizontallyFlippedOrientation`
and `UIScreen` gets `maximumFramesPerSecond`, each read from the release's own
code and answering the same, the text of the exceptions included; the flipped
image is rebuilt from public API, and its facts say where that differs.
Left out because iOS 6 cannot answer as iOS 10 does: the pasteboard's `hasStrings`,
`hasURLs`, `hasImages`, `hasColors` and `-setItems:options:`, which ask a
pasteboard service and a framework iOS 6 does not have and, with an expiration
date, promise to clear the pasteboard after the application has gone, and the
Display P3 colors, which need a color space iOS 6 cannot make.

### os_log, written to the system log

A program built for iOS 6 reaches `os_log` through the iOS 9 functions, `_os_log_internal` and `_os_log_create`,
which the macros choose below a deployment target of 10.0. The port carries those and the log object they need, and
writes each message, formatted as the release's own formatter writes it, to ASL. Nothing is redacted, and a few
decorators for a reader, such as `iec-bytes`, are written plain; the facts say which.

### Finding the cameras and microphones, in a library of its own

`AVCaptureDeviceDiscoverySession`, the device types of iOS 10 and `+[AVCaptureDevice defaultDeviceWithDeviceType:mediaType:position:]`
are carried in `libAVFoundationBackports.dylib`, built with the `avfoundation` config, so that only a port that looks for
cameras loads AVFoundation. They answer from the devices iOS 6 has: a camera is the wide angle one, the microphone is the
built-in one, and a search for a telephoto or a dual camera finds nothing.

### Text content types, kept and never read

The 23 `UITextContentType` constants of iOS 10 have the release's own strings, and
`textContentType` of a text field, a text view and a search bar keeps a copy and
gives it back. Nothing reads it: it hints at an autofill iOS 6 does not have.

### Images drawn where sRGB cannot be made

`UIGraphicsImageRenderer` draws in sRGB, as iOS 10 does, so that its PNG and
JPEG match UIKit's byte for byte. On an iPhone4,1 running 6.1.3 CoreGraphics
makes no sRGB space - `CGColorSpaceCreateWithName(kCGColorSpaceSRGB)` answers
`NULL` - and there the renderer draws in device RGB, the space the release's own
UIKit draws every image context in. The pixels are the same; the files carry no
colour profile, like every image that release makes itself.

### SafariServices, a page in bars of the application's own

`SFSafariViewController`, its configuration, its activity button and the prewarming token are carried in
`libSafariServicesBackports.dylib`, built with the `safariservices` config. The page is drawn by the `UIWebView` of the
release in the process of the application, under a navigation bar with the dismiss button and the address, over a toolbar
with back, forward, the action sheet, the button that opens the page in the browser and reload. What is asked of the
delegate, what is refused and with which words follow the system's (and `SFAuthenticationSession`, the sign-in session of iOS 11, takes the callback address from the page's navigation), held by `host/uikit2` (`safariviewcontroller`) and
run on an iPad 2 by `device/safariviewcontroller.m`; the cookies and passwords of Safari, Reader and the content blockers
are not shared, as `facts/SafariServices/SFSafariViewController.md` sets out.

### JavaScriptCore's typed arrays, a value the release's engine does not have

Thirteen rows of JavaScriptCore's C API are **absent** here, and the reason is a value rather than a
release: `JSObjectMakeTypedArray` and its ten siblings, `JSObjectGetTypedArray*`,
`JSObjectGetArrayBuffer*` and `JSValueGetTypedArrayType` all report on, or make, an ES6 typed array, and
iOS 6's engine has none. Measured, not assumed: the release's C API exports no typed-array entry point
at all until 10.0.1 (`tools/cache-index/first-rung.lua` over the 50 held rungs, for all thirteen), and the
6.1.3 armv7 cache's own symbol table carries 300 `JSC::` symbols - `JSC::JSArray` and `JSC::JSString`
among them, which is the control that says the search can see a JSC class - and none for
`JSC::JSArrayBuffer` or `JSC::JSTypedArray`.

Nine of the thirteen are getters, and Apple's own answer for a value that is not a typed array is a zero,
a null or `kJSTypedArrayTypeNone`, so a port that returned those unconditionally would link, would not
crash, and would be indistinguishable from correct to every client that never holds a typed array. It
would be a lie to the one client that does: a typed array made by a polyfill or carried in from a newer
context would be reported as 0 bytes by a function that has not looked. So the effect is a weak
reference that is NULL, and `facts/JavaScriptCore/CAPI.md` has the measurements and the rest of the
twenty-six C API rows the corpus listed as absent.

## iOS 13 and 14

### Relative dates, in English

`NSRelativeDateTimeFormatter` writes the distance between two dates as "in 2 hours", "3 days ago", "yesterday", "next week",
in the numeric and named styles and the four unit styles, over the calendar of the formatter. It is written from the host's
own formatter: the fuzz differential agrees on 56000 answers, and 1600 recorded cases are held against the port on the
device. The words are English whatever the language of the device; the numbers go through the locale's number formatter.
See `facts/Foundation/NSRelativeDateTimeFormatter.md`.

### Scenes, over the one window an application has

`UIScene`, `UIWindowScene`, `UISceneSession`, `UISceneConfiguration`, the connection options, the URL contexts and their
options, the activation conditions, the request options, `UIStatusBarManager`, the scene notifications and the roles are
carried as a facade over the application's single window stack: one implicit scene, taken from the scene manifest of the
Info.plist or from the application delegate, connected after launch, and moved through its activation states by the
application's own notifications. `connectedScenes` holds it, `supportsMultipleScenes` is NO, and a request for a second
scene is answered with the error of a release that has none. `UIWindow(windowScene:)` makes a window of it and the scene
delegate's `window` is filled in for a storyboard. Not carried: state restoration by activity, Handoff, shortcut items and
CloudKit shares in the connection options, and the disconnect of the scene. See `facts/UIKit/UIScene.md`.

### Menus, context menus and previews, present so that applications launch

`UIMenuElement`, `UIAction`, `UIMenu` and `UIDeferredMenuElement`, the 45 `UIMenu...` identifiers,
`UIContextMenuConfiguration`, `UIPreviewParameters`, `UIPreviewTarget` and `UITargetedPreview` are carried as the value
objects they are: defaults, copies, equality, `-description`, secure coding and the exceptions they raise are held to the host's
own UIKit through Mac Catalyst (`tests/backports/host/uikit2`, the `menus` group), and the identifier constants string for
string. `UIMenuController` gets `-showMenuFromView:rect:`, `-hideMenuFromView:` and `-hideMenu` over the calls iOS 6 has.

What iOS 6 cannot do is not faked. It has no menu view, no preview morph and no highlight of the source view, so
`UIContextMenuInteraction` puts a long press on its view and shows the menu **as an action sheet**: elements that are disabled
or hidden are left out, inline submenus are flattened, other submenus open a second sheet, the first destructive element is the
sheet's red button, and the chosen action's handler runs. The delegate hears of the menu through an animator that runs added
animations at once, and the three preview callbacks and the preview provider are never called. Its `menuAppearance` is
compact, since a rich menu is the one with a preview. `UIMenuSystem` is there and **inert** - iOS 6 has no menu bar and no
key command menus to rebuild - and says so once in the log; `UIMenuBuilder` is absent, and `-buildMenuWithBuilder:` is never
called. `facts/UIKit/UIContextMenuInteraction.md` has the whole table, and `facts/UIKit/UIPreviewParameters.md` the one place
a value differs from the host: lines of text that touch are not joined into one outline.

### Pointers, hover, keys, search tokens and color wells, present so that applications launch

`UIPointerInteraction`, `UIPointerRegion`, `UIPointerRegionRequest`, `UIPointerStyle`, `UIPointerShape` and the four pointer effects,
`UIHoverGestureRecognizer`, `UIKey` with the `UIKeyInputHome`, `UIKeyInputEnd` and `UIKeyInputF1` to `UIKeyInputF12` strings,
the button, modifier and event members of `UIEvent`, `UIGestureRecognizer` and `UITapGestureRecognizer`, and
`UIButton.pointerInteractionEnabled` and `.pointerStyleProvider` are carried so that applications that link them launch. iOS 6 has no
pointing device, so what a pointer would do is **inert**: an interaction or a hover recogniser can be added to a view and never fires,
the delegate is never asked for a region or a style, no event has modifiers or buttons, and the first interaction and the first hover
recogniser say so once in the log. The values are the host's own to the last thing that can be asked - descriptions, equality, copies, the
hashes that follow from the values, the exceptions - held by the `pointer` and `pointercategories` groups of `tests/backports/host/uikit2`.
`UIPress.key` is absent, since `UIPress` is not on this release. See `facts/UIKit/UIPointerInteraction.md`, `UIPointerRegion.md`,
`UIPointerStyle.md`, `UIHoverGestureRecognizer.md`, `UIKey.md` and `UIPointerEvents.md`.

`UISearchTextField` and `UISearchToken` keep their tokens apart from the text, raise for a bad index with the system's own words and draw each token
as a plain rounded chip before the text; a backspace at the start deletes the last one. Positions count the text only, since a token is not a
character here, and tokens are not selected, copied or dragged. `UISearchBar.searchTextField` answers the search bar's own text field, extended at
run time with the token members, which are kept there and not drawn. `UISearchController.automaticallyShowsScopeBar` is kept and **inert**.
See `facts/UIKit/UISearchTextField.md`.

`UIColorWell` and `UIColorPickerViewController` are real, if small: the well draws a swatch and, when tapped, presents a picker of a 12 by 10 grid
of colors, an alpha slider and Done, which sets the well's color and sends value changed and tells the picker's delegate as the
system's does, continuously while a finger moves. There is no spectrum, eyedropper, saved color or hex entry. See `facts/UIKit/UIColorWell.md`.

`UISheetPresentationController` is the presentation of a page or form sheet in a compact width, over the port's own
presentation: the card slides up to its medium or large detent (or a custom one) over the presenter, which dims and scales
back behind it, sheets stack behind one another, and a drag moves it between detents or takes it down, asking the
delegate and `modalInPresentation` first, with the numbers of UIKitCore 16.0. In a regular width the release draws its
own form sheet. A full-width sheet's bottom corners follow the display's (square on every device with a home button), the
sheet rises over the keyboard while a first responder in it needs one, and the "magic" shadow of a sheet whose parent does
not stack with it is drawn from a reading of what lies under it, refreshed a few times a second rather than composited by
the render server. See `facts/UIKit/UISheetPresentationController.md`.

A program linked with SDK 13.0 or later gets iOS 13's default presentation style: a new view controller starts with
`UIModalPresentationAutomatic`, which `modalPresentationStyle` answers as the page sheet (full screen for an image picker of the
camera), decided as the release decides it, by the SDK the program's load command records. **Every port the toolchain builds is such a
program** (the SDK is 16.4), so a presentation without a style of its own is a sheet on the phone and a page sheet on the iPad; a
program linked with an older SDK keeps full screen. See `facts/UIKit/UIModalPresentationAutomatic.md`.

### Compositional layouts, laid out by the release's own collection view

`UICollectionViewCompositionalLayout` and everything it is described with - `NSCollectionLayoutSection`, `Group`, `Item`,
the supplementary, boundary and decoration items, the dimensions, sizes, spacings and anchors, the layout's configuration and
the environments a section provider is given - are carried in full. iOS 6 has `UICollectionViewLayout` since 6.0, so the layout
is one more subclass of it: it solves the description into frames and answers the calls the collection view already makes. The
rules were **measured**, not read: the same description is laid out by the host's own layout under Mac Catalyst and by the
port's, in a collection view in a real window, and 182 fixed layouts (fractional, absolute and estimated sizes, every kind of
group, spacing, insets, edge spacing, supplementary, boundary and decoration items, pinned headers, several sections, scrolling
both ways) agree frame for frame with no tolerance; their answers are the expectations of `tests/backports/device/compositional.m`.
The value classes agree with the host on 139 statements - defaults, copies, equality, `-description`, exceptions.
`contentInsetsReference` of 14.0 is carried in an object of its own.

What iOS 6 has no API for is done by the port. A section with an `orthogonalScrollingBehavior` scrolls sideways on its own inside
the collection view, in all five behaviors: a pan recognizer on the collection view drives an offset for the section (it follows
the finger, decelerates, gives at the ends, snaps to a group or a page), the groups are laid out in a row as the host's private scroll
view lays them, `visibleItemsInvalidationHandler` is called with real `NSCollectionLayoutVisibleItem` objects and what it sets on them is
shown, and the offsets are held to the host frame for frame. An estimated dimension is measured on the steps of a self-sizing flow layout: the displayed cell is asked
`-preferredLayoutAttributesFittingAttributes:` (its default fits the constraints or asks `-sizeThatFits:`, and a cell that overrides it works for both layouts), and so is a header or footer, the layout is asked whether to invalidate and
is invalidated with the context that method builds, and it is solved again with what they answer, as the host's is; sizes are held to the host's on 25 layouts, cells of a fixed intrinsic content size and cells that set the height in their attributes among them. Both are `implemented`. What is not the
host's: the cells of a section that scrolls the other way are not clipped to it, what a finger does is the port's own (the host's
scroll view takes only a real touch, so only the device test drags it), and an estimate on a supplementary item of an item or a group
is not measured. `-[NSCollectionLayoutGroup visualDescription]` is absent, and so is anything of a later
release. `facts/UIKit/UICollectionViewCompositionalLayout.md` has every rule and the few places where a very odd description is
not held to the host's answer.

### Corner curves, drawn as a mask

`kCACornerCurveCircular`, `kCACornerCurveContinuous` and `CALayer.cornerCurve` are carried as the host has them: a layer is
circular until given continuous, and a value that is neither makes it circular again. iOS 6 rounds a corner with a circular arc
only, so a clipping layer set to continuous gets a mask of the continuous corner shape over its circular clip, within 1.5% of the
area the system covers. See `facts/QuartzCore/CALayerCornerCurve.md`.

`CALayer.maskedCorners` picks which of the four corners `cornerRadius` rounds, the same four `CACornerMask` bits `UIRectCorner` already carries at the same positions: a clipping layer masked to fewer than all four gets a `CAShapeLayer` mask of a rect rounded on exactly those corners, kept in step with its bounds, radius and mask the way `cornerCurve`'s own mask is; a layer masked to all four (the default) is untouched. The two masks are not coordinated - whichever of `cornerCurve` or `maskedCorners` was set more recently on a layer keeps `layer.mask`. See `facts/QuartzCore/CALayerMaskedCorners.md`.

### The spring and the display link of Core Animation

`CASpringAnimation` is the release's own class - the armv7 caches of iOS 6.0 and 6.1.3 already carry it, privately, with its mass,
stiffness, damping and velocity - so `initialVelocity` and `setInitialVelocity:` are carried as iOS 9 carries them, one call to
`velocity` and `setVelocity:`, and `settlingDuration` as `durationForEpsilon:` with 0.001: the closed form below critical damping
and, at or above it, the system's own walk in steps of 0.1 second over a critically damped spring, held to the host's answers
over 32 named springs and 4000 random ones. A spring that cannot settle answers `MAXFLOAT`. See
`facts/QuartzCore/CASpringAnimation.md`.

`CADisplayLink.targetTimestamp` is the timestamp plus the duration of a display frame times the frame interval, the expression
iOS 12 ends in one instruction. `CADisplayLink.preferredFramesPerSecond` is kept beside the link and sets the release's own frame
interval to `max(1, round(1 / (frame duration * rate)))`, as the newer release does; it starts at zero, the documented default,
and reads back as 60 divided by the frame interval where an application moves the interval itself. The port leaves
`setFrameInterval:` alone, so an interval that is not a divisor of 60 stays where the application put it. See
`facts/QuartzCore/CADisplayLink.md`.

### Background tasks, accepted by no scheduler

`BGTaskScheduler`, the refresh and processing requests and the task classes are carried in a library of their own, for an
application that registers launch handlers and submits requests. iOS 6 launches an application in the background for none of
them, so a handler for a permitted identifier is kept and never called, and a submission answers NO with the error the header
gives for scheduling that is not available (code 1), or not permitted (code 3) when the identifier or the background mode is not
listed in the Info.plist. There is no host framework to compare with; the device test holds the port to the headers. See
`facts/BackgroundTasks/BGTaskScheduler.md`.

### Bar appearances, values on their own and applied where iOS 6 can draw them

`UIBarAppearance`, `UINavigationBarAppearance`, `UIToolbarAppearance`, `UITabBarAppearance`, `UIBarButtonItemAppearance`
and `UITabBarItemAppearance`, with their state objects, are carried as the value objects they are, against the host's own
UIKit: the defaults, which of them are set and which are only defaults, how a button or a tab item state falls back to the
normal one, the copies, the equality, the description and a secure archive are held to the host's answers over thousands of
random sequences of changes. What differs is written in `facts/UIKit/UIBarAppearanceValues.md`: the system colours are
plain light colours, a back indicator has no default image to answer, and the archive is the backport's own.

The bars apply them. `standardAppearance` of a `UINavigationBar`, a `UIToolbar` and a `UITabBar`, and `compactAppearance` of
the first two, become what iOS 6 has: a solid or an image background through `setBackgroundImage:forBarMetrics:`, a
hairline shadow, the title attributes turned into the keys of iOS 6, the button and tab item attributes and images on the
appearance proxies, the compact one on the landscape metrics. What iOS 6 cannot draw is kept in the object and
recorded in the facts: the blur, the large title, the badge, the layout of the tab items. The scroll edge appearances and the
appearances of a navigation item or a tab item are applied too: the bar watches the content scroll view of its view
controller by key-value observing and takes the scroll edge appearance at the top (the bottom, for a tab bar and a toolbar)
and the standard one elsewhere, and takes the appearance of its top item, or of the selected tab item, while that item
is shown, as the SDK's comment orders them. The subtitle attributes of iOS 26 and the override
interface style of iOS 27 are absent. The buttons reach every bar of the class in the application, not one bar, and
`facts/UIKit/BarAppearanceApplication.md` says why and what a device still has to prove.
### Symbol configurations, and symbols the port draws

`UIImageConfiguration` and `UIImageSymbolConfiguration` are carried as the immutable value objects they are - the factories, `configurationByApplyingConfiguration:`, the
four `without...` methods, traits, `isEqualToConfiguration:`, hash, description and secure coding - and `UIImageSymbolWeightForFontWeight()` with its inverse, all held to the host's own
UIKit through Mac Catalyst (`tests/backports/host/uikit2`, the `symbols` group). `UIImage` gets `symbolConfiguration`, `isSymbolImage`, `imageByApplyingSymbolConfiguration:` and the baseline,
`UIImageView` a `preferredSymbolConfiguration` that re-draws a symbol image with it.

iOS 6 has no SF Symbols, so `+[UIImage systemImageNamed:...]` **draws its own**: a small language of paths of the port's, with the system's naming grammar (`.fill`, `.circle`, `.slash`, `.badge.plus`, ...),
answers a template image for 549 names - the 251 that ten corpus applications name and 298 common ones - at the size, alignment insets and baseline the host gives (within a point, all names, eight configurations),
with the stroke following the weight, the size the scale, point size or text style. The drawings are held to the host's by the overlap of the two bitmaps (median 0.70, minimum 0.10; fine line
drawings are the low end); any other name is nil, as an unknown name is on the host, and `facts/UIKit/UIImageSymbols.md` lists the names the host knows that are not drawn yet.
Where the port differs from the host, `facts/UIKit/UIImageSymbolConfiguration.md` and `facts/UIKit/UIImageSymbols.md` say so: a font from `+preferredFontForTextStyle:` has no text style to give,
a symbol weight below zero is Regular where the host reads the memory beside its table, and a symbol image is `AlwaysTemplate` where the host's is `Automatic`.
### The difference of two collections, and diffable data sources

`NSOrderedCollectionDifference` and `NSOrderedCollectionChange`, with `-differenceFromArray:`, `-arrayByApplyingDifference:`, their ordered set
counterparts and `-applyDifference:`, are carried as the system's are: 320000 random differences of arrays and ordered sets, with every
option, an equivalence test and the calls it received, and the exceptions of the ones built from changes and index sets, none differing from the
host's (`tests/backports/host/uikit2`, the `orderedcollections` group). The shortest edit script is the Myers algorithm walked forward, so the
indexes match, and the difference of two ordered sets is not the same algorithm but a walk of both with a cursor each, which keeps fewer elements and is
the system's. `facts/Foundation/NSOrderedCollectionDifference.md`.

`NSDiffableDataSourceSnapshot`, `UICollectionViewDiffableDataSource` and `UITableViewDiffableDataSource` build on it. The snapshot, with its
exceptions and their reasons, is held to the system's over 50000 operations per run; the data sources are the view's data source and give a
collection or table view one batch of inserts, deletes, moves and reloads per snapshot applied, the reloads in a second batch, and are run
beside the system's in a window (the `diffabledatasource` group). They answer the same counts, index paths and identifiers after every apply,
and a batch the port cannot prove consistent for iOS 6 - items moving between sections, section changes mixed with item changes - is a `reloadData`, losing the animation. The apply is synchronous on the main queue.
`NSDiffableDataSourceSectionSnapshot`, `-applySnapshot:toSection:animatingDifferences:` and `-snapshotForSection:` come with iOS 14; the handlers
for reordering and for expanding are **inert** and say so once in the log, and the transaction classes are absent, since iOS 6 has no interactive
reordering and no outline cell. The members of iOS 15 are not answered. `facts/UIKit/NSDiffableDataSourceSnapshot.md`,
`NSDiffableDataSourceSectionSnapshot.md`, `UICollectionViewDiffableDataSource.md`, `UITableViewDiffableDataSource.md`.

### Lists and cell configurations, laid out from what the host measured

`UIListContentConfiguration`, `UIBackgroundConfiguration`, the configuration states, `UIListContentView`, the `UICellAccessory` family,
`UICollectionViewListCell`, `UICollectionLayoutListConfiguration` with the list section and layout, the cell registrations and the
configuration of collection view cells, table cells and table headers are carried in full. The values come from the host's UIKit under Mac
Catalyst, so the margins and sizes are those of the Mac idiom: the port follows them, except the row estimate of a list layout, which is 44
and not the host's 40.04. This release has no self sizing cells, so a row stays that high. The swipe actions of the providers of a list slide the row and run their handlers, the outline disclosure expands and collapses the items of a section
snapshot and calls the handlers of the data source, and the reorder grip drags a row, with an interactive movement of the collection view built on the
release that has none (`UICollectionViewInteractiveMovement.md`); the data source is told of each step of a drag as it happens, and not once at the end. Not carried:
the background decoration item, the blur and shadow of a reordering row, `selectionFollowsFocus` and the system colour transformers (`absent`). Members of iOS 15 and later
(`configurationUpdateHandler`, `isPinned`, `separatorConfiguration`) are not answered. Facts: `facts/UIKit/UIListContentConfiguration.md`
and its neighbours; the entries are in `registry/UIKit/ios14lists.json`.

### Commands, actions and menus on controls, appearance traits, dynamic colours and the rest of what UIKit added

`UICommand`, `UICommandAlternate` and a `UIKeyCommand` that is one are carried as the host has them (defaults, equality, copies, exceptions, archive: the `commands` group), and
`UIActivityItemsConfiguration` with an `UIActivityViewController` made of it. What a control does with an action is real, not present: `addAction:forControlEvents:`,
`removeAction:...`, `enumerateEventHandlers:`, `sendAction:` and every initialiser with a primary action work on any `UIControl` through proxy targets, the primary action
is registered for the event that triggers it on this release (touch up inside, value changed, editing did end on exit), and a button, a bar button item and a segmented control
made of actions and menus run them; a menu of a button or a bar button item is shown as the action sheet of the context menu interaction, and so is the menu a table row or
collection view item asks for by its delegate. Tables and collection views get their interaction when the delegate is set, so `contextMenuInteraction` is never nil. The
answers are held to the host's in processes that do not share the port's code (`controlactions`, `controlmenus`, `listmenus`); what differs is in
`facts/UIKit/UIControlActions.md` and `UIControlMenus.md`: the pairs and the actions of `enumerateEventHandlers:` do not interleave, a menu as a primary action shows on touch up
inside and not on touch down, and a bar button item's `target` and `action` are the port's.

The four appearance traits and `+currentTraitCollection` are carried with the trait collection, held to the host over 2434 checks: the screen is light, normal, base and active,
and `performAsCurrentTraitCollection:` nests. Dynamic colours and the 25 semantic colours are real too, with a limit that is not a difference the tests can see: a dynamic colour
is a colour of the release with its provider beside it, so what reads it - a view, a label, `CGColor` - reads the light value, and only `resolvedColorWithTraitCollection:` reads
another. The host's palette is the Mac's, so only the colours it shares with iOS 13 (the link, the fills, the grays) are held to it; the rest is Apple's published iOS 13 table
(`facts/UIKit/UIColorDynamic.md`).

`viewIsAppearing:`, `textFieldDidChangeSelection:`, the unwind segue question of iOS 13, the orientation message of a window scene delegate, `UITextInteraction` (tap, double tap, triple
tap and long press on a text input, with no handles or loupe), `-replaceRange:withAttributedText:`, `showCGGlyphs:...`, `imageWithTintColor:` (drawn byte for byte as the host does),
baselines, `+imageNamed:inBundle:withConfiguration:`, five system images the port draws itself, `UIBarButtonItem`'s space items and the monospaced system font are real. Kept
and read back with nothing reading them - `inert`, each said once in the log - are what belongs to a device or a service iOS 6 has none of: the large content viewer, the Apple
Pencil's scribble, the screenshot service, the font panel, the pointer lock, the override of the interface style, the modal that resists dismissal, the page control's images, the
date picker's compact and inline styles (it draws wheels, and says so in `datePickerStyle`), the font picker (it cannot hand back a descriptor that iOS 6 does not have and offers
Cancel), the pattern detection of the pasteboard (no pattern found), and a handful of properties that belong to the Mac idiom. `NSToolbar`, the columns of a split view
controller, the storyboard creators, the document picker of content types and the accessibility name of a colour are absent; the delegate methods of things that do not fire are
declared and never sent. `facts/UIKit/UIRestAbsent.md` gives the reason for each.

## iOS 11 and 12

These two releases are read differently from the ones before them. The last
firmware with a 32-bit slice is 10.3.4, so there is no armv7 implementation of
anything iOS 11 added; the behaviour is read from arm64 - from 11.0 and 12.0
themselves, where the calls still go through `objc_msgSend` and the selectors
can be read, and from 16.0 and 18.0 for the numbers a later release corrected -
and the code here is written anew for armv7 and armv7s. What a facts file under
`facts/` names is what was read; nothing in this range was carried over from an
older implementation.

### Foundation of iOS 13 and 14, carried and held against the host

145 names of Foundation are decided in `registry/Foundation/ios13found.json`: 119 carried, 2 inert and 24 absent.
Carried: the error-returning `NSFileHandle` methods, `NSData` compression (ZLIB, LZ4 and LZMA in both directions;
LZFSE as stored blocks only, since compressed LZFSE has no public specification), `NSListFormatter`,
`NSUnitInformationStorage`, the `NSByteCountFormatter` measurement forms, `-[NSHTTPURLResponse valueForHTTPHeaderField:]`,
the secure collection decoders of `NSCoder` and `NSKeyedUnarchiver`, `NSOperationQueue` barriers and progress,
`NSURLSessionWebSocketTask` (an RFC 6455 client), expensive and constrained network access, `NSHTTPCookie` SameSite,
`NSURLCache` with a directory URL, the new URL resource keys, and the small members (`NSDate.now`, the post-order
enumerator flag, `macCatalystApp`, `iOSAppOnMac`, `targetContentIdentifier`). Inert: `NSURLContentTypeKey` and
`NSURLFileContentIdentifierKey` answer no value. Absent: the `NSXPC` members, which cannot work without a service an
iOS 6 application can ship, the TLS version bounds and the transaction metrics properties. The facts are in
`facts/Foundation/`; the proof is the `foundation14*` groups of `tests/backports/host/uikit2/run.sh` and
`tests/backports/device/foundation14.m`.

### Carried

Foundation gets the secure coding surface of the archivers: an archiver created
requiring secure coding and asked for its `encodedData`, an unarchiver reading
from data with an error, and the two convenience class methods that stand for
the whole round trip. Beside them: the property list readers and writers that
take a URL and fill in an error, `NSURLComponents`'
`percentEncodedQueryItems`, `-decodeValueOfObjCType:at:size:`,
`NSSecureUnarchiveFromDataTransformer`, and the validated format constructors
of `NSString`, which are the ones a program uses when the format string comes
from outside it.

UIKit also gets the list of interactions a view holds - the list, the two
callbacks an interaction is told its move by, and the owner - which is
bookkeeping the release can do even though Apple's own interactions of that
release cannot be carried, and the attributed label, hint and value of
accessibility, whose text reaches this release's VoiceOver through the plain
property it has kept since iOS 3.

UIKit gets directional edge insets whole - the struct's zero, its two string
functions, its `NSValue` and `NSCoder` surface - and then the parts of the safe
area that are values rather than moments: `-safeAreaInsets` on a view,
`additionalSafeAreaInsets` on a controller, and on a scroll view
`adjustedContentInset` with the `contentInsetAdjustmentBehavior` that decides
it. With them come `directionalLayoutMargins`, the two comparison functions of
the content size categories, the large title text style, `UIFontMetrics`, the
system spacing anchors, the name of a gesture recognizer, and
`-performBatchUpdates:completion:`.

The renderer formats get `+preferredFormat` and
`+formatForTraitCollection:`. The preferred format is the default one: in 11.0,
12.0 and 18.0 alike, the image format answers its own `+defaultFormat`. A trait
collection sets the scale and whether the format prefers an extended range, and
nothing else.

A program built for a release that has these frameworks asks each of them one
question before it does anything else, and a program recompiled for this one
links the classes it asks it of. So the classes and the question are carried
where the answer is a plain one: `DCDevice`, with the one shared object and
`-isSupported` answering YES as the release's own constant does;
`ARConfiguration` and the five subclasses of iOS 11 and 12, whose
`+isSupported` answers NO, since ARKit asks for an A9 chip and these devices
have an A5; and `NFCReaderSession` with `NFCNDEFReaderSession`, whose
`+readingAvailable` answers NO on a device with no NFC. The error domains an
application compares an error against, `DCErrorDomain`, `ARErrorDomain` and
`NFCErrorDomain`, are carried with the release's strings. Everything behind the
question - a token, a session, a setting, an anchor, a tag - is absent, and
`respondsToSelector:` and `NSClassFromString` say so.

`NSProcessInfo.thermalState` answers nominal and its notification is never posted, and the export presets of the image picker are kept and not applied: the release publishes no thermal pressure level a process can read, and its picker hands over a JPEG and transcodes a movie by its quality. All three are `inert`, and each says so once in the log.

The five key functions of iOS 10 - `SecKeyCreateRandomKey`, `SecKeyCopyPublicKey`, `SecKeyCreateEncryptedData`, `SecKeyCreateDecryptedData` and `SecKeyCopyExternalRepresentation` - are carried in `libSecurityBackports.dylib` over what iOS 6 already has. The release generates the pair itself with `SecKeyGeneratePair` and reads its own `kSecAttrIsPermanent`; the public key of a private one is the release's private `SecKeyCopyPublicBytes` followed by `SecKeyCreateFromPublicData`, which divides RSA from elliptic curve by the key's own algorithm identifier, so the port names no encoding of its own; and the algorithm of iOS 10 becomes the padding of `SecKeyEncrypt` and `SecKeyDecrypt` for the three the release can do - raw, PKCS1 and OAEP with SHA-1. Every other algorithm is refused with NULL and a CFError of `errSecParam` that names it, because iOS 6's OAEP carries no choice of digest and answering an OAEP-SHA256 call with SHA-1 padding would be a different cipher text under the name of the one that was asked for. `SecKeyCopyExternalRepresentation` answers a private key's PKCS#1 representation only where the release really keeps one, which the port parses before it trusts it, and the public one only where the key is proven to be public; where the release keeps neither the answer is a CFError, never the public half in place of a private key. Every error is domain `NSOSStatusErrorDomain` with the release's own OSStatus. `facts/Security/SecKey.md`.

`SecTrustEvaluateWithError` is carried over the release's own `SecTrustEvaluate`: the verdict is the newest Security's, and the error it makes says what the newest Security says for an untrusted root, a name that does not match and an expired certificate, read from the four English strings the release gives for a failed evaluation. A language in which the release words them differently gets the not trusted error. `SecCertificateCopyKey` and `SecCertificateCopySerialNumberData` come with it, in `libSecurityBackports.dylib`, built with the `security` config, so that a process which never evaluates a trust does not load Security for them.

`CGColorSpaceGetName`, `CGPathApplyWithBlock`, `CGImageGetByteOrderInfo`, `CGImageGetPixelFormatInfo`, `CGPDFArrayApplyBlock` and `CGPDFDictionaryApplyBlock`, the six functions that turn the code points of a video colour description into names and back (`CVColorPrimaries`, `CVTransferFunction` and `CVYCbCrMatrix`, each way) and the constants iOS 11 and 12 added beside them come in `libGraphicsBackports.dylib`, built with the `graphics` config, so that a process which reads none of them loads neither CoreGraphics nor CoreVideo for them. The tables are the iOS 12 ones: a code point that release names nothing for gets the string it makes, `ColorPrimaries#7`, and reads back. iOS 6 names a generic RGB space as the device one, so that is the name `CGColorSpaceGetName` answers for it. The outline and access permission keys of a PDF, the colour conversion object, the info pointer of a data provider and the colour space constants of 12.3 and 12.6 are absent, each with its reason in the registry.

`UIDragItem`, `UIDropProposal`, `UIDragInteraction` and `UIDropInteraction`, with the drag and drop delegates and switches of `UITableView` and `UICollectionView` and the drag hooks of their cells, are carried as the surface an application configures: everything is held and nothing ever begins, so no drag starts, no drop enters a view and no delegate is asked. `+[UIDragInteraction isEnabledByDefault]` answers NO on every device, an iPad included, where iOS 12 answers YES there.

`ASWebAuthenticationSession` is carried in `libAuthenticationServicesBackports.dylib`, built with the `authenticationservices` config, which brings `libSafariServicesBackports.dylib`: it is a wrapper over the `SFAuthenticationSession` of that library, as it is in iOS 12, and gives the callback URL, or an error of `ASWebAuthenticationSessionErrorDomain` with code 1 for a cancel. The credential provider and the credential identity store are absent. `facts/AuthenticationServices/ASWebAuthenticationSession.md`.

`NSPersistentHistoryChangeRequest` and the objects around it (`NSPersistentHistoryToken`, `NSPersistentHistoryTransaction`, `NSPersistentHistoryChange`, `NSPersistentHistoryResult`) are carried in `libCoreDataBackports.dylib` as what an application names and asks with: the request holds its date or token and result type as iOS 12 does, the abstract classes raise the exception iOS 12 raises, and no store of this release keeps a history, so nothing answers a request, `currentPersistentHistoryTokenFromStores:` answers `nil` and the remote change notification is never posted. `NSManagedObjectContext.transactionAuthor` is kept and read by nothing. `facts/CoreData/PersistentHistory.md`.

`PHPhotoLibrary` is carried in `libPhotosBackports.dylib`, built with the `photos` config, with the classes it reads and changes the library through, all over the `ALAssetsLibrary` of the release: `PHAsset`, `PHAssetCollection`, `PHCollectionList`, `PHFetchOptions`, `PHFetchResult`, `PHImageManager` and `PHCachingImageManager` with their option classes and keys, `PHAssetChangeRequest` and `PHObjectPlaceholder`. `+authorizationStatus` is the `ALAssetsLibrary` status, `+requestAuthorization:` shows the system prompt through a read of the saved-photos group, and the calls with an access level of iOS 14 answer the same, never limited. A fetch is empty until the application is authorized; then it returns the assets and albums of the release in order of date, with the predicate, sort descriptors and limit applied, an image comes from the thumbnail, the full-screen image or the full-resolution image of the asset, drawn to the size and content mode asked for, and a video is an `AVURLAsset` on its address. `-performChanges:completionHandler:` and `-performChangesAndWait:error:` add an image or a video to the saved photos, with its date and location written as image metadata; deleting, editing an asset, a favorite and a hidden asset fail the whole change with `PHPhotosErrorChangeNotSupported` before anything is written. What the release cannot tell is not made up: no favorites, hidden assets, bursts, media subtypes or modification dates, and the smart albums other than the camera roll, the videos and the empty favorites, hidden and bursts are not made. Observers, cloud identifiers, the history of changes, live photos, content editing and the asset resources are absent. `facts/Photos/Assets.md`, `facts/Photos/ImageManager.md`, `facts/Photos/Changes.md`, `facts/Photos/PHPhotoLibrary.md`.

The rest of Photos and of PhotosUI is absent, each row in `registry/Photos/absent_Photos.json` and `registry/PhotosUI/absent_PhotosUI.json`: the resource managers, live photos, content editing, the change requests for collections and the persistent changes need the Photos database, and nothing in iOS 6 does their work. `PHPhotoLibrary`, `PHAdjustmentData`, `PHContentEditingInput` and `PHContentEditingOutput` are declared by the headers of both frameworks, and are decided once, in the file of Photos, so the difference of PhotosUI alone shows those four classes as undecided.

`GCController`, `GCMouse` and `GCKeyboard` are carried in `libGameControllerBackports.dylib`, built with the `gamecontroller` config, for what an application asks before there is a device: `+[GCController controllers]` and `+[GCMouse mice]` are empty, `+current` and `+coalescedKeyboard` are nil, the discovery ends at once and calls its handler on the main queue, and the notification names exist and are never posted. No device is ever attached, so no object of these three classes exists, and their mouse and keyboard members are absent. The names of the inputs, keys and haptics of iOS 14 are carried as strings and key codes, with the values of the host's GameController. What software can make is carried whole: `+controllerWithExtendedGamepad` and `+controllerWithMicroGamepad` make a controller that is a snapshot, with the extended or micro gamepad, its buttons, axes and direction pads, the motion, `-capture` and the state copies, and the handlers of the elements are called on the handler queue as the host calls them; the port is held to the host's GameController over a random sequence of 4000 values (8576 lines, none differs). `GCColor` and `GCEventViewController` are carried whole, and the classes of the Xbox, DualShock and DualSense profiles, the touchpad, the light, the battery, the haptics and the keyboard and mouse inputs are carried for what names them, with no object of them ever made. The snapshots and their data functions, the virtual controller and the physical input protocols of iOS 16 stay absent. `facts/GameController/GameController.md`, `facts/GameController/ControllerModel.md`.

`NSBatchDeleteRequest` and `NSBatchDeleteResult`, with the `-[NSManagedObjectContext executeRequest:error:]` that runs them, are carried in `libCoreDataBackports.dylib`. The removal is done in a private context on the same coordinator, which leaves the calling context as iOS 12 does but runs delete rules and validation and posts a did save notification, which iOS 12 does not; a fetch request or a save request given to `executeRequest:error:` is executed by the release's own coordinator. `facts/CoreData/BatchDelete.md`.

`kSecAttrSynchronizable` and `kSecAttrSynchronizableAny` are carried in `libSecurityBackports.dylib`, as the strings `sync` and `syna`; the keychain of iOS 6 ignores the attribute, so an item marked synchronizable stays on the device and a query for either finds the items of the device. `kSecUseAuthenticationUI` and `kSecAttrTokenID` are not carried, as the release refuses them with -50. `facts/Security/kSecAttrSynchronizable.md`.

`NSFetchIndexDescription`, `NSFetchIndexElementDescription` and `NSEntityDescription.indexes` are carried and checked the way iOS 12 checks them, and not applied: the store of this release builds no index from them, which the documentation of `indexes` allows. `NSCoreDataCoreSpotlightDelegate` is absent: `corespotlight`'s `CSSearchableIndex` carries its own store now (`facts/CoreSpotlight/CoreSpotlight.md`), but the automatic Core Data bridge onto it is not built. `facts/CoreData/FetchIndex.md`.

`MTLCreateSystemDefaultDevice` is carried in `libMetalBackports.dylib`, built with the `metal` config, and answers nil, as Metal does where the hardware has no driver: iOS 6 runs on the A4 and A5, so an application that falls back to OpenGL ES when it is given no device does so. The rest of Metal and MetalKit is absent. `facts/Metal/MTLCreateSystemDefaultDevice.md`.

`NSQueryGenerationToken`, `-[NSManagedObjectContext queryGenerationToken]` and `-setQueryGenerationFromToken:error:` are carried without a snapshot to read (see the container above), and `NSConstraintConflict` is carried as a value that nothing here makes, since the store of iOS 6 enforces no uniqueness constraint; `uniquenessConstraints` and the merge policy that resolves the conflicts are absent. `facts/CoreData/QueryGeneration.md`, `facts/CoreData/ConstraintConflict.md`.

`+[AVCaptureDevice authorizationStatusForMediaType:]` and `+requestAccessForMediaType:completionHandler:` are carried in `libAVFoundationBackports.dylib`: iOS 6 asks nobody for the camera or the microphone, so the microphone is authorized and the camera is authorized unless ManagedConfiguration says the camera is restricted, the request never shows a prompt, and a media type other than audio or video raises as iOS 12 does. Most of the rest of AVFoundation and AVKit that iOS 6 lacks is absent, each row in `registry/AVFoundation/absent_AVFoundation.json` and `registry/AVKit/absent_AVKit.json` - except where the camera and microphone the device has make it real work rather than a wall, below. `facts/AVFoundation/AVCaptureDeviceAuthorization.md`.

`AVCaptureDevice.activeVideoMinFrameDuration` and `.activeVideoMaxFrameDuration` are carried as real front ends onto `AVCaptureConnection.videoMinFrameDuration`/`videoMaxFrameDuration`, deprecated in the same release these device-level properties replace them but present and functional since iOS 5.0 - iOS 6.1.3's own AVFoundation already exports `activeFormat` and `videoSupportedFrameRateRanges` ahead of their public iOS 7.0 documentation. A stored duration is applied to every video connection of every session a device's input is added to, reapplied whenever a session adds an input or output, starts running, or commits a configuration change; read without ever being set, it computes the shortest or longest duration across the active format's supported frame rate ranges, the header's own documented default. `facts/AVFoundation/ActiveFrameDuration.md`.

`AVMetadataItem.dataType`, `.extendedLanguageTag` and `.identifier`, their `AVMutableMetadataItem` readwrite counterparts, and the three class-side identifier conversions are carried: `AVMetadataItem` has been real on iOS 6 since 4.0, and all three properties are derivable from ones the class already carries - `dataType` from the class of `.value` (an `NSString` is UTF-8, an `NSNumber` is the integer or float width its `objCType` names, an `NSData` is sniffed for JPEG/PNG/GIF/BMP magic bytes or called raw data, all in the release's own `CMMetadataBaseDataType` string values, read out of CoreMedia of the armv7 shared cache of iOS 8.0 since iOS 6.1.3's own CoreMedia does not export them yet), `identifier` from `.key` and `.keySpace` joined as `"<keySpace>/<key>"`, and `extendedLanguageTag` from `.locale` with underscores turned to hyphens. `facts/AVFoundation/AVMetadataItemIdentifiers.md`.

`AVCaptureDataOutputSynchronizer`, `AVCaptureSynchronizedDataCollection`, `AVCaptureSynchronizedData` and `AVCaptureSynchronizedSampleBufferData` are carried for `AVCaptureVideoDataOutput` and `AVCaptureAudioDataOutput`, whose own `-setSampleBufferDelegate:queue:` has been on iOS 6.0 from the start: the synchronizer takes over each output's delegate, and on every buffer its master output receives, delivers a collection carrying that buffer alongside whichever buffer was most recently received from every other output - an honest simplification of the release's own presentation-timestamp windowing, not a re-implementation of it. `AVCaptureSynchronizedMetadataObjectData` and `AVCaptureSynchronizedDepthData` are carried as real classes so their symbols resolve, but this port's synchronizer never constructs either: metadata-object synchronization was not this pass's demand, and the iPhone 4S and iPad 2 this port targets have no depth-capable camera at all. `facts/AVFoundation/DataOutputSynchronizer.md`.

CoreGraphics of iOS 6 already exports `CGPathAddRoundedRect`, the `CGColorCreateGeneric...` functions, `CGColorGetConstantColor` and seven `kCGColorSpace...` names, and the registry records them as the release's own, held to the host's CoreGraphics by `tests/backports/device/coregraphics7.m`. `CGColorSpaceCreateWithName` makes a space for `kCGColorSpaceGenericRGB`, `...Gray` and `...CMYK` only, and answers NULL for `kCGColorSpaceSRGB` and the other names it exports, so a bitmap context made with an sRGB space by name is NULL. `libGraphicsBackports.dylib` carries `CGColorSpaceCopyICCData` (the release's `CGColorSpaceCopyICCProfile`) and `CGColorSpaceUsesExtendedRange`, `CGColorSpaceIsHDR`, `CGColorSpaceUsesITUR_2100TF`, `CGColorSpaceIsHLGBased` and `CGColorSpaceIsPQBased`, which answer NO for every space, as the release makes none of those. The names of the spaces it does not export are absent. `facts/CoreGraphics/CGColorSpace.md`.

The eight CVMetalTexture functions of iOS 8 (`CVMetalTextureCacheCreate`, `CVMetalTextureCacheCreateTextureFromImage`, `CVMetalTextureCacheFlush`, `CVMetalTextureCacheGetTypeID`, `CVMetalTextureGetCleanTexCoords`, `CVMetalTextureGetTexture`, `CVMetalTextureGetTypeID` and `CVMetalTextureIsFlipped`) are carried in `libGraphicsBackports.dylib` so their hard-linked import resolves: iOS 6 runs on graphics with no Metal, so they answer the way a device without the hardware does, never making a cache or a texture. `facts/CoreVideo/CVMetalTexture.md`.

The rest of ImageIO and CoreVideo that arrived after iOS 6 is absent, each row in `registry/ImageIO/absent_ImageIO.json` and `registry/CoreVideo/absent_CoreVideo.json`; iOS 6 exports `CGImageSourceCopyMetadataAtIndex`, the eight `kCGImageMetadataNamespace...` names, `kCGImagePropertyPNGCompressionFilter` and `kCGImageSourceSubsampleFactor` itself, which the registry records as the release's own. `facts/ImageIO/ImageIOExports.md`.

The seventeen classes of CallKit and its four error domains are carried in `libCallKitBackports.dylib`, built with the `callkit` config, for an application that places and takes calls of its own: `CXProvider` reports them, `CXCallController` asks for them, `CXCallObserver` watches them, and the actions, the transaction, the handle, the update and the configuration are the objects they are asked with. CallKit's own truth lives in `callservicesd`, which iOS 6 does not run and which the port cannot install, so the three classes meet in a broker of the port's own, one per process: an application sees its own calls and no others. What an application reads off the objects before a call starts is the release's, to the character and the second - the error domains, the defaults of a configuration, the ten minutes a start action has and the minute an answer action has, the completeness of a transaction, the equality of a handle - held to the host's CallKit under Mac Catalyst by `tests/backports/host/callkit/run.sh` over 43 records, with the two that release no longer carries stated apart. The observer also reports the calls the device makes itself: `CTCallCenter` is in iOS 6 and is the whole of what a third party may see of a cellular call, so making the first observer of the process starts a watch on it, and a cellular call appears beside the application's own with a UUID of the port's making. It belongs to no provider, so an action asked for against it is refused rather than handed to a delegate that never made it. A call of a provider connecting activates the shared `AVAudioSession` and the delegate is told, as CallKit does it; the category and the mode stay the application's own. The call directory is an application extension and stays absent. `facts/CallKit/CallKit.md`.

`CSSearchableIndex`, `CSSearchableItem` and `CSSearchableItemAttributeSet` are carried in `libCoreSpotlightBackports.dylib`, built with the `corespotlight` config, for the two applications of the corpus that strong-import them: the classes are real, `CSSearchableItem` generates a UUID when none is given and defaults its expiration a month out as the header says, and `CSSearchableItemAttributeSet` carries the 19 properties of the `CSGeneral` category with real storage, `NSCopying` and `NSSecureCoding`; the later Images, Media, Documents, Events, Places, Messaging and custom-key categories are not. iOS 6.1.3 has no CoreSpotlight-shaped system index, so `CSSearchableIndex` keeps its own journal, a per-index store under Application Support: writes, both delete methods, `deleteAllSearchableItemsWithCompletionHandler:` and the batch client state all land there and answer with a nil error, `isIndexingAvailable` answers YES, and every mutation also registers the index's category with the release's own private `Spotlight.framework` class `SPSpotlightManager` and pushes the changed identifiers to it - the same pull mechanism the release already runs for Messages and Calendar - best-effort and never fatal if the private surface is absent. `CSSearchableItemActionType` and `CSSearchableItemActivityIdentifier` are carried at the release's own values, read out of the arm64 shared cache of iOS 12.0, though neither is ever posted: reaching the device's actual Spotlight UI needs a search bundle of this port's own in `/System/Library/SearchBundles/`, real and buildable but a distinct, larger, unattempted feature, not part of what `CSSearchableIndex` itself promises. `facts/CoreSpotlight/CoreSpotlight.md`.

`PKPushRegistry`, `PKPushCredentials`, `PKPushPayload` and the three `PKPushType` constants are carried in `libPushKitBackports.dylib`, built with the `pushkit` config, for an application that places and takes VoIP calls. iOS 6.1.3's own `apsd` already hands a real device token to `-[UIApplication registerForRemoteNotificationTypes:]` (measured on an iPhone 4S and an iPad 2, `facts/UIKit/UIApplicationNotificationRegistration.md`), so `PKPushRegistry` bridges to it instead of answering with a fake or absent one: setting `desiredPushTypes` to include `PKPushTypeVoIP` delivers a cached token at once if one is held and re-asks `apsd` with any `UIUserNotificationType` the application already registered on its own, and `RevenantPushBridge` chains onto the application delegate's `-application:didRegisterForRemoteNotificationsWithDeviceToken:` the first time `-setDelegate:` names it, so every live registry hears a token as soon as the OS hands one out. The one seam this port cannot reach: `apsd`'s protocol on this release ties every token to a nonzero Badge/Sound/Alert bitmask, with no silent fourth bit the way later releases eventually grew one, so a registry with no prior, separate `-registerUserNotificationSettings:` call from the application never receives a token - manufacturing one by asking for a type the application never requested would put up a permission alert as a side effect of a call that is supposed to show nothing, a worse dishonesty than the gap. Incoming push delivery is not wired for the same reason as the token silence: `apsd` wakes no suspended application for any push on this release, so forwarding only the narrow foreground/background window iOS 6 already grants would misrepresent the one behaviour PushKit exists for. `facts/PushKit/PushKit.md`.

The rest of MetalPerformanceShaders, CoreML, Vision, MediaPlayer, LocalAuthentication, SafariServices, QuartzCore and Security that arrived after iOS 6 is absent, each row in `registry/<Framework>/absent_<Framework>.json`, decided once in the framework that owns it where two headers declare it. JavaScriptCore is the one of that list the release carries whole, so its twenty-six C API rows are not decided by its export table: twelve are carried and fourteen are absent, in `registry/JavaScriptCore/capi.json` and `registry/JavaScriptCore/absent_JavaScriptCore.json`, and `facts/JavaScriptCore/CAPI.md` has the measurements. The C names that iOS 6 already exports itself are recorded as the release's own: thirteen of the JavaScriptCore C API (`facts/JavaScriptCore/JavaScriptCoreExports.md`) and five of Security (`facts/Security/SecurityExports.md`). The C API JavaScriptCore itself arrived after iOS 6 in twenty-six names, and a family where the library exists is the opposite of one where it does not: eight of the twenty-six are questions the release's own 2012 engine answers (`JSValueIsArray`, `JSValueIsDate`, `JSValueIsSymbol` and the four `JSObject…PropertyForKey`), one hands back the port's own promise (`JSObjectMakeDeferredPromise`), four are the Web Inspector's fields for a context and are carried inert because nothing here can attach an inspector, and fourteen name a value the engine has none of - a typed array, an ArrayBuffer, a symbol to make - and are absent with the capability named.

The eleven `CTRadioAccessTechnology...` names and `CTRadioAccessTechnologyDidChangeNotification` are carried in `libCoreTelephonyBackports.dylib`, built with the `coretelephony` config, with `CTTelephonyNetworkInfo.currentRadioAccessTechnology`: iOS 6.0 has none of them, and iOS 6.1.3 exports all the names but WCDMA and keeps the technology in a private class, whose string is spelled `CTRadioAccessTechnologyWCMDA` for WCDMA, so the property answers the string with the value iOS 7 gives, and nil on iOS 6.0. The per-service dictionaries of iOS 12, the delegate of iOS 13, `CTCellularData` and the two 5G names are absent. `facts/CoreTelephony/CTRadioAccessTechnology.md`.

`libSecurityBackports.dylib` carries what iOS 8 and 9 added to the keychain as names and answers of a release that has none of it: the constants `kSecAttrAccessControl`, `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`, `kSecUseOperationPrompt`, `kSecUseNoAuthenticationUI`, `kSecSharedPassword`, `kSecUseAuthenticationContext` and `kSecUseAuthenticationUI` with its three values, which the keychain of iOS 6.1.3 refuses with -50 (`errSecParam`) as it refuses any key it does not know; `SecAccessControlCreateWithFlags`, which answers NULL with `errSecUnimplemented`; `SecAddSharedWebCredential`, whose block gets that error; `SecRequestSharedWebCredential`, whose block gets an empty array and no error; and `SecCreateSharedWebCredentialPassword`, which makes `xxx-xxx-xxx-xxx` as the host's Security does. `kSecAttrTokenID` and the Secure Enclave value stay absent. `facts/Security/KeychainAccessControl.md`.

`libAccelerateBackports.dylib`, built with the `accelerate` config, carries `vImageBuffer_Init`, `vImageBuffer_InitWithCGImage` and `vImageCreateCGImageFromBuffer` of iOS 7 over the release's CoreGraphics, for the 8-bit RGB formats (32 bits with alpha first or last, premultiplied or not or skipped, in the three byte orders; 24 bits), held to the host's vImage by `tests/backports/host/accelerate7` and `tests/backports/device/accelerate7.m`, with the differences that `facts/Accelerate/vImageBuffer.md` lists: a NULL colour space is the device RGB space, other formats answer `kvImageInvalidImageFormat`, and the rows are padded to 16 bytes. It also carries the 420 Y'CbCr conversions of iOS 8 that the corpus asks for - the four `kvImage_*Matrix_ITU_R_*` constants with the coefficients the newer release holds, the two `_GenerateConversion` functions over an opaque structure of the port's own, the four conversions between `ARGB8888` and `420Yp8_CbCr8`/`420Yp8_Cb8_Cr8`, and `vImageExtractChannel_ARGB8888`. The arithmetic is the one the header writes out, in `float` where the system works in fixed point: 4262 of 457920 bytes differ from the system's by exactly one and none by more, over four pixel ranges, both matrices, four sizes and four permutations, and the port's byte is the correctly rounded one. A Y'CbCr type outside the two 420 8-bit ones is refused with `kvImageUnsupportedConversion`, which the system carries and the port does not. `facts/Accelerate/vImageYpCbCr.md`. `vImageConvert_RGB565toBGRA8888`, `vImageConvert_BGRA8888toRGB565`, `vImageConvert_ARGB16UtoRGB16U` and `vImageConvert_ARGBFFFFtoRGBFFF` of iOS 7 come with them, byte for byte the system's answers - the arithmetic of the five and six bit channels is the integer one the header writes out, and the other two drop the first channel of each pixel. A destination larger than the source is `kvImageRoiLargerThanInputBuffer` in all four, which is what the release answers although the header's comment above the 565 expansion names another code. `facts/Accelerate/vImagePixels.md`. `libGraphicsBackports.dylib` carries `kCIInputAngleKey`, `kCIInputRadiusKey` and `kUTTypeScalableVectorGraphics` as their strings. `facts/CoreImage/InputKeysAndSVG.md`.

`CAMetalLayer` is carried in `libMetalBackports.dylib`, as a layer that keeps its device, pixel format, drawable size and the rest of what it is given, and has no drawable: `nextDrawable` is nil and `preferredDevice` is nil, since iOS 6 has no Metal, so an application that asks for a drawable falls back to OpenGL ES; a maximum of drawables outside 2 to 3 raises the exception of iOS 12. The properties of iOS 16 are kept and used for nothing, and `CAEDRMetadata` is absent. `facts/QuartzCore/CAMetalLayer.md`.

`PHPickerViewController`, `PHPickerConfiguration`, `PHPickerFilter` and `PHPickerResult` are carried in `libPhotosBackports.dylib` over the release's `UIImagePickerController`, which the controller holds as a child for the media types of the filter: one item at most (a `selectionLimit` of more is kept and not honoured), an image offered as JPEG or, by the address the release gives it, PNG, GIF or TIFF, made from the image the picker returns, a video offered as the file the picker made, and `assetIdentifier` nil; the filters of iOS 15 and 16 and the selection of iOS 15 are absent. `UIImage` reads and writes itself through `NSItemProvider` as in iOS 11, in `libUIKitBackports.dylib`. `facts/Photos/PHPicker.md`, `facts/UIKit/UIImageItemProvider.md`.

`UIVisualEffectView` with a `UIBlurEffect` blurs what lies behind it, for real and not live: the view draws the layers of its window into a bitmap a quarter of the size, blurs it with a box filter, raises its saturation and mixes the tint of its style in, and shows the picture behind its content view, again about ten times a second while what is behind changes; the picture cannot hold what the window draws with OpenGL ES, and vibrancy is not carried. `facts/UIKit/UIVisualEffect.md`.

### Carried with a difference

Each of these is implemented, tested against the real implementation, and
departs from it in one named way; the facts file says so and the registry entry
repeats it.

`-[DCDevice generateTokenWithCompletionHandler:]` asks a daemon, `com.apple.devicecheckd`,
that iOS 6 does not run. The handler hears `DCErrorFeatureUnsupported` - the
header's word for DeviceCheck being unavailable on this device - from a
background queue, after the call has returned, where the release's own path
for a daemon it cannot reach answers `DCErrorUnknownSystemFailure`. That is the
one departure, chosen because an application that reads the documentation
handles the first as a settled answer and the second as a reason to retry.
`facts/DeviceCheck/DCDevice.md` has what was read from the release, what came from
the header and what the host answered.

The safe area insets and the adjusted content inset are computed on every read
rather than stored, because nothing here tells the port when they change. An
application that reads them gets the same numbers; one that expects a stored
value to go stale between layouts does not.

`+[NSArray arrayWithContentsOfURL:error:]` fills in an error where 11.0 answers
nil and leaves the error empty for a plist whose top level is of the wrong
kind, and `+[NSKeyedArchiver archivedDataWithRootObject:requiringSecureCoding:error:]`
returns the error that 11.0 and 12.0 let escape as an exception. Both are the
later releases' behaviour, which is the rule for this package.

`UIFontMetrics` scales by a ratio that is one on this release: iOS 6 has a
single content size category, so a metric has nothing to scale between. The
arithmetic, the maximum point size and the rounding are the real ones, and a
release with more categories would need only the table. The system spacing
anchors follow the current implementation, which rounds the spacing up to the
screen scale, not iOS 11's, which did not. `percentEncodedQueryItems` refuses
a query with characters that do not belong in one, and the refusal comes from
the `NSURLComponents` backport underneath rather than from this code.
`-performBatchUpdates:completion:` always reports `finished` as YES: Apple's
completion says whether the animation ran to its end, and the Core Animation
transaction the port groups the updates in does not hand that back.

`NSLinguisticTagger` gets its units: word, sentence, paragraph and document
across `tokenRangeAtIndex:unit:`, the enumeration, the tags, the class
conveniences and `dominantLanguage`. Words are tagged by iOS 6's own tagger;
above the word only the Language and Script schemes answer, from the words of
the unit, where iOS 12 also gives lexical classes and lemmas. See
`facts/Foundation/NSLinguisticTagger.md`. `+[NSOrthography
defaultOrthographyForLanguage:]` stays absent: it is a table of about 250
languages inside iOS 12.

`SecCopyErrorMessageString` answers the sentence for a status from a table of
534 English texts carried in the Security library; a status the table lacks reads
`OSStatus` and its number, as it does in iOS 12. The language of the device is not
honoured. See `facts/Security/SecCopyErrorMessageString.md`.

Core Data's batch update and asynchronous fetch are carried, both executed with
`-executeRequest:error:`: a batch update sets the values of what its predicate finds, with
the keys and values checked as iOS 12 checks them; an asynchronous fetch answers its result at
once, fetches in a context of its own and delivers to its block on the context's queue, with a
progress when there is a current one, and cancels. Neither writes SQL the way the release does:
the objects are set and saved in a context of their own, so the model's rules apply to what a
batch update sets. `+mergeChangesFromRemoteContextSave:intoContexts:` brings a context up to
date afterwards. See `facts/CoreData/BatchUpdate.md`, `AsynchronousFetch.md` and `RemoteMerge.md`.

The port's `NSURLSession` waits for connectivity and delays requests as iOS 11 does: `waitsForConnectivity` and
a background session make a task that begins with no network say so through
`URLSession:taskIsWaitingForConnectivity:` and begin when it comes back, `earliestBeginDate` delays the tasks of
a background session and `willBeginDelayedRequest` lets the delegate continue, replace or cancel them. The size hints
`countOfBytesClientExpects...` are kept and read by nothing. See `facts/Foundation/NSURLSessionConnectivity.md`.

`NLTokenizer` and `NLLanguageRecognizer` of NaturalLanguage, with the 57 `NLLanguage` constants, are carried in
the Foundation library: words, sentences and paragraphs come from the release's `CFStringTokenizer` with the
attributes and emoji sequences of the system, and the recognizer votes sentence by sentence with the release's tagger.
The scripts the release cuts with a smaller dictionary (Chinese) and the probabilities of the recognizer differ, and
the rest of the framework (`NLTagger`, `NLModel`, embeddings) is not carried. See
`facts/NaturalLanguage/NLTokenizer.md` and `NLLanguageRecognizer.md`.

The path monitor of Network is carried in the Foundation library: `nw_path_monitor_*`, `nw_path_*` and `nw_interface_*`
of iOS 12, over the reachability of iOS 6, so that `NWPathMonitor` and `NWPath` have something to stand on. It reports
the path when it starts and when it changes, on the queue it was given, and says satisfied, unsatisfied or
satisfiable, the interface (`en0`, or cellular and expensive) and the addresses. Connections and the rest of Network are
not carried. See `facts/Network/NWPathMonitor.md`.

`libNetworkBackports.dylib`, built with the `network` config, carries the connection of Network: `nw_connection_create`
and its queue, path, viability, start and cancel, over a real BSD datagram socket - the host is resolved with
`getaddrinfo`, the socket is opened and connected, and viable means the kernel has a route to that address and the
path above is satisfied. It reports its path through the path monitor the Foundation library carries. The stream
parameters factories and the connection's data calls are absent rather than faked. It is what the Matter framework's
device browser needs, and its own use of Network is exactly this. See `facts/Network/NWConnection.md`.

The same library carries the objects of Network's C API, which are one file per family and per release
(`nw12-core.m` for the endpoint, the content context, the identity of a protocol and the options of IP, TCP, TLS and
UDP; `nw12-parameters.m`; `nw13-txtrecord.m`, `nw13-ws.m`, `nw13-framer.m`, `nw13-reports.m` and the browse and
advertise descriptors; `nw14-privacy.m`, `nw14-group.m` and the resolution reports; `nw134-quic.m`, `nw16-quic-options.m`; `nw16-*.m`;
`nw17-proxy.m`; `nw26-*.m`), with their state in `RevenantNW.h` and the pieces of C every file needs in
`RevenantNWSupport.c`. The file per release is what `modules/apple/backports.lua` asks for: an object that exports the
symbols of two introductions is split from under a band. What each of them answers was measured against the host's own
Network - an empty host is an endpoint only when its port names something, a final content context takes no more
change, two framer definitions of one name are different protocols, a record of no bytes is no record - and the two
places where the host contradicts its own header are written down where they are answered for. See
`facts/Network/NWObjects.md`.

### Not carried, and why

Nothing here is a quiet stub. Where the behaviour cannot be produced, the API
is `absent`: the class is not there, the method is not there, and
`respondsToSelector:` answers honestly, so an application that asks first keeps
working on its own fallback path.

Four callbacks report a moment rather than a value - `-safeAreaInsetsDidChange`,
`-viewSafeAreaInsetsDidChange`, `-adjustedContentInsetDidChange` and
`-scrollViewDidChangeAdjustedContentInset:`. A value can be carried wherever
the release's own behaviour produces it; the moment it changes is produced by
UIKit's layout, and reaching it means standing in for `-layoutSubviews` across
every view of the process. The same reasoning takes out the layout guides -
`safeAreaLayoutGuide`, `contentLayoutGuide`, `frameLayoutGuide`: a guide is
useful because the layout engine keeps its frame current, and a guide whose
frame nothing updates is worse for an application than no guide at all, because
constraints to it would resolve and be wrong.

The attributes inside an accessibility string are the mild case of the same
thing: the four keys of this range carry the strings UIKit gives them, so an
application can build such a string at all, but this release's VoiceOver speaks
the text and knows nothing of pronunciation, pitch, queued announcements or
heading levels.

Some API only means anything if the release's own code understands it. The
leading and trailing content alignments of a control are decided inside
`UIControl` while it lays its content out; mapping them to left and right would
be quietly wrong in a right-to-left language, which this release does have.
Smart quotes, smart dashes and smart insert-and-delete are substitutions the
keyboard makes, and this keyboard has no such rule. `largeContentSizeImage` is
drawn only where an accessibility content size category is in force, and there
is none here. `systemMinimumLayoutMargins` and
`viewRespectsSystemMinimumLayoutMargins` describe a minimum this release never
produces, so any number the port invented would be an invention.
`hasUncommittedUpdates` reports on bookkeeping the release's table does not
keep. The swipe actions - `UISwipeActionsConfiguration`, `UIContextualAction`
and the two delegate methods that hand them over - are absent as a whole,
classes included: carrying the value types so that they could merely be created
would leave an application believing it had configured a swipe that never
happens, while with them missing it falls back to the release's own swipe to
delete.

A navigation bar's large title and its search bar are laid out by the bar
itself, a home indicator and the system edge gestures that defer to it do not
exist on this hardware, a colour named in an asset catalogue is read by a
CoreUI that knows no such file, the exemption from inverted colours has to
reach the render server, the password rules of a text field are read by a
keyboard that generates none, and `UIScreen.captured` is answered by a service
that watches recording and mirroring. Dragging, dropping and spring loading are
the same story with a service of their own.

Whole families go out for one reason each, and the registry names every class
and protocol in them rather than the family: everything that hangs off a drag
session (the previews, the items, the sessions and the delegates, the drop
side, the row and item level of a table or a collection view, and text
dragging, dropping and pasting), spring loading, the focus engine, and the
document browser with the file provider world behind it. Four accessibility
protocols of that release go out too, because the VoiceOver here never asks the
questions they answer.

Two loose constants of iOS 11 are carried instead of refused, for a reason
worth naming: `UIImagePickerControllerImageURL` and `UIActivityTypeMarkupAsPDF`
are strings an application writes into a dictionary or an array, and a missing
one becomes a `nil` key that raises. They carry the values UIKit gives them -
the second is a reverse-domain identifier, not its own name, which is why both
were read rather than assumed - and they make nothing happen: the picker of
this release never fills that key in, and its share sheet never offers that
activity.

The rest needs something the device does not run. Multipath TCP
(`multipathServiceType`) needs it in the kernel. `getFileProviderServicesForItemAtURL:`
needs a File Provider daemon. `NSUserActivity`'s `eligibleForPrediction`,
`persistentIdentifier` and the deletion of saved activities need the daemon that
keeps that store; there is nothing here to predict from and nothing to delete.

Two entries are `ignored` rather than absent, because the call never passes
through this package at all: `NSJSONWritingSortedKeys` is a number the compiler
writes into `+dataWithJSONObject:options:error:`, which this release already
answers and which ignores the bit, so the keys come out unsorted; and
`NSLocalizedFailureErrorKey` is carried in an error's user info untouched, since
honouring it would mean changing `-localizedDescription`, a method every release
already has.

`preferredRange` of an image renderer format chooses between a standard and an
extended colour range, and CoreGraphics of iOS 6 has no extended colour space at
all. No context it builds is of extended range, so the property could only
store a promise.

### What Markdown says a run of text is

Three classes of iOS 15 and 16 and the attribute keys beside them are carried
whole: `NSPresentationIntent`, which records what a block-level Markdown element
is - a paragraph, a header, a list item, a cell of a table - so a view can style
it; `NSAttributedStringMarkdownParsingOptions`, the five settings a parse is
asked for; and `NSAttributedStringMarkdownSourcePosition`, where a run came from
in the source. No release this package is built for has any part of the three, and
none of the three is a class with behaviour to borrow: they are values, and what
they hold is the host's own, read out of the host's own classes and held against
them by `tests/backports/host/presentationintent`,
`tests/backports/host/attributed15` and
`tests/backports/host/markdownsourceposition`.

`NSAttributedStringMarkdownParsingOptions` is **not** NSSecureCoding, and that is
the host's own answer and not work left out: the host has no
`+supportsSecureCoding` and an archiver asked to write one raises. Carrying a
coding for it would be a second implementation where Apple has none.

Two things about a source position a header alone does not say, both measured on
the host's own archive of a run its Markdown parser marked, where the byte offsets
and the UTF-16 ones are keys side by side. A **column is a UTF-8 byte offset**
within its line, for a multi-byte character the character's first byte; and the
range `-rangeInString:` answers is in **UTF-16 units**, because a range into an
`NSString` is. The port reads the eight cached offsets its archive carries and uses
none of them - they are offsets into one particular Markdown string, which an
archive does not carry and no key in one names - and works the range out from the
four numbers instead. Over twelve documents and the 29 runs the host's parser
marks, that answer is the host's own on 28; the one that differs is the CRLF
document, where the host's cached offsets count a document seventeen bytes shorter
than the one it was asked about. `facts/Foundation/NSPresentationIntent.md`,
`facts/Foundation/NSAttributedStringMarkdownParsingOptions.md` and
`facts/Foundation/NSAttributedStringMarkdownSourcePosition.md`.

### How it is proved

Every implemented entry has a differential test under `tests/backports/host/`
that compiles these sources with the classes and functions renamed and the
categories attached under their own selector prefix, so the system's
implementation and the port run side by side in one process and the two answers
are compared. The safe area, the scroll view's adjusted content inset, the
directional margins and the font metrics were also checked on an iPhone 4S
running 6.1.3, through a tweak loaded into an application the phone already
has: forty-seven checks in one run, no failures. That run is where the font cache
of this release showed up - a font scaled to the size it already has comes back
as the same object, which no host can show.

## Libraries that carry a later release's names, and two that carry no radio

Eleven libraries exist because a name a later release declared is a name an application links
strongly. `CFNetwork.framework` is on the release this port runs on, so an application that names
one of CFNetwork's later additions binds a symbol nothing provides and dyld kills it before `main` -
measured, in `facts/CFNetwork/Names.md`, and the reason each of these libraries exists. Where the value
behind a name is a string, it is the framework's own text, read out of a shared cache rather than
typed, and each family below is held against the host's own copy of the same framework. Where the
name is a class, the question is different, and the answer is what the release can really do.

### Game Center's value classes, over the Game Center the release has

`GKBasePlayer`, `GKCloudPlayer` and `GKLeaderboardSet` (7.0, 8.0) are carried whole. The armv7 cache of
6.1.3 holds 304 GameKit classes and the *modern* selectors - `displayName`, `playerID`, `score`,
`rank` - so iOS 6 already answers what the iOS 7 API asks of a player. What it has none of is the
**set**: `loadLeaderboardsWithIDs` is not in its selector list. So a set the port holds is the port's
own, kept in memory and empty until something is loaded into it, and every call on a set that was
never loaded answers no set and the SDK's own `GKError`. A leaderboard set nobody loaded has no
title, no identifier, no group and no image, which is the true answer with nothing loaded.
`facts/GameKit/Values.md`, and the host's own GameKit, which has all three classes, is the oracle in
`tests/backports/host/gamekit/`.

### The account names iOS 7 added, and the name behind them

`ACAccountTypeIdentifierTencentWeibo` and `ACTencentWeiboAppIdKey` (7.0) name an account type and the
key an options dictionary carries a Tencent App ID under; both were deprecated in iOS 11.
`ACAccount.userFullName` (7.0) is the owner's name as the service knows it, and the account store the
release reads has one kind of account - Sina Weibo - whose record holds a handle and a name and
nothing that names the owner, so the answer is the documented nil and not a name made up.
`facts/Accounts/`.

### The 54 uniform type identifiers CoreServices added

52 arrived in 8.0 and one each in 9.0 and 9.1. Each value is read out of the arm64e shared cache of
iOS 18.0 through its own symbol with `tools/corpus/cache-value.lua`, and the host's own CoreServices agrees with
every one of them. What stays the release's own is the classification of a file: the release knows
none of these types, so a file it recognises is classified as it always was.
`facts/CoreServices/Names.md`.

### The seven names CFNetwork added

Two HTTP versions, one call-signalling network service type and four stream properties, none of which
6.1.3 exports: it has `kCFHTTPVersion1_1` and 225 `kCF*` names, and not these seven. They live in
three objects, one release each, because an object carries the API of a single release.
`facts/CFNetwork/Names.md`.

### The registry paths of IOKit, and its main port

A registry path is a plane name followed by the `/`-separated names from the root down to the entry.
Four names arrived after this release: the two functions of 9.0 that take and return a path, and
`kIOMainPortDefault` and `IOMainPort` of 15.0. The two functions are written over the release's own
`IORegistryEntryFromPath` and `IORegistryEntryGetPath`, which the armv7 cache of 6.1.3 does export. A path the release's own `IORegistryEntryGetPath` fails
for is nil here too, and the host shows the same for an entry of its own, so nil means the entry is
not there rather than that the port gave up. `facts/IOKit/IORegistryPaths.md`.

### The NDEF value classes, with no radio

`NFCNDEFMessage` and `NFCNDEFPayload` (11.0) are two value classes: a payload is a type, an
identifier and bytes, a message is a list of payloads, and both are made, encoded, parsed and
compared here with no tag anywhere near them - which is why they are carried whole while the
sessions of the framework, which need one, are not. `facts/CoreNFC/NDEF.md`.

### The property keys IOSurface added

33 keys, from the surface of 11.0 to the four releases that added one each after it. The keys are
carried with the texts IOSurface itself gives them, so a strong reference to one resolves; the surface
is still the release's own, which answers for the properties it has. The class itself, its
properties, its methods and its functions are named at the end of the facts file as the next piece of
this framework, not left to look like an oversight. `facts/IOSurface/Names.md`.

### The 207 CNLabel names Contacts added

The relation labels of a contact - the text a relationship is written as - run to 207 names between
11.0 and 14.3, and all of them are carried, with the texts **Contacts' own**: a label is what a
contact is stored under, and a spelling of the constant would be a different label. The host's own
Contacts exports all 207 and agrees with every one. `facts/Contacts/Values.md`.

### The four Security calls that sign, verify, exchange and say what a key can do

`SecKeyCreateSignature`, `SecKeyVerifySignature`, `SecKeyCopyKeyExchangeResult` and
`SecKeyIsAlgorithmSupported` (10.0) are carried over `revenant@micro-ecc` - Kenneth MacKay's P-256
arithmetic, BSD-2, taken as a package of its own rather than written here - because iOS 6.1.3 has no
way to make an ECDSA signature: `SecKeyCreateRandomKey` and `SecKeyCreateSignature` are both iOS 8.
A key of the **release's own keychain** is signed by the release's own arithmetic: the armv7 cache of
6.1.3 exports `SecKeyRawSign` and `SecKeyRawVerify`, and it has an EC key type - `kSecAttrKeyTypeEC`
is `ios(4.0)` - so an elliptic key of its keychain is signed through those, with the padding the
package chooses and the release's own status passed on. The curve is reached for the keys the package
makes itself, which are the ones the release's keychain does not hold, and the exchange answers the
documented error for every other key because that cache has no elliptic key agreement of any kind. All
four functions are carried once, for both kinds of key, in `Security/SecurityFunctions10_0_1.m`.
`facts/Security/SecKey.md` and `facts/Security/SecKeyElliptic.md`, and the probes that take the
measurement again are `tests/backports/host/seckeycurve/` and `tests/backports/host/microecc/`.

### DCAppAttestService, the second half of DeviceCheck

App Attest mints a key pair in the Secure Enclave and has Apple certify it. An iPhone 4S and an iPad 2
have no Secure Enclave - it came with the A7 of the iPhone 5s - and no daemon of the release runs the
service, so the questions are answered as a device without it answers them: not supported, no key,
and the error the framework documents. Every completion is called from a background queue after the
method has returned, the way the release's own `DCDevice` token path does.
`facts/DeviceCheck/DCAppAttestService.md`.

### The App Clip payload

`APActivationPayload`, the payload an `NSUserActivity` carries, and
`+[NSUserActivity appClipActivationPayload]` (14.0) are carried, and the release launches no App Clip:
there is no App Clip binary, no registered App Clip URL, and no NFC tag or visual code to invoke one.
So no payload is ever made, every payload has no URL, and `-confirmAcquiredInRegion:completionHandler:`
refuses with the error the framework documents for an invocation that did not come from a tag or a
code. `facts/AppClip/APActivationPayload.md`.

### The tracking authorization question

`ATTrackingManager` (14.0) asks the owner for permission to track the user across apps, and asks what
the answer is. The release runs no `tccd`, has no per-bundle record of an answer and no privacy
setting for one, so the status is `NotDetermined` and stays there, a request calls back with it and no
prompt goes up, and a second request calls the handler again the same way: nothing is remembered
between requests, because there is nothing to remember.
`facts/AppTrackingTransparency/ATTrackingManager.md`.

### The attribution token

`+[AAAttribution attributionTokenWithError:]` (14.3) is one method that asks Apple's own attribution
service for a token tying an install to the advertisement that brought it in. The token is not
computed on the device: it is minted over the network, against an application registered with the
service. So the class stands where the host's does, an application that asks finds it, and the answer
is the documented error rather than a token of the port's own making.
`facts/AdServices/AAAttribution.md`.

### The environment and the domain state of iOS 18

`LAEnvironment`, its mechanisms and its state, and `-domainState` on the `LAContext` this package
already carries (18.0), are carried as one shared `LADomainState` per context. On a device with no
biometry enrolled and no companion paired, the state hashes are empty, and nil is the port's own
answer for a state with nothing in it - which is what the host's own fresh context shows as well, so
the comparison is one that can be made. `facts/LocalAuthentication/LAEnvironment.md`.

### Whether this device may run a browser engine of its own

`+[BEAvailability isEligibleForContext:completionHandler:]` (18.4) asks whether a browser built with
its own engine may run here, and hands the answer to a handler. The answer is the system's to give,
from an entitlement and a release that support it; iOS 6 carries neither, so nothing is eligible and
the call says so at once rather than waiting. `facts/BrowserKit/BEAvailability.md`.

## iOS 17

### CMTag, and the three bodies that are the SDK's

`CMTag`, `CMTagCollection` and `CMTaggedBufferGroup` arrived at iOS 17, and the SDK this package is
written against - 16.4 - has no header for any of them, so `RevenantCMTag26.h` carries 26.2's own
declarations. Nineteen of CMTag's twenty-five are functions with definitions in `CMTag17.m`; the other six
are `CM_INLINE` in 26.2, so the header carries their bodies.

**Three of those six bodies are the SDK's text, and that is not a choice: `CMTagGetValue`,
`CMTagGetCategory` and `CMTagHasCategory`.** A struct field accessor is one expression, and for these
three no other exists - `CMTagValue` is 26.2's `uint64_t`, the category is a 32-bit field, and the
question `CMTagHasCategory` asks is answered by the single equality of two 32-bit patterns. Their rows say
so and claim no independence. What the port stands on for them is the measurement, not the spelling: the
host's answers over 672 values, in `tests/backports/host/coremedia7/cmtaginlines.m`.

The other three - `CMTagIsValid`, `CMTagCategoryEqualToTagCategory`, `CMTagCategoryValueEqualToValue` -
are the port's own, written from that measurement and composed through the package's own accessors
rather than off the struct.

**The port's bodies bind only on an SDK with no `CMTag.h`,** which is 16.4, the SDK the port targets. On
an SDK that has one - the host's, where `<CoreMedia/CoreMedia.h>` includes `<CoreMedia/CMTag.h>` at its
line 19 - Apple's definitions are compiled first and the port's text is shadowed before it is read. So no
check in this repository compares the port's six against the host's: a two-table comparison on the host
would compare Apple's inlines with Apple's. What is verified is that the port's bodies are the ones that
bind on 16.4, by compiling them for `armv7-apple-ios6.0` against it.
