# The two credential-provider classes, of iOS 12.0

Neither of these was hardware. `absent` is only for hardware that is physically not there, and a
*service* is not hardware: the release's own class is there, its methods are there, and an application
subclasses it. So both are carried, and what they cannot do is written down here rather than hidden in
an absent row.

## `ASCredentialProviderViewController`

A `UIViewController` subclass — the header says `ASViewController`, which is `UIViewController` where
UIKit exists — that a password-manager extension subclasses so the system can ask it for a credential.
The five members, all at `ios(12.0)`, and all read out of the header with clang's AST:

| member | what the base class does |
| --- | --- |
| `-prepareCredentialListForServiceIdentifiers:` | nothing — the header asks an *override* to prepare a list |
| `-prepareInterfaceToProvideCredentialForIdentity:` | nothing — the presentation is the system's |
| `-prepareInterfaceForExtensionConfiguration` | nothing — the settings screen is the extension's own |
| `-provideCredentialWithoutUserInteractionForIdentity:` | nothing — the system asks this only when its store already holds a matching credential, and the port has no store |
| `-extensionContext` | `nil` — there is no system-provided context, and standing in an object that cannot complete anything would be worse. Its type is the header's own `ASCredentialProviderExtensionContext *`, which it became when that class was carried below; it was `id` while the class was absent, and the declaration says so |

**A no-op default here is the base class behaving as a base class behaves, not a stub.** An extension
that overrides a member gets its own behaviour; one that overrides none gets the release's own answer,
which is also nothing. What the port will not do is invent a credential the extension never said it
had, or a settings screen the extension did not write.

## `ASCredentialProviderExtensionContext`

An `NSExtensionContext` subclass whose completion methods an extension calls when it has a credential.
Three of the header's four members, all `ios(12.0)`, and all read out of the header with clang's AST:

| member | what the port does |
| --- | --- |
| `-completeRequestWithSelectedCredential:completionHandler:` | records the credential in `-lastExchange`, and asks the handler the expiry question it exists to answer |
| `-completeExtensionConfigurationRequest` | records that the settings exchange finished |
| `-cancelRequestWithError:` | records the error, because a cancellation that dropped it would look like an exchange that merely stopped |
| `-completeRequestReturningItems:completionHandler:` | **not implemented** — the release declares it `NS_UNAVAILABLE` and refuses to compile a call to it, and the port refuses for the same reason. That is a row of its own, not a gap |

**Why recording, and why that is not a stub.** On a device the counterpart of a completion is the
system: it takes the credential, presents, and the user sees a filled field. The port has no system to
hand a credential to, so what a test can observe is what the extension **decided** — and the context
keeps it, where the application that owns the extension can read it. A context that threw the
completion away would be the stub, because then nothing anywhere would know the exchange had finished.

`-lastExchange` is a struct returned by value, not an object: there is exactly one record per context
and no one else has business holding a reference to it, and returning it by value means an application
cannot reach in and change the record behind the context's back. The expiry answer is `NO` because
`ASPasswordCredential` carries a user and a password and no expiry at all, so within the port a
credential just handed over is not expired; were the port to carry an expiry that line would have to
read it, and it is written to be found when that happens.

**The type of the controller's `-extensionContext` follows from this.** It was `- (id)` at `081e8835e`
while this class was `absent` in the registry, `e51d793a6` recorded that connection at the declaration
and in the facts, and with the class carried the getter is typed `ASCredentialProviderExtensionContext *`
as the header has it. The getter still answers `nil`, and for a narrower reason now: the port has no
*system-provided* context, and its own context class is one an extension is handed, not one this
controller fabricates and returns as if the system had supplied it.

## What a device does that the port cannot

- **The AutoFill presentation.** The system shows this controller inside its own UI, and the
  identities on offer come from the system's credential-identity store.
- **That store.** The port's own controller would offer the identities the application's own store
  recorded, which is a different thing from the system's, and saying otherwise would be the lie this
  whole arrangement exists to prevent.

**And the machine's own store is never touched.** The same two halves stand here as for the value
differential: the static scan `tests/backports/host/authservices/writing-selectors-scan.py`, which
requires every writing selector in a harness source to be inside the chokepoint or an allowlist line, and
the runtime refusal `port-store-selftest.m`, which asks the chokepoint's predicate about *this Mac's own*
`ASCredentialIdentityStore` class object and sends nothing. A provider extension that was measured by
asking the real store what it holds would be measured by writing to it.
