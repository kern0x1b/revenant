# NSFileProviderManager: what answers, and where the answer comes from

The first family of the FileProvider port, and the one with 38 of the 217 missing rows in
`coordination/corpus/ledger/FileProvider.tsv`. The class arrived in iOS 11.0; the release this
port builds is 6.1.3, which has no FileProvider framework and no extension host at all, so the
whole family is the port's own work.

## Oracle: the host, for the two members the header leaves available

**I got this wrong once and the header settles it.** A first pass took `defaultManager` and
`providerIdentifier` for iOS-only and reported the manager unmeasurable. `NSFileProviderManager.h`
in the Command Line Tools' macOS SDK says otherwise:

```
62:  @property (class, readonly, strong) NSFileProviderManager *defaultManager API_UNAVAILABLE(macos);
67:  + (nullable instancetype)managerForDomain:(NSFileProviderDomain *)domain;
217: + (NSURL *)placeholderURLForURL:(NSURL *)url FILEPROVIDER_API_AVAILABILITY_V2;
244: + (void)getDomainsWithCompletionHandler:(void (^)(NSArray<NSFileProviderDomain *> *domains, NSError * _Nullable error))completionHandler;
```

`defaultManager` is the one excluded on macOS, and `placeholderURLForURL:` carries
`FILEPROVIDER_API_AVAILABILITY_V2`, which the Swift importer refuses there. **`managerForDomain:`
and `getDomainsWithCompletionHandler:` carry NO availability macro at all** - they are available,
and the earlier failure was my Swift spelling (`.manager`), not the platform.

Measured, in Objective-C, with the header's own selectors
(`.agent-work/probe/host/domains-host.m`, read-only: a list and a lookup on a domain that is not
registered):

```
getDomainsWithCompletionHandler: = 0 domain(s), error = The application cannot be used right now.
   NSError domain/code           = NSFileProviderErrorDomain / -2001
managerForDomain(unregistered)  = a manager
NSFileProviderErrorDomain       = NSFileProviderErrorDomain
   NSFileProviderErrorNoSuchItem      = -1005   "no such item"
   NSFileProviderErrorServerUnreachable = -1004
```

**Two lines of the previous version of this file were wrong, and both were guesses dressed as
findings.** `getDomains` is not "an empty array and no error": it is an empty array **and an
error**, `NSFileProviderErrorDomain` code **-2001**. And `managerForDomain:` on an unregistered
domain is **a manager, not nil**. A third guess is gone with them: `DomainNotFound` and
`NoSuchExtension` are **not declared at all** in the macOS SDK's `NSFileProviderError.h` - I made
those names up, and the codes above are the ones that exist.

So the table, per member, with where each answer comes from:

| member | answer | oracle |
| --- | --- | --- |
| `+getDomainsWithCompletionHandler:` | **0 domains, and an error**: `NSFileProviderErrorDomain` / -2001 | **the host**, measured |
| `+managerForDomain:` (unregistered) | **a manager** | **the host**, measured |
| `+defaultManager` | excluded on macOS; on 6.1.3 a manager with no domains | documentation - the host is absent, and iOS-only |
| `-placeholderURLForURL:` | `FILEPROVIDER_API_AVAILABILITY_V2`, refused by the macOS importer | documentation - the host is absent |
| `-providerIdentifier` | same macro, refused on macOS | documentation |
| `-addDomain:` / `-removeDomain:` / `-removeAllDomains…` | the completion with the documented error | **forbidden on the host**, as on the device |
| `-signalEnumeratorFor…`, `-claimKnownFolders:…`, `-registerURLSessionTask:` | as the header documents | **forbidden on the host** |
| `NSFileProviderError` codes | the values above, from the header and quoted by the host | **both** |

## The honest limit

**There is a differential for the two measurable members and not for the rest.** `getDomains` and
`managerForDomain:` are measured above and can be compared on both sides, and the error domain and
its codes are measured on both. The members that would exercise the manager's behaviour -
`addDomain:`, `removeDomain:`, the known-folder claim, the task registration, the enumerator
signalling - are forbidden on the host and absent on 6.1.3, so their answers come from the
documentation and the table says which line is which.

