# WebKit web extensions (iOS 18.4)

The web-extension API, family by family, and what each one's answers were read from. An extension is a
MANIFEST, and that is why the first family carries on a release with no WebKit at all: the manifest is
JSON, and `NSJSONSerialization` and `NSBundle` are on every release this port builds. Nothing here
needs a web view, and the families that DO need one say so.

## What the host answers, and where each answer is measured

Each of these was measured on this machine by making a real extension from a manifest and asking it,
rather than read off a header, which for this API declares the classes and says nothing about the
behaviour.

**`WKWebExtension`** — `supportsManifestVersion:` is YES for 0, 1, 2 and 3 and NO for 4 and 5. The
header does not say which versions are supported and the SDK declares version 3, so a port that
answered "anything below 4" would be guessing. `manifestVersion` is the manifest's own
`manifest_version`. The requested permissions come back **sorted**, not in manifest order: a manifest
asking for `tabs` and `storage` answers storage first. `allRequestedMatchPatterns` holds the
**requested** host patterns only — an optional host pattern stays in its own set, because it has not
been asked for. `defaultLocale` is nil unless the bundle carries the `_locales` messages the manifest
names, and `displayActionLabel` is nil unless the manifest sets one. `errors` is **not** empty for a
manifest that loaded: the host's own run of the probe manifest answers two.

**`WKWebExtensionMatchPattern`** — a pattern is a scheme, then `://`, then a host, then a path, with a
single star for "any" in each, and `<all_urls>` for every http and https URL. A pattern carrying a
**port** is refused, and so is one with no path, both in `WKWebExtensionMatchPatternErrorDomain`. Any
scheme parses, not only http and https. `<all_urls>` answers nil for scheme, host and path and YES
for both `matchesAllHosts` and `matchesAllURLs`; `http://*/*` answers `matchesAllHosts` YES and
`matchesAllURLs` NO. In matching, a **leading star in the host takes zero labels, not one** — so
`https://*.example.com/api/*` answers YES for `https://example.com/api/x` as well as for
`a.example.com` and `b.example.com`; and **neither the port nor the query is part of the match**, so
`a.example.com:8443` and `?q=1` both still match. `<all_urls>` answers NO for `about:blank` and for
`data:text/plain,hi`, and YES for https: it is the http and https URLs, not every URL a process can
name.

**`WKWebExtensionAction` and `WKWebExtensionCommand`** — neither can be made by a program: both
headers mark `-init` and `+new` `NS_UNAVAILABLE`, and the host agrees, both classes allocating and
neither initialiser reachable. A **context** hands them out, because a button and a shortcut only mean
something against a loaded extension and the tabs it acts on. Each keeps ALL of its state in a single
opaque storage ivar — 192 bytes for the action, 72 for the command — which is Apple's C++ storage and
not a shape a port should copy; the port keeps ordinary ivars.

## The manifest keys a context will read

Named here because the context family is where they are used, and the port does not read them itself:
an action's `label` is the action section's `default_title`, its `badgeText` is `default_badge` and its
icon comes from the action's icons; a command's `identifier` is its key in the `commands` object, its
`title` is that command's `name`, and its `activationKey` and modifiers come from `suggested_key`.

## What is not measured, and why

An action and a command only exist once a context has loaded an extension, and building a context needs
`WKWebExtensionController`, which is a later family and needs a web view this port does not have. The
two classes are carried with their members and take their values from the context that will build them;
what a member answers for a **real** extension is measured when that family lands. The same applies to
the three contour-derived members of Vision's `VNGeometryUtils` and to the body-pose observation's joint
filtering: named, not quietly implied.

## WKWebExtensionContext: carried, and every member measured off a real one

A context is **software state**, not a thing a machine has or lacks, so it is carried and callable.
The host hands one out for a real extension:

```
$ [WKWebExtensionContext contextForExtension:extension]      # an extension built from $D/ext/manifest.json
extension ok, errors=2
contextForExtension:ext  = 0x102e58330       a real object
```

and it raises on anything that is not an extension, which is worth carrying because it is the only
public way to make one:

```
NSInternalInconsistencyException, reason:
'Invalid parameter not satisfying: [extension isKindOfClass:WKWebExtension.class]'
3   WebKit   +[WKWebExtensionContext contextForExtension:]
```

The answers below are the host's, for a **fresh** context — one made from a manifest and never loaded
into a web view. This is the state the port carries, so each is a measurement and not a guess.

```
webExtension           the extension that was passed in
webExtensionController nil  -- no controller has it yet
uniqueIdentifier       a fresh UUID per call: two calls answered two different ones
baseURL                webkit-extension://40b2e76e-3b1b-4efb-bb0a-5597824e02b7/
optionsPageURL         webkit-extension://<the same UUID>/options.html
overrideNewTabPageURL  nil  for a manifest with no chrome_url_overrides
loaded 0    inspectable 0
errors                   the extension's own two -- NOT empty
unsupportedAPIs          0
every permission set     0
hasAccessToAllHosts 0  hasAccessToAllURLs 0  hasAccessToPrivateData 0  optionalAllHosts 0
webViewConfiguration     nil
openTabs 0   openWindows 0   focusedWindow nil
inspectionName           "Charon probe — Extension Background Page"
```

