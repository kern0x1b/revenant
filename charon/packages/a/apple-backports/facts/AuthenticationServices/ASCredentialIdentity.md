# The credential identity types, of iOS 12.0

These are the values that name *what* a stored credential is for, as opposed to `ASCredentialIdentityStore`
which holds them. They are the first classes in this family that exist to be written down rather than
talked to a daemon, and the first that an application reads back after a relaunch.

## `ASCredentialServiceIdentifier`

Which service a credential is for, and whether that service is named by a domain or a URL. The type is
part of the value and not a detail: the same string typed as a domain and typed as a URL is a different
service, and the system will not match an identity stored against the wrong one. `-copyWithZone:` carries
both parts for that reason, and the coder carries both too.

This class does **not** mark its public designated initialiser unavailable — only plain `-init` is — so the
port keeps the release's own `-initWithIdentifier:type:` as it is. That is the opposite of the request
classes two commits back, and it is worth stating because the same construction is right in one place and
wrong in the other.

The port does not parse the string against RFC 1035 or RFC 1738. The release does not either: the header
says what the type *represents* and leaves the conformance to the application that stored it, and refusing
identities the system would have kept is the worse of the two mistakes available.

## What the two checks say about them

The **shape** check reads the members from the header with clang's AST and asks the host and the port
whether each is bound. The **value** check runs both builds and compares what a request holds. Neither of
them can see a class that is not asked about — which is how `ASCredentialServiceIdentifier` went unmeasured
for a round: its registry row said `absent` while the class was in the tree, so the case builder was given
six class names and the class was written but never asked about.

The builder now fails in **both** directions and both are proved:

    set the row to absent       -> these classes are DEFINED in the tree and the registry does not
                                   carry them as implemented, so they are not measured at all:
                                   ASCredentialServiceIdentifier          exit 1
    restored                    -> 8 class rows, 42 members from clang, 42 cases, 0 red   exit 0

and it prints what it was asked for and what it produced, per class, so a class that contributes nothing
is visible rather than inferred:

    ASAuthorization 4   ASAuthorizationAppleIDCredential 10   ASAuthorizationAppleIDProvider 2
    ASAuthorizationAppleIDRequest 2   ASAuthorizationOpenIDRequest 8   ASAuthorizationRequest 3
    ASCredentialServiceIdentifier 3   ASWebAuthenticationSession 10        8 class rows, 42 members

The per-*member* guard came with it: a class can produce a case and still lose members, which is the
other half of what was unexplained.

## The store, and the rule about the host's writing half

`ASCredentialIdentityStore` is the first class in this family with state behind it, and it is the one
where a differential could do real harm, so the rule is written here as well as enforced.

On a Mac these four methods change the **user's** AutoFill state:

    -saveCredentialIdentities:completion:
    -removeCredentialIdentities:completion:
    -removeAllCredentialIdentitiesWithCompletion:
    -replaceCredentialIdentitiesWithIdentities:completion:

A differential that called them to see what they return would be writing to the reviewer's passwords. So
the host side of this family is **read-only**: only
`-getCredentialIdentityStoreStateWithCompletion:`, and only because it asks the system what it already
holds. The writing half's behaviour is documented from the header, and the port's own save-then-query
runs against the port's own store, whose property list lives under `.agent-work/runs/` and never in
`~/Library`.

Two things enforce that, and they are different in kind, so they are worth telling apart.

**The runtime refusal.** Every store write in the probe goes through one chokepoint,
`port_store_send()` in `values.m`, which reads the receiver's class name out of the runtime and refuses
anything the harness has not renamed to the port's, aborting with the selector and the class it was
about to be sent to. `port-store-rule.h` holds the predicate and
`tests/backports/host/authservices/port-store-selftest.m` asks the same predicate about **this Mac's own**
`ASCredentialIdentityStore` class object, with the four selectors as strings and nothing sent:

    this machine's class is ASCredentialIdentityStore, the rule's prefix is "Port"
    saveCredentialIdentities:completion:                   refused
    removeCredentialIdentities:completion:                 refused
    removeAllCredentialIdentitiesWithCompletion:           refused
    replaceCredentialIdentitiesWithIdentities:completion:  refused
    0 of the four would have been allowed against this machine's store

This is the half that protects the machine, and it does not depend on reading any source.

Before this round's first run the four names appeared in `values.m` 0 times, and in the port's own
sources — the only place any of them is called — 5, 2, 2, 2.

## What the port's store does, and where it differs from the system one

A save replaces an identity already held — matched on the service identifier, the user and the record
identifier, and deliberately **not** on the rank, which is the order the system offers them in and not
part of what they are. A remove takes only the named records, because the header restricts that method
to a store that takes incremental updates and this one does.

