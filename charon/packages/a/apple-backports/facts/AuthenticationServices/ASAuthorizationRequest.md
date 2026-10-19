# ASAuthorizationRequest, iOS 13.0

The base every request in AuthenticationServices is, and therefore the template the rest of this family
is written in: a subclass adds two or three members and nothing else, and what it inherits is a
provider, a copy and a coder.

## What the host says, measured

macOS 27.0's own `AuthenticationServices.framework` has the class, and `tests/backports/host/authservices`
asks it with `dlopen` and `class_getInstanceMethod` for each member. The class list holds eight instance
methods:

    provider   initWithProvider:   initWithCoder:   init
    .cxx_destruct   copyWithZone:   encodeWithCoder:   supportsStyle:

`-provider` and the three `NSCopying`/`NSSecureCoding` members are the public contract; `initWithProvider:`
is the release's own way in and is not in the public header, so the port does not reach for it — the port's
construction is named and declared in `CharonASConstruction.h`, which is the same mechanism HomeKit's
graph uses and for the same reason.

## The parts that are decided, and how

- **`-provider` is a strong reference and is kept as one.** It is what the controller asks when it runs
  the request; a request that outlived its provider would be a request nothing can service.
- **`+supportsSecureCoding` answers NO.** A provider is an object the caller supplies and the release
  does not document it as archivable; the port writes the provider under its own key and reads it back
  only when the coder can produce an object, so a round trip of a request without a provider gives a
  request without one rather than pretending.
- **A copy is the same request with the same provider**, and a subclass copies what it adds — the base
  copies only what the base holds.

## The census this is the first of

`tools/verify.py` over the 26.2 AuthenticationServices surface, against a registry export of this tree:

    613 objc rows -> 582 real work, 31 carried by the registry

582 is the whole family. This class is the first of them, and the next ones are its subclasses.

## Why `port_has` did not see `-init`, and what it reads

It was asked, and here is what it said. The diagnostic read
`packages/a/apple-backports/AuthenticationServices/ASWebAuthenticationSession.m` — **7231 bytes on
disk, 7231 read**, so the file was not short and not unreadable — found `@implementation
ASWebAuthenticationSession` at offset 3374, and then searched for:

    - (init)

**which no Objective-C method has**, because the return type sits between the parens. Every port-side
answer from that tool was "no" whatever the tree held: the classes it reported as missing were missing
to the search, not to the port. The one real difference it did report — the missing
`-[ASWebAuthenticationSession init]` — came out right for the wrong reason, and the `-init` was added on
the strength of a report the tool could not be trusted to make.

The first correction allowed a space between the sign and the paren and then required the paren to be
the very next character, which `- (instancetype)init` does not have either, so the second run was still
green in the wrong direction. What works is where a declaration puts the selector: a `-` or `+`, optional
space, `(`, the return type, `)`, optional space, and then the member name with a non-identifier after
it — so that `charon_initWithProvider:` is not read as `provider`, which is the next false positive the
prefix form would have given.

    ASWebAuthenticationSession   init                                            yes yes same
    ASAuthorizationRequest      provider                                       yes yes same
    ASAuthorizationRequest      copyWithZone:                                   yes yes same
    ASAuthorizationRequest      encodeWithCoder:                                yes yes same
    shapes: 4 cases, 0 differences

and the mutant, with the base request's `-provider` and its `@synthesize` removed from a copy:

    ASAuthorizationRequest      provider                                       yes no  the port is missing it
    the check exited 1, which is what a check that can see a removed member does

## The member list comes from the header, and a class with no header is an error

The first version kept a table here of which members to ask each class about, and a class missing from
it was asked `init` alone and passed — a check that compares what it happens to have been told to. There
is no table now. The list is parsed at run time out of the framework's own headers, in the SDK the
build compiles against, and **a class the registry carries whose header cannot be found stops the run
and is named**. Asking the host for everything it has instead would ask about the release's private
methods — `initWithProvider:`, `supportsStyle:` — which are not claims and not in the headers.

