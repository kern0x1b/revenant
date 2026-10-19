# CallKit of iOS 10 and 11

CallKit came in iOS 10.0: an application that places and takes calls of its own reports them to the system through a `CXProvider`, asks the system to change
them through a `CXCallController`, and watches every call of the device through a `CXCallObserver`. iOS 11.0 added `includesCallsInRecents` to the
configuration and the two shorthand requests of the call controller. The release keeps no call of its own: the truth about which calls exist lives in
`callservicesd`, and each of the three classes is a client of it.

Source: the CallKit of the host, read under Mac Catalyst by `tests/backports/host/callkit/run.sh` - the five error domains as data, the defaults of
`CXProviderConfiguration`, the deadline of an action, the completeness of a transaction, the keys a `CXStartCallAction` archives under, the equality of a
handle and what a copy of an action and of a transaction is - and SDK 16.4's headers for the surface. What the host will not answer is written down under
*What is not carried*.

## What iOS 6 has instead

Nothing. `callservicesd` arrived with CallKit, and iOS 6 runs no daemon that holds the calls of the device, publishes them to an application, or takes a
transaction from one. There is also no way to write one that another application would find: the port installs libraries into processes, not services into
the system.

So the broker is per process. `CharonCallBroker` is the one place in an application that knows which calls exist, and the provider, the call controller and
the call observer of that application meet there. An application sees its own calls and no others, which is what a single application using CallKit for its
own VoIP calls - the case the ports have - sees anyway. Two applications do not see each other's calls, and that is the one place the port cannot follow the
release. The cellular calls of the release are the one thing that does cross the boundary, and they come in through `CTCallCenter`.

## What the port does

- The five error domains are the release's own strings, to the character: `com.apple.CallKit.error`, `com.apple.CallKit.error.incomingcall`,
  `com.apple.CallKit.error.requesttransaction`, `com.apple.CallKit.error.calldirectorymanager`, and iOS 14.5's
  `com.apple.CallKit.error.notificationserviceextension`. An error of the port carries the domain and the code and
  no user info, as the release's do, so `-localizedDescription` falls back to Foundation's wording for an unknown domain.
- A new `CXProviderConfiguration` allows 2 call groups of 5 calls each, supports no video, includes its calls in recents, and supports no handle type; its
  `ringtoneSound` and `iconTemplateImageData` are nil. Those are the release's defaults, read off the host. `-initWithLocalizedName:` is the iOS 10
  initializer and keeps the name; `-init` is the iOS 14 one and leaves it nil. A provider's `configuration` is a copy both when it is set and when it is
  read, so an application cannot change a running provider's configuration behind its back.
- A `CXAction` carries its deadline from the moment it is made, before any provider has seen it, and how long it is belongs to the class: ten minutes for
  `CXStartCallAction`, one minute for `CXAnswerCallAction`, and five seconds for `CXAction` itself and for ending, holding, muting, grouping and playing
  DTMF. Those three numbers are the release's, read off the host. Fulfilling or failing an action no provider holds does nothing and leaves `isComplete` NO -
  the release leaves it incomplete too, because fulfilling is a message to whatever is performing the action and there is nobody to send it to.
- A `CXTransaction` is complete when every action of it is, so a transaction with no actions is complete from the start, as the release's is. A copy of a
  transaction is a new transaction whose actions are copies; a copy of an action is a new action of the same class with the same UUID.
- A `CXHandle` is equal to another of the same type and value, hashes with it, and copies to an equal object that is not the same one. It archives with
  secure coding and comes back equal.
- An action archives under the release's key names - `UUID`, `callUUID`, `handle`, `contactIdentifier`, `isVideo`, `onHold`, `muted`,
  `callUUIDToGroupWith`, `digits`, `type` - and its completeness under `complete`, where the release writes a `state` of its own whose values this band has
  no reading of. An archive of the port is read only by the port.
- `-[CXProvider setDelegate:queue:]` takes the main queue when it is given none, and the delegate is told `providerDidBegin:` on the next turn of that
  queue, so setting the delegate returns first. Every message to a delegate and every completion block runs on that queue.