`replaceCredentialIdentitiesWithIdentities:` makes the store's set **exactly** the array, because that
is what the caller asked for. My first version saved the new identities as a superset and left anything
not in the array alone, on the reading that the header confines this method to a store that does not take
incremental updates. **That reading was wrong.** The restriction is a rule for the caller about which
method to call on which kind of store; it is not permission for the callee to do something the caller
did not ask for. An application calling this is saying "these and only these", and a port that keeps
the rest hands back a set the caller neither asked for nor can see. The store here does take incremental
updates, and a caller that wants a superset semantics calls `-saveCredentialIdentities:completion:`,
which is the method that means it.

`-getCredentialIdentityStoreStateWithCompletion:` reports **enabled** and **incremental**, and that is
about the *application's* store, not the system's autofill database. There is no daemon behind this one
and nothing outside the process reads it, which is the honest answer for a port that has no system
credential store to ask.

## The store case, and the two bugs it found

The case the coordinator asked for — the set before, the replace, the set equals the array — is in
`tests/backports/host/authservices/values.m` and is **green**:

    store   path            .agent-work/runs/authservices-values/credential-store.plist
    store   before replace  2 identities
    store   after replace   1 identities

It writes the **port's** store, under `.agent-work/runs/`, and the write guard passes on it: the case
resolves only `PortASCredentialIdentityStore` and never the host's class.

It found two bugs, and the first one is the more interesting because nothing pointed at it.

**1. `NSNull` is not a property-list value.** A record with no record identifier was written as
`identity.recordIdentifier ?: [NSNull null]`, and one `NSNull` in a record made the whole
`NSPropertyListSerialization` return nil — so the store saved *nothing at all*, every save reported the
failure its completion handler exists for, and the shape check was green throughout because nothing in
it writes. "No record identifier" in a property list is the absence of the key, which is what the
comparison against a held record already expected; the key is now omitted. A class that appears to
work, reports its failures correctly, and stores nothing is a worse failure than one that crashes, and
only a case that writes and reads back finds it.

**2. The test passed a selector where a block belongs.** The first version called
`-saveCredentialIdentities:completion:` with `sel_registerName("saveCredentialIdentities:completion:")` as
the completion, because the port's declaration spells the completion as a `SEL`. The port did what it
was told and called it, and the crash was:

    frame #0: objc_retain
    frame #1: -[PortASCredentialIdentityStore saveCredentialIdentities:completion:] + 76
    frame #2: store_case + 768
    frame #3: main

Neither hypothesis of mine was the cause: `+sharedStore` had already been reached, and the store path
had already been read. The first frame is in the runtime and the second is in the port's save — and the
port was right to be there.

## The store mutant

The value differential mutates two things and requires both red. The **operation** mutant is red with a
differing table. The **replace** mutant — which restores the superset behaviour — is red by *crashing*,
not by differing, and a crash is not the red this self-test wants: it shows the code path changed and
nothing more. It is left in the run and the fact is recorded here rather than dressed as a pass.

## `ASPasswordCredential`, and why it is not absent with the two provider classes

`ASPasswordCredential` was registered `absent` for the same reason as
`ASCredentialProviderViewController` and `ASCredentialProviderExtensionContext`: "the release has no
credential provider extension or identity store for the system's AutoFill to consult". **That reason does
not reach it.** A credential is a value object — a user and a password — that an application constructs
and hands back. It asks nothing of the system, needs no daemon, no extension host and no hardware, and
the two provider classes are absent for the opposite reason. Carrying this one and leaving those two
absent is not a partial answer; it is the right answer for each.

What it carries: `-initWithUser:password:`, `+credentialWithUser:password:`, `-user` and `-password`, each
copied in and out, and `-copyWithZone:` carrying **both**. A copy that dropped the password would be an
object that looks like a credential and could not be used for one.

Its construction is the port's own — `-charon_initWithUser:password:` — because `ASAuthorizationCredential`,
the protocol it adopts, declares the initialisers `NS_UNAVAILABLE`.

**The check that covers it is the shape one, and it is the check that caught the row.** With the class in
the tree and the row still saying `absent`, the shape check stopped the run by name:

    these classes are DEFINED in the tree and the registry does not carry them as implemented,
    so they are not measured at all: ASPasswordCredential

That is the guard written for exactly this, doing its job on the band that wrote it. With the row set, the
four members clang reads out of `ASPasswordCredential.h` are compared against the host's own class:

    ASPasswordCredential  initWithUser:password:          instance  available  yes yes  same
    ASPasswordCredential  credentialWithUser:password:    class     available  yes yes  same
    ASPasswordCredential  user                            instance  available  yes yes  same
    ASPasswordCredential  password                        instance  available  yes yes  same
    12 class rows, 63 members from clang, 63 cases, 0 red