Three of those are worth stating separately, because they are not what the names suggest:

- **`commands` is not the manifest's.** The manifest asks for a command called `do-it`, and the host
  answers ONE command whose identifier is `_execute_action` and whose title is the action's
  `default_title`. A manifest with an `action` section has that command **synthesised** for it, and
  the manifest's own command is not in the list. A port that surfaced `do-it` would be answering the
  manifest rather than the release.
- **`inspectionName` carries an em dash** and a description of what the context is showing: the
  manifest's name, then ` — Extension Background Page` when the manifest has a background section.
- **`baseURL` and `optionsPageURL` share the context's own identifier**, so they change when a new
  context is made. A caller that caches a base URL across contexts holds a URL for a context that no
  longer exists.

`WKWebExtensionContextPermissionStatusUnknown` — the zero of the enum the 26.2 SDK declares — is what
a caller reads when nothing has been decided, and it is the value the port carries with no permission
granted or denied.

## The seven permission statuses are ENUMERATORS, and an enumerator has no symbol

`WKWebExtensionContextPermissionStatusUnknown`, `…GrantedExplicitly`, `…GrantedImplicitly`,
`…DeniedExplicitly`, `…DeniedImplicitly`, `…RequestedExplicitly` and `…RequestedImplicitly` are the
seven cases of the `NS_ENUM` the 26.2 SDK declares at `WKWebExtensionContext.h:85`, where the SDK
numbers them -3, -2, -1, 0, 1, 2, 3. The same header mentions them in prose as "@constant", which is
how a reader can mistake them for symbols; grepping the header for `extern` or `const` finds none,
because there is no declaration to find. An enumerator is a compile-time integer, so it is not a
symbol, nothing defines it, and `nm -g` over this library's objects cannot show it.

This port therefore carries the seven values the way the release does: as the `NS_ENUM` in
`CharonWebExtension.h:203`, where a caller writing `WKWebExtensionContextPermissionStatusGrantedExplicitly`
gets the value. That is why they have no row. Seven rows once said `status: implemented` for them,
which the 6.1.3 gate rightly refused -- `implemented` is a promise that something of that name is
built, and an enumerator is the one name in this library that cannot be. The corpus agrees: no other
enum's cases carry a row, and `inert` is not the word for it either, since `inert` describes a symbol
that exists and answers nothing (a user-info key, a notification name that is never posted), not a
name that has no symbol at all.

Measured, not asserted: `constant-symbols.sh` compiles the 13 WebKit sources with the gate's own flags
(`-target armv7-apple-ios6.1.3 -isysroot <16.4 SDK> -fobjc-arc -Os -Werror=objc-missing-property-synthesis`),
takes the strong global symbols with `nm -g` (257 of them), and checks every implemented constant row
against that list with a fabricated name as a red control. Before this delta: 32 rows, 7 without a
symbol, and the 7 are exactly these. After it: 25 rows, 0 without.

## An enumerator's NUMBER is part of the API, and the port's must be the SDK's

An app compiles against the SDK's `WKWebExtensionContext.h`, so the numbers it writes into a port
method are the SDK's, and the numbers it reads back out of a port answer are read as the SDK's. The
port had its own: it enumerated the seven cases from zero in the order Unknown, Granted, Denied,
Requested, while the SDK numbers them -3, -2, -1, 0, 1, 2, 3 in the order Denied, Requested, Unknown,
Granted. A caller passing `WKWebExtensionContextPermissionStatusDeniedExplicitly` compiled against the
SDK passed -3, and the port read -3 as RequestedImplicitly. Nothing in the port's own `.m` reads or
writes these values -- `-currentPermissions`, `-grantedPermissions` and `-deniedPermissions` answer the
empty set and the port never constructs a status -- so nothing failed at build time and the defect was
only ever visible to a caller.

`audit-enums.py` checks every `NS_ENUM`/`NS_OPTIONS`/`NS_ERROR_ENUM` the family declares, name by name
and value by value, with implicit increments followed, against the same macro in the 26.2 headers. Two
things it had to be taught, both because a laxer match would have made it agree with anything: the SDK
spells an error enum `NS_ERROR_ENUM(domain, Name)` rather than `NS_ENUM(Type, Name)`, and closes a
declaration with `} NS_SWIFT_NAME(...) API_AVAILABLE(...);`. The red control is an enum with the right
name and one value wrong by construction; it must read MISMATCH, or every "agrees" below is worthless.

Measured, at `CharonWebExtension.h:203` against `WKWebExtensionContext.h:85`:

| case | SDK 26.2 | port, before | port, now |
| --- | ---: | ---: | ---: |
| `…PermissionStatusDeniedExplicitly` | -3 | 3 | -3 |
| `…PermissionStatusDeniedImplicitly` | -2 | 4 | -2 |
| `…PermissionStatusRequestedImplicitly` | -1 | 6 | -1 |
| `…PermissionStatusUnknown` | 0 | 0 | 0 |
| `…PermissionStatusRequestedExplicitly` | 1 | 5 | 1 |
| `…PermissionStatusGrantedImplicitly` | 2 | 2 | 2 |
| `…PermissionStatusGrantedExplicitly` | 3 | 1 | 3 |