- `-reportNewIncomingCallWithUUID:update:completion:` makes the call, hands it to the broker and calls the completion with nil; a UUID a call already has
  fails with `CXErrorCodeIncomingCallErrorCallUUIDAlreadyExists`, and an invalidated provider or a missing UUID with
  `CXErrorCodeIncomingCallErrorUnknown`. `-reportCallWithUUID:updated:` merges the update over the one the call has, so a field left nil keeps what the call
  already carried. `-reportOutgoingCallWithUUID:connectedAtDate:` is what makes an outgoing call connected; `-reportCallWithUUID:endedAtDate:reason:` ends
  it.
- `-[CXCallController requestTransaction:completion:]` refuses a transaction before any provider sees it, in this order: a transaction with no actions is
  `EmptyTransaction`, a process with no provider is `UnknownCallProvider`, an action that is not a call action is `InvalidAction`, a start action for a
  call UUID that is already there is `CallUUIDAlreadyExists`, a start action past the configuration's `maximumCallGroups` is `MaximumCallGroupsReached`, and
  any other call action for a UUID no call has is `UnknownCallUUID`. The completion says whether the transaction was taken, not whether its actions were
  performed: an action taken and then failed reaches the delegate of the provider, and the completion has already run with no error.
- A transaction the controller takes reaches the delegate whole through `provider:executeTransaction:` when the delegate answers YES to it, and action by
  action through the `perform…Action:` methods when it does not. An action whose `perform…` method the delegate does not answer fails at once, rather than
  leaving a call waiting on something nothing will perform. An action still incomplete at its own deadline times out: it finishes as failed and the delegate is
  told `provider:timedOutPerformingAction:`. Each action of a transaction runs out on its own clock, so a transaction that starts a call and mutes it has
  ten minutes for the one and five seconds for the other.
- A fulfilled action is what changes the call. A start action records when the call started connecting, an answer action connects it, an end action ends it
  and takes it out of the broker, and the held, muted and group actions set those. A failed start or answer action ends the call as
  `CXCallEndedReasonFailed`, since the call only exists because the action was asked for and there is nothing for it to be; a failed end, hold, mute or
  group action leaves the call as it was.
- `-[CXProvider invalidate]` fails every action of every transaction it has not finished, ends every call it holds as `CXCallEndedReasonFailed`, drops the
  provider out of the broker and tells the delegate `providerDidReset:`.
- A `CXCallObserver` answers the calls of the broker and tells its delegate, on the queue it was given or the main queue, whenever one appears, changes or
  ends. What the delegate is handed is a snapshot taken while the broker held its lock, so the call does not change under it. A `CXCall` is equal to another
  with the same UUID and hashes with it.
- The observer reports the calls of the device and not only the application's, which on iOS 6 means the cellular ones. `CTCallCenter` is there from iPhone
  OS 4 and is the whole of what a third party may see of them - an identifier and one of four states - and it is what the port watches. Making the first
  `CXCallObserver` of the process is what starts the watch, so an application that never asks for one never loads the call centre. A call CoreTelephony
  first shows as `CTCallStateDialing` is outgoing and one it first shows as `CTCallStateIncoming` is incoming; `CTCallStateConnected` connects it and
  `CTCallStateDisconnected` ends it as `CXCallEndedReasonRemoteEnded`. A cellular call gets a UUID of the port's making, kept for as long as the call
  lasts, since CoreTelephony's identifier is a string and CallKit's is a UUID.
- A cellular call belongs to no provider of this process, and an action the call controller is asked for against one is refused as
  `CXErrorCodeRequestTransactionErrorUnknownCallProvider` - which is what is true - rather than handed to a delegate that never made that call. The same
  refusal covers a call of another provider in the same process.
- CallKit does not configure an application's audio, and neither does the port: the application sets its own category and mode while it performs the
  action, and what the system does is activate the session and say so. A call of a provider connecting activates the shared `AVAudioSession` and the
  delegate is told `provider:didActivateAudioSession:`; the provider's last connected call going away deactivates it, with
  `AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation`, and the delegate is told `provider:didDeactivateAudioSession:`. iOS 6 has the category, the
  mode and `-setActive:withOptions:error:` the contract needs. A cellular call is none of the application's audio and moves nothing.