That widened the questions from four hand-listed members to the seven the two headers declare, and the
run is **red on two of them**, which is the point of the change:

    ASAuthorizationRequest  new                        no  yes  the port adds it
    ASAuthorizationRequest  init                       yes yes  same
    ASAuthorizationRequest  copyWithZone:              yes yes  same
    ASAuthorizationRequest  encodeWithCoder:           yes yes  same
    ASAuthorizationRequest  initWithCoder:             yes yes  same
    ASWebAuthenticationSession  initWithURL:           no  yes  the port adds it
    ASWebAuthenticationSession  start                  yes yes  same
    ASWebAuthenticationSession  cancel                 yes yes  same
    ASWebAuthenticationSession  new                    no  no   same
    ASWebAuthenticationSession  init                   yes yes  same

`ASAuthorizationRequest new` is a defect in `port_has` and not a finding: the source has no `+new` and
no `- (…)new`, and the check reports one. Diagnosed as far as "reports a selector the file does not
contain"; the cause is not yet known and is the next thing to look at, because a matcher that invents a
selector is worse than one that misses one. `ASWebAuthenticationSession initWithURL:` is the same
pattern — a short selector the port has and the check does not see — and the host's answer of "no" for
both is itself suspicious, since a host that answers "no" to a class method the header declares is more
likely the tool's host side than the framework.

**So the gap is closed and the check is red.** It is committed red, with the two cases named, rather
than committed green on the four members the old table happened to list.

## The first subclass, and the two header shapes

`ASAuthorizationOpenIDRequest` is the first class below the base, and the first place the two headers
differ: the base marks `-init` and `+new` `NS_UNAVAILABLE`, its own header does not, and the host's
own class list for it has eleven instance methods **including `init`**:

    nonce  setNonce:  state  setState:  requestedOperation  setRequestedOperation:
    requestedScopes  setRequestedScopes:  init  .cxx_destruct  supportsStyle:

`supportsStyle:` is the release's own, is not in the header, and is therefore not asked about -- a
private method is not a claim. `init` **is** asked about here and **is** bound here, because this
header asks for it. That is the whole point of the `must-be-unavailable` state: the base and its
subclass are on opposite sides of it, and a check that treated "the port declares -init" as a single
verdict would be wrong on one and right on the other.

A fresh request holds nil `requestedScopes`, `state` and `nonce` and the **implicit** operation, which
is the header's default rather than a measurement: the host will not make an instance to ask, because
its `-init` is the one under discussion. Recorded as the header's default, not as something observed.

`-copyWithZone:` carries all four across. A request's identity is what it asks the provider for, and a
copy that quietly changed one of those would be a different request wearing the same object's memory.

    21 cases, 0 red

## ASAuthorizationAppleIDRequest, and what the check cannot see

One property over its superclass, and the measured class list is four instance methods: `user`,
`setUser:`, `init` and the destructor the compiler emits. `user` is the identifier a previous
authorization response vended, so a second sign-in asks for the same person rather than a new one.

    ASAuthorizationAppleIDRequest  user       instance  available  yes yes  same
    ASAuthorizationAppleIDRequest  setUser:   instance  available  yes yes  same
    23 cases, 0 red

**No value mutant for this class yet, and the reason is a limit of the check rather than an oversight.**
The shape check reads the *binary*: it asks whether a method is bound, and the port's library is armv7
so the code cannot be run on this host. A value claim -- the implicit operation a fresh request holds,
or `user` surviving a copy -- is invisible to it, and a value mutant against it would be a mutation
nothing could notice, which is the thing the mutant exists to prevent.

Making it able to see values means compiling these sources for **this** host and running them, which
they allow: they use Foundation and AuthenticationServices, and both exist on macOS. That is a host
build of the same files plus an assertion on a fresh request's four properties and its copy's, and it is
the next piece of work. The two request classes are committed with a green shape check and **no value
mutant**, and this file says so rather than letting the green stand for more than it is.