Two of the seven agreed by coincidence, `Unknown` at 0 and `GrantedImplicitly` at 2, which is why an
eyeball pass would have called the enum half right. The audit also read the other four enums the family
declares and they agree exactly, case for case: `WKWebExtensionError` (9), `WKWebExtensionMatchPatternError`
(4), `WKWebExtensionMatchPatternOptions` (1) and `WKWebExtensionDataRecordError` (1). The 26.2 headers
declare 3 more the port does not carry at all -- `WKWebExtensionContextError`, `WKWebExtensionMessagePortError`, `WKWebExtensionTabChangedProperties` -- which is
owed work, not a numbering defect.

## The manifest's own twenty-two members, held to a comparison

`WKWebExtension` is the one class on this side whose members are all about a file on disk: there is no
`WKWebExtension` object until an extension is loaded, so every answer here is an answer about a manifest.
`tests/backports/host/webkit/manifest/manifest.json` is that manifest, committed beside the programs and
handed to both sides by `run.sh`, and the twenty-two rows each name the case that holds it in
`webextension-extension_scenario.h` — the same shape as the controller family's: the questions in one
header, compiled twice, once with no port code in the process and once with the renames, `dladdr` saying
which image answered, and `run.sh`'s exit status as the verdict.

Nothing here needs a window, a web view or a user. The loader answers on the main queue and the scenario
turns the run loop until every case has been asked, so the count is claimed and checked (32) and a lost
case cannot pass quietly. `-defaultLocale` is asked for its `localeIdentifier` rather than its description,
because a description is an object dump and two runs would never agree.

**The comparison found three wrong answers, none of which any build or test had caught:**

| member | the port said | the host says | why |
| --- | --- | --- | --- |
| `displayActionLabel` | nil | the action's `default_title` | the label is a string *inside* the `action` object; reading the `action` key answers a dictionary, which is not a string and so came back nil |
| `defaultLocale` | nil | `en` | the messages live in `_locales/<identifier>/messages.json`, and the port looked for `_locales/<identifier>.lproj`. Both layouts are now read, and the measured one is named first |
| `hasOptionsPage` | YES for `options_ui` only | YES for `options_page` **and** for `options_ui` | measured with each key alone: the release answers 1 either way, so the port reads both |

A fourth was a coincidence rather than a wrong answer, and it is worth naming because a green run did not
mean it: `hasOverrideNewTabPage` read `chrome_url_overrides`, which is the key the release reads, while the
fixture carried `override_new_tab_page`, which nothing reads. The host answered 0 and the port answered 0
and the two agreed for no reason at all. The fixture now carries `chrome_url_overrides {"newtab": ...}` and
both answer 1 — measured. Two keys were measured on the host to settle it, each with the other removed.

**The patterns are sorted before they are compared.** A set's enumeration order is not part of an answer,
and the first version joined them in whatever order the set handed over, which made two runs of the same
build disagree with each other.

## The sixteen permissions, and how their values were read

`WKWebExtensionPermission` was carried from the first family as a type with nothing to be a value of,
so an application could name the type and not one permission. The sixteen names the 26.2 SDK declares
(`WKWebExtensionPermission.h:35` to `:95`) are now carried with their values.

Every value is the string the manifest and the extension's own JavaScript write, read out of the
host's own WebKit by `dlsym` and not written from the symbol's name -- a data symbol's `dlsym` answer is
the ADDRESS of the pointer, so the pointer is what has to be dereferenced before it is a string, and a
program that treats the address as the object crashes in `objc_msgSend`:

```
WKWebExtensionPermissionActiveTab                   slot 0x1ebb78118 value 0x1f5df2998 activeTab
WKWebExtensionPermissionTabs                        slot 0x1ebb78190 value 0x1f5df2b78 tabs
WKWebExtensionPermissionWebRequest                  slot 0x1ebb781a8 value 0x1f5df2bd8 webRequest
```

Sixteen cases in `webextension-controller_scenario.h` compare the two sides' values, so a permission
whose value is written from the symbol's own name (`WKWebExtensionPermissionTabs` for `tabs` is the one
that happens to agree; `WKWebExtensionPermissionContextMenus` for `contextMenus` is the shape, and
`WKWebExtensionPermissionNativeMessaging` for `nativeMessaging` is the one a camel-case guess gets
wrong) goes red rather than passing.

**The three error enumerators of the message port have no symbol, and the seven permission statuses
likewise.** `WKWebExtensionMessagePortErrorUnknown`, `...NotConnected` and `...MessageInvalid` read
`(no symbol)` on the host, for the reason the seven statuses give above: an enumerator is a
compile-time integer. They are carried as the `NS_ERROR_ENUM` in the port's own header and have no row.

The sixteen live in `WKWebExtension.m`, beside `-requestedPermissions` and `-optionalPermissions`,
which answer exactly these strings out of the manifest's own arrays. That object is still the 18.4 one
it was: nothing older exports any of the sixteen.