## What is not carried

The call directory is an application extension, and iOS 6 loads no extensions. Its delegate protocol,
`CXCallDirectoryExtensionContextDelegate`, is absent: nothing ever calls it. `CXCallDirectoryProvider` and
`CXCallDirectoryExtensionContext` are carried inert, as the host answers for them without an extension host: the provider's
`-beginRequestWithExtensionContext:` does nothing; the context is an `NSExtensionContext` (the release's from 8.0, the package's before),
not incremental, with no delegate and no input items, whose adding methods return, whose four removing methods raise
`NSInternalInconsistencyException` ("Calling removeAllBlockingEntries when isIncremental is false is unsupported", the host's text), and whose
`-completeRequestWithCompletionHandler:` is never answered. `CXCallDirectoryManager` is carried and refuses at that seam: no
identifier names an extension here, so `-reloadExtensionWithIdentifier:completionHandler:` completes with
`CXErrorDomainCallDirectoryManager` / `CXErrorCodeCallDirectoryManagerErrorNoExtensionFound`, and
`-getEnabledStatusForExtensionWithIdentifier:completionHandler:` with `CXCallDirectoryEnabledStatusUnknown` and the same error. That is
the header's error for an identifier with no extension, reasoned rather than read: the host runs no call directory service, and its
manager answers every identifier with the connection's failure (`NSCocoaErrorDomain` 4099), which the host test names divergent. What
the host does answer is held: `+sharedInstance` is one object, and the answers come on a queue that is not the main one, as the port's
come on a global queue. iOS 13.4's `-openSettingsWithCompletionHandler:`, a category of its own so a release with the class and without
the method gets it too, completes with `NSCocoaErrorDomain` / `NSFeatureUnsupportedError`, the host's answer where it has no page to
open: iOS 6 has none, and the releases before 13.4 give an application no public way to open theirs. `CXErrorDomainNotificationServiceExtension` is carried: it is a
string, and an application that names it loads.

`+[CXProvider reportNewIncomingVoIPPushPayload:completion:]` (iOS 14.5) is there and refuses at its seam. The header gives it to a
Notification Service Extension, to have the containing application launched for an incoming VoIP call; iOS 6 has no application
extensions, so no caller of it is ever one. The answer is the host's to a process that is no extension and holds no notification filtering
entitlement (Mac Catalyst, `tests/backports/host/callkit/run.sh`, records `provider.voipPush.*`): the completion is called once, before the
method returns, on the caller's thread (from the main thread and from a global queue alike), with `CXErrorDomainNotificationServiceExtension`
/ `CXErrorCodeNotificationServiceExtensionErrorMissingNotificationFilteringEntitlement` (2) and no user info, whatever the payload; a nil
completion is allowed. The earlier handoff's "on the main thread" was the thread the probe called from. A process that does hold
`com.apple.developer.usernotifications.filtering` and is still no extension presumably gets
`CXErrorCodeNotificationServiceExtensionErrorInvalidClientProcess` (1) from the system, as the reviewer remembered for an application process;
the host cannot show it, since AMFI kills an ad-hoc signed process that claims that entitlement before it runs (exit 137, 2026-09-24), and
iOS 6 gives a process no public way to read its own entitlements, so the port answers 2 to such a process as well. That is the one
divergence, between two refusals, for an entitlement Apple issues only to extensions.

Behind the seam is the wall that made the method `absent` before, and it still stands: the method turns a `PKPushRegistry` VoIP push payload
into a reported call, and this port never receives one to turn. `apsd`, iOS 6.1.3's
own push daemon, ties every device token to a nonzero `UIRemoteNotificationType` bitmask (`Badge`/`Sound`/`Alert`) with no silent fourth bit - measured
against real hardware in `facts/PushKit/PushKit.md` - so a `PKPushRegistry` set up the way PushKit is meant to be used, with no prior
`-registerUserNotificationSettings:` call, never receives a token at all. And even with a token, `apsd` on this release never wakes a suspended or
not-running application for any push, VoIP included. Both are Apple's own service on this device, not something the release "didn't have yet" - which
is why cellular incoming calls are still fully reported, through `CharonCallTelephony.m`'s `CTCallCenter` observation instead of a push.

What the release does with a cellular call beyond the four states is out of reach: `CTCallCenter` gives no direction for a connected call, no hold state and
no handle, so a cellular call of the port has `onHold` NO and an update of nothing. CoreTelephony of iOS 6 does export `CTCallDial`, `CTCallAnswer`,
`CTCallHold` and `CTCallDisconnect`, so acting on a cellular call is reachable in principle; whether CommCenter lets an unentitled process do it is
untested, and until it is tested the port refuses rather than pretends.

Two behaviours the host would not answer, because a tool without the VoIP entitlement never gets past CallKit's own entitlement check (every request came
back `CXErrorCodeRequestTransactionErrorUnentitled`, code 1, and no delegate method was ever called): the order in which a transaction is refused, and
whether `providerDidBegin:` and `providerDidReset:` arrive and when. The order above is the order the header's enumeration lists the failures in and the
order the port checks them in; it is reasoned, not read, and the entry says so. `CXErrorCodeUnentitled` and the rest of `CXErrorCode` are cases of an
enumeration the compiler writes into the application, so the package carries nothing of them; the port never answers `Unentitled`, since there is no
entitlement to hold an application to.