## The value differential, and what it changed

`run.sh` asks whether a member is *bound*, reading the binary. A value is not a method, so the value
check is a second instrument: it **runs** the code, both builds of it, in one process.

**How a request is made is the whole thing, and I had it wrong.** `ASAuthorizationRequest`'s header
marks `-init` and `+new` `NS_UNAVAILABLE` — by design, because a request is not made by constructing
it. It comes from a provider: `[[ASAuthorizationAppleIDProvider alloc] init] createRequest`, which the
SDK gives, needs no daemon, no network and no UI, and returns a real `ASAuthorizationAppleIDRequest`. My
first attempt used `[[cls alloc] init]` on the host, the base's `-init` raised, and I concluded "the
framework is a stub". That was a conclusion, not a measurement: the initialiser is unavailable *by
design* and the provider is the way in.

**Two builds, one process, the renames on the port's translation units only.** The test TU compiles
without the `-D` list and names the SDK's classes; the port's own build renames its three to
`PortAS…`, so the test reaches them by name and never sees a port class under a release name.

**What the host holds, measured:**

    fresh  requestedScopes nil   state nil   nonce nil   requestedOperation nil   user nil
    copy   requestedScopes set   state set   nonce set   requestedOperation set   user set
    (with the first three set on the original before copying)

**And it changed this port.** A fresh request's `requestedOperation` is **nil** on the host, not the
implicit operation — the header types the property non-nullable and the release leaves it nil. This port
defaulting it to `ASAuthorizationOperationImplicit` was sending an operation the release does not
send, which is a behavioural difference an application can observe and which no member list can see. The
default is nil now, and the reason is in the source.

    12 keys, 0 differ between the two builds

**Two call targets, proved rather than asserted:** `nm` shows the port's three classes in the binary
under the `Port` names and nothing else, and the test prints the class each side built its request
from and the address `-init` is reached at — two different classes, two different addresses, one
process.

**The value mutant is red**, and three defects stood between it and being so — none of them in the
differential's idea, all three in the machinery around it:

1. **The comparison was blind to the value the mutant changes.** The table's value column is separated
   by a run of spaces and the `requestedOperation` line had a single space, so both of its keys were
   dropped: 12 keys parsed, no `requestedOperation` among them. Every line is aligned now.
2. **The plain run was never called.** `values.sh` defined `build_and_run` and called it only for the
   mutant, then went straight to reading a table nothing had produced.
3. **`set -- $renames` set the script's positional parameters**, and inside `build_and_run` `"$@"` is
   the function's own two arguments — so the compiler was handed the tag `plain` where a `-D` belongs.

Rewritten from the file as it is rather than patched, which is the only reason three was findable: after
several rounds of scripted edits the structure was no longer what I believed it was.

The mutant, traced:

    + build_and_run .../AuthenticationServices plain
    +++ cksum
    +++ cksum
    + echo '   the source changed: cksum 628344446 4733 -> 3096366218 4769'
    + cmp -s .../ASAuthorizationOpenIDRequest.m .../mutant/ASAuthorizationOpenIDRequest.m
    + build_and_run .../mutant mutant
    + cmp -s .../plain-table.txt .../mutant-table.txt

    20c20
    <   fresh   requestedOperation   nil
    ---
    >   fresh   requestedOperation   set

    ok: the mutation changed a value and the check noticed, and the port's own source and library
        were not touched by this run

## What is not done

576 rows. The value differential is green and its mutant is red; the shape differential beside it is
green and its mutant is red. Both are now witnesses rather than demonstrations. The value half of the family is measured (30 constants, 30 agree with the host) and the shape
half has a host differential and a mutant; the classes do not exist yet. The differential is currently
**red** on one case — `-[ASWebAuthenticationSession init]`, which the host has and the port's source did
not, and which has since been added — and that red has not been cleared, so the check is committed in a
state its own report says is failing rather than in a state that says `ok`.