The mutant belongs on the constants: change a code the port exports and the differential goes
red against -1005 and -2001.

## Two members the ledger lists and the 26.2 header does not declare

`-[NSFileProviderManager requestDiagnosticCollectionForItemWithIdentifier:errorReason:completionHandler:]`
and `-[NSFileProviderManager requestDownloadForItemWithIdentifier:requestedRange:completionHandler:]`
are rows in `coordination/corpus/ledger/FileProvider.tsv` at 11.0, and **the 26.2 header does not
declare either of them** — measured by reading `NSFileProviderManager.h` out of the 26.2 SDK
(`toolchain/.agent-work/sdk-26.2`) for every declaration. They are 16.4-era declarations that 26.2 no
longer carries, so the target SDK has no version for them and they get **no registry row**: a row
would have to carry an `introduced` this SDK does not say. The ledger is not wrong to list them —
it records the 16.4 surface — and the disagreement is recorded here rather than settled by picking
one of the two.

## The nine rows whose release is inferred from the class

A member of `NSFileProviderManager` takes its release from its **own** `AvailabilityAttr`; failing
that, from the **enclosing category's**; failing that, from the **class's**, which is `ios 11.0` — the
attribute at line 4 of the dump. **Nine** rows resolve that way, and the table's `source` column says so for each:
`defaultManager`, `addDomain:completionHandler:`, `getDomainsWithCompletionHandler:`,
`init`, `managerForDomain:`, `removeAllDomainsWithCompletionHandler:`,
`removeDomain:completionHandler:`, `registerURLSessionTask:forItemWithIdentifier:completionHandler:`
and `signalEnumeratorForContainerItemIdentifier:completionHandler:`.

The count is **nine** and the review said seven. The arithmetic is in the table: the raw scanner
output had **ten** `none` rows, one of which belongs to `MaterializedSet` and resolves to 16.0 by
its own category, leaving nine for the class. I wrote seven into this paragraph first and
corrected it against the table rather than against the review's number.

The reason they need it is a fact about the dump, not about the header: `-ast-dump-filter` prints a
category's methods as **top-level declarations with no category above them**, so a member declared in
a category arrives with no attribute and no parent to inherit from, and the scanner answers `none` for
all seven. Only `MaterializedSet` — the one category of the eleven with a version of its own — is
resolvable on its own account, and it is **16.0**; the other ten take the class's, and the two the
corpus prices at 16.0 (`getUserVisibleURLForItemIdentifier:`, `removeDomain:mode:`,
`getIdentifierForUserVisibleFileAtURL:`, `temporaryDirectoryURLWithError:`, `globalProgressForKind:`,
`signalErrorResolved:`) each carry their own attribute, so they are not among the seven.

## What the host registers under this prefix, and where the 25 comes from

`packages/frameworks/apple-backports/spec/FileProvider/bands.json` carries `expect_classes: 25`, and every run of
`tests/backports/host/inventory/run.sh FileProvider` compares the host's own count against it, so a
host that answers fewer classes fails instead of quietly reading smaller. **25 classes and 34
protocols** is what the host registers under the `NSFileProvider` prefix, measured:

```
sh tests/backports/host/inventory/run.sh FileProvider

  HOST: NSFileProvider -> 25 classes, 34 protocols
  COUNT: 25 classes, as the spec expects
  PORT: 5 objects built and read
  CARRIED: 8 never_call names present as an exact nm symbol in the built object
  inventory: FileProvider green
```

The prefix is `NSFileProvider` and not the framework's name, because the framework is `FileProvider`
and its classes are `NSFileProvider*`: a probe matching on the framework name finds nothing and
reports 0 of 0, which is why that harness fails a prefix that matches nothing rather than passing it.

The harness sits **beside** this framework's own differential rather than in place of it, and its
own header says so: `differential.m`/`run.sh` compare the port's `NSFileProviderManager.m` with the
host line by line (`VERDICT: green` above), which the inventory cannot do — it counts names, and it
reads the eight `never_call` names out of the built object rather than out of the source tree,
because the port keeps no `.o` files there and a check that read `$pkg/*.o` was comparing an empty
set. One measures the answers, the other measures that the band objects exist and carry what the
spec says they carry; neither answers for the other.