The port's `-description` is its own. The release's carries the ivars of a CallKit far newer than iOS 10 - `state`, `commitDate`, `handles`, a dozen flags
the iOS 10 header has no property for - and there is nothing to be gained from following a text no application reads.

## The system call screen

The screen an incoming call is shown on belongs to SpringBoard, which no library loaded into an application can draw in, so what the library carries is one
side of a bridge and the screen itself is a tweak's business. The two sides speak in Darwin notifications and a file, because that is what crosses the
boundary on this release: a notification reaches every process whatever its sandbox and carries nothing, and a file carries the call but only where both
sides may reach it - `/var/mobile/Library/Caches/org.charon.callkit`, made by whichever side runs first and writable by everyone, since an application and
SpringBoard are not the same user and share no group.

A provider reporting an incoming call writes the UUID, the caller's name, the handle and its type, whether there is video, the application's bundle
identifier and the configured ringtone, and posts `org.charon.callkit.incoming`. What the person does on the screen comes back as
`org.charon.callkit.answered` or `org.charon.callkit.declined` with the UUID in a file beside it, and the library turns it into an ordinary
`CXAnswerCallAction` or `CXEndCallAction` run through the provider - so the delegate is called exactly as it is when the application answers from its own
interface, and there is one path through the state machine instead of two. The screen is taken down when the call is answered, since from there on it is
the application's own interface, and when the call ends.

Without that tweak none of this is heard: the library writes a file nobody reads and posts a notification nobody hears, and the calls of the application
work exactly as they do with no screen. Nothing on this path can refuse, raise or fail a call. The behaviour does not degrade when the tweak is missing -
it simply does not happen, the way a device without the hardware a feature needs answers "unavailable" rather than pretending.

The tweak, `org.charon.callkit-screen` (`packages/a/apple-callkit-screen`), carries the other side: a MobileSubstrate dylib filtered to
`com.apple.springboard`, built by Charon's own tweak rule (`@addon/charon/tweak`) the way any port builds one, proven for real by
`tests/addon/tweak_test.lua` (the rule itself, against a device test already held to a running iPhone 4S) and `tests/addon/callkit_screen_test.lua`
(this package, built and installed - `Library/MobileSubstrate/DynamicLibraries/charon-callkit-screen.dylib` and its filter plist land where the rule
promises). It listens for `org.charon.callkit.incoming`, reads the payload, raises a window above SpringBoard's own with the caller's name and handle and
an answer and a decline button, and on a tap writes `answered` or `declined` and posts back, exactly the protocol the library already speaks; it takes the
window down on `org.charon.callkit.ended` too, for a call the application ended for a reason of its own.

What that proves and what it does not: the dylib links, is signed and packaged, and the build gate holds it to the same Mach-O checks every other binary in
this tree answers to. It does **not** prove that a window drawn this way actually appears above SpringBoard's own interface, or that
`notify_register_dispatch` reaches a dylib injected into SpringBoard's process in its own sandbox and its own launch sequence - nothing short of a device
answers that. `tests/backports/device/callkit-screen.m` is the device test written for that measurement: it reports an
incoming call from a command-line process and waits for a tap on the screen - logged coordinates, driven by `revtouch tap X Y`, never anything else - to
turn into `performAnswerCallAction:` or `performEndCallAction:` on its own delegate. Until it has run on hardware, the screen is not declared working under
any description weaker than that.

Measured on hardware 2026-09-22 (iPhone 4S, 6.1.3): `dpkg -i` of `org.charon.callkit-screen` installs cleanly (`dpkg-query` confirms
`install ok installed`, the dylib and filter plist land where the rule promises). Posting `org.charon.callkit.incoming` with the payload the library
writes reaches the folder and the notification is posted without error - but **no window appeared over SpringBoard**. This is not a crash: SpringBoard's
PID was the same before and after the install and after the poke, and its crash log carries nothing from this run - silence, not a fault. The likely
cause is architectural, not a bug in this package: `/Library/MobileSubstrate/MobileSubstrate.dylib` here resolves to
`CydiaSubstrate.framework/Libraries/SubstrateInjection.dylib`, and this release's MobileSubstrate injects a filtered dylib into a process at that
process's own launch, not retroactively into one already running - SpringBoard was already up before the tweak was installed, and nothing short of a
respring picks a freshly-installed filter up.

Measured again 2026-09-23, same iPhone 4S, with the owner's sign-off to respring: the tweak's constructor now writes its own pid to
`/var/mobile/Library/Caches/org.charon.callkit/loaded` and posts `org.charon.callkit.screen-loaded`, so "did SpringBoard load this dylib" is a direct
read instead of a guess from the window - there is still no `vmmap`/`otool` on this device to ask any other way. `launchctl stop
com.apple.SpringBoard` (and, on a retry, `killall -9 SpringBoard`) changed the PID `launchctl list` reports (3565 -> 11711 across one respring, then
11711 -> 12529 across a second one taken purely to pair a fresh before/after inside a single measurement), and each time the marker file's pid matched
the new SpringBoard PID exactly. **The window appears.** Posting `org.charon.callkit.incoming` right after immediately raised the dimmed overlay with
the caller labels and the two round buttons, confirmed on a screenshot taken and deleted immediately after each check. A tap on Decline (80,390) and,
on the next call, a tap on Answer (240,390), each written to `answered`/`declined` and dismissed the window as the tweak's `-respond:` promises.

That much is the tweak's own file-and-notification protocol, driven by the `charon-callkit-poke` probe rather than a real `CXProvider` - the stronger
proof is `tests/backports/device/callkit-screen.m` itself, built through the real toolchain (`@addon/charon/daemon`, `apple-backports` with
`callkit=true`) and run on the same device against the already-installed canon (`0.8.10+0f900eff` - the canon was not rebuilt or touched for this).
It reports its own incoming call through a real `CXProvider`, waits on a tap at the coordinates it logs, and turns what arrives into
`performAnswerCallAction:` or `performEndCallAction:` on its own delegate. Both cases ran: `charon-callkit-touch tap 80 390` turned into
`performEndCallAction:`, and `charon-callkit-touch tap 240 390` on the next call turned into `performAnswerCallAction:` - `checks=7 failures=0`. The
screen is proven end to end: build, package, install, SpringBoard load, the window, and both directions of the tap round-trip through a real
`CXAnswerCallAction`/`CXEndCallAction`. The one caveat that remains structural, not a gap in this measurement: MobileSubstrate here only picks up a
freshly-installed or freshly-updated filtered dylib at SpringBoard's own next respring, never retroactively - anyone installing or updating this
package still needs one.
