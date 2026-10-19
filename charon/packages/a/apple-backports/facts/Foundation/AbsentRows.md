# The absent rows, what they owe, and how the next family was chosen

This is not a facts file for an API. It is the state of the registry's own `absent` rows: how many
there are, which of them a host differential can and cannot prove, which family each slice took, and
what is still owed with the exact blocker. Every number is the output of a script in the tree or of a
run in the delivery it belongs to.

## The count, and how to reproduce it

A registry walk (removed) counts the registry files by path (`registry/<Framework>.json` and
`registry/<Framework>/<part>.json`, the two shapes the registry README gives) and refuses a path with
no registry under it. The export is not the instrument for this: its framework column is empty for
every file whose JSON carries no `framework` key, so counting by framework there drops rows and the
number does not reproduce.

The line below is **written by that script** (`--write-facts`, between the two markers) and nothing
else writes it, so it cannot drift from the tree it describes. Every other number in this file names
the tree it was measured on, because a number that says "this tree" is a number that goes stale the
next time anything lands.

<!-- framework: Foundation -->
<!-- count:begin -->
```
Foundation   110 absent   9 ignored   792 implemented   48 inert      (16718 rows, 3209 absent, over 75 frameworks)
```
<!-- count:end -->

## Which of them the host does not answer, and the control that says so

A host differential can only prove the port's own code for an API **the host does not answer**. When
the host answers it too, its implementation is the one that runs, and every assertion becomes a
statement about Apple. That is measured, not assumed:

* the five `NSMutableURLRequest` properties (15.0-26.1) are answered by the host, so a category
  carrying the port's answer is not what runs;
* the mutation that only the port's code can produce - moving the port's own key string - is
  **invisible** in a host binary: `key-moved mutant: ok fresh allowsPersistentDNS NO … ok set
  allowsPersistentDNS YES … exit=0`;
* the three flag mutations came back `NOT NOTICED` for the same reason, and the differential that
  found them would have been a claim about Apple's class.

`.agent-work`-only instrument of that round: a host probe that asks the runtime about each row
(`NSClassFromString`, `NSProtocolFromString`, `class_getInstanceMethod`, `class_getClassMethod`, and
`dlsym` for a constant or a C function), with four controls - a selector the host has, a planted
selector, a class the host has, a planted class - so a run that examined nothing cannot pass. Over the
110 rows of `820a21f76` plus this slice: **30 the host lacks, 80 it has, 0 malformed, 0 unparsed**,
and the controls read `HAS / LACKS / HAS / LACKS` as they must. The probe is `tools/host-has-row.m`,
its input is the registry walk's `--list Foundation` output - the same walk the count above comes from -
and it counts every line it reads: a line it cannot parse is counted and refused
(`input_lines=111 parsed=110 ... unparsed=1`, `FAIL 1 line(s) did not parse`, exit 1) rather than
skipped, because a summary over 109 of 110 rows says nothing about the one it dropped. An earlier run
of it did exactly that: the row in `registry/Foundation.json` (a *file*, not a directory) was missed by
the ad-hoc list writer, which is why both the list and the count come from the one script now.

## The families, by what the host lacks

The groups are the second generated block below, which is the same run and the same tool as the
list above it, so a plan built on it cannot quote a number the block does not carry:

<!-- host-lacks-by-owner -->
<!-- host-lacks-by-owner:begin -->
```
  1  NSUserActivity
  1  NSInflectionRuleAttributeName
  1  NSLanguageIdentifierAttributeName
  1  NSMorphologyAttributeName
  3  NSURLSessionTaskDelegate
  1  NSMarkdownSourcePositionAttributeName
  1  NSInflectionAgreementArgumentAttributeName
  1  NSInflectionAgreementConceptAttributeName
  1  NSInflectionConceptsKey
  1  NSInflectionReferentConceptAttributeName
  1  NSURLSessionUploadTaskResumeData
  1  NSFilePresenter
  1  NSLocalizedNumberFormatAttributeName
  1  NSListItemDelimiterAttributeName
  1  NSPredicateValidating
  2  NSXPCInterface
  2  NSUserActivityDelegate
  4  NSURLSessionStreamDelegate
  1  _os_log_impl
  1  _os_log_error_impl
  1  _os_log_fault_impl
  1  _os_log_debug_impl
  1  _os_log_disabled
# 23 groups over 30 rows the host lacks
```
<!-- host-lacks-by-owner:end -->

| the host lacks | what the port has to build |
| --- | --- |
| the two delegate protocols, the largest group in the block | the port's own loader and stream task, which have to *call* those members at the right moments |
| `NSXPCInterface` | Mach XPC on 4.3 and 6.1.3 - the class itself is the wall |
| `NSUserActivityDelegate` and `NSUserActivity` | the port's own `NSUserActivity` class |
| the item-provider six | **answered**: the rows this series took, which the port's own provider answers (see below) |
| `NSFilePresenter`, `NSPredicateValidating`, `_os_log_*`, the constants | each its own line below |

The **seven session-delegate rows are the largest group the host still lacks**, and they are not the slice that came next,
for a reason that is a limit of the instrument rather than of the work: the code that would call those
seven members is `NSURLSession.m` and `NSURLSessionStreamTask9.m`, which are written against the
device's Foundation (its `NSURLConnection`, its private ivars, `attach.c`) and are not a host
translation unit. The item-provider six were the largest such group whose port code is a self-contained class the
port itself implements, and this slice is them; they are answered, and the host-lacks column is 0 for
them now. The next group of that shape is the three `NSUserActivity` rows.

## Owed, with the blocker

- **The five `NSMutableURLRequest` properties** (`allowsPersistentDNS`, `allowsUltraConstrainedNetworkAccess`,
  `requiresDNSSECValidation`, `attribution`, `cookiePartitionIdentifier`). The code is written and
  compiles clean with the library flags; the defaults and the round trip were read out of the host
  (`NO`, `NO`, `NO`, `0`, `nil`, and every set sticks and survives a copy). Blocker: **the proving
  instrument is the 6.1.3 call test** (`xmake emulate`), the coordinator's gate, because the host's own
  Foundation answers the same five properties and a mutation only the port's code can produce is
  invisible (above). A two-process host probe is the alternative. Not a registry row: the rows stay
  `absent` until something proves them, and this line is what they owe.
- **The five `NSFileManager` ubiquity and file-provider methods** (11.0, four of 26.0). The oracle is
  already measured: for a local path with no provider and no iCloud the host answers nil plus
  `NSCocoaErrorDomain 3328` for `fetchLatestRemoteVersionOfItemAtURL:`, `pauseSyncForUbiquitousItemAtURL:`,
  `resumeSyncForUbiquitousItemAtURL:withBehavior:` and `uploadLocalVersionOfUbiquitousItemAtURL:withConflictResolutionPolicy:`,
  and nil plus `NSFileProviderInternalErrorDomain 0` for `getFileProviderServicesForItemAtURL:`. The
  port's category is small; the proof has the same blocker as the five above.
- **The seven session-delegate members**: the port's own `NSURLSession.m` and `NSURLSessionStreamTask9.m`
  have to call them, and neither is a host translation unit. Owed with the 6.1.3 call test.
- **The names this family owes** - the inflection, morphology, markdown and attributed-string
  vocabulary, `NSURLSessionUploadTaskResumeData`, `NSListItemDelimiterAttributeName`,
  `NSLocalizedNumberFormatAttributeName` - are owed for their **values**. The block below is
  `tools/host-has-row.m --write-facts` over the registry walk's `--list Foundation` output: it is every
  absent Foundation row the host does not answer, and **eleven** of the ones in this family are in it -
  `NSInflectionRuleAttributeName`, `NSLanguageIdentifierAttributeName`, `NSMorphologyAttributeName`,
  `NSMarkdownSourcePositionAttributeName`, `NSInflectionAgreementArgumentAttributeName`,
  `NSInflectionAgreementConceptAttributeName`, `NSInflectionConceptsKey`,
  `NSInflectionReferentConceptAttributeName`, `NSURLSessionUploadTaskResumeData`,
  `NSLocalizedNumberFormatAttributeName`, `NSListItemDelimiterAttributeName` - so for those there is
  no host oracle at all; the rest of the family the host has a name for and what it lacks is the
  release-ladder reading. No count of the whole family is written here on purpose: a number typed beside
  a list the tool prints is a number that goes stale, which is what this section had twice. The facts
  file that carries the family refuses a header comment as a source. Blocker: `xmake firmware --arch=<a> fetch <a release new enough to export
  them>` and one `tools/corpus/cache-value.lua` run each - the network, not a slot. **`cachetools-fix3`
  is on this path**: `cache-value.lua`'s 32-bit reads are what a cache value read goes through.

<!-- host-lacks -->
<!-- host-lacks:begin -->
```
-[NSUserActivity deleteSavedUserActivitiesWithPersistentIdentifiers:completionHandler:]
NSInflectionRuleAttributeName
NSLanguageIdentifierAttributeName
NSMorphologyAttributeName
-[NSURLSessionTaskDelegate URLSession:didCreateTask:]
NSMarkdownSourcePositionAttributeName
-[NSURLSessionTaskDelegate URLSession:task:didReceiveInformationalResponse:]
-[NSURLSessionTaskDelegate URLSession:task:needNewBodyStreamFromOffset:completionHandler:]
NSInflectionAgreementArgumentAttributeName
NSInflectionAgreementConceptAttributeName
NSInflectionConceptsKey
NSInflectionReferentConceptAttributeName
NSURLSessionUploadTaskResumeData
-[NSFilePresenter accommodatePresentedItemEvictionWithCompletionHandler:]
NSLocalizedNumberFormatAttributeName
NSListItemDelimiterAttributeName
NSPredicateValidating
+[NSXPCInterface XPCTypeForSelector:argumentIndex:ofReply:]
+[NSXPCInterface setXPCType:forSelector:argumentIndex:ofReply:]
-[NSUserActivityDelegate userActivity:didReceiveInputStream:outputStream:]
-[NSUserActivityDelegate userActivityWasContinued:]
-[NSURLSessionStreamDelegate URLSession:streamTask:didBecomeInputStream:outputStream:]
-[NSURLSessionStreamDelegate URLSession:betterRouteDiscoveredForStreamTask:]
-[NSURLSessionStreamDelegate URLSession:readClosedForStreamTask:]
-[NSURLSessionStreamDelegate URLSession:writeClosedForStreamTask:]
_os_log_impl
_os_log_error_impl
_os_log_fault_impl
_os_log_debug_impl
_os_log_disabled
# 30 rows the host lacks, over the tree this walk read
```
<!-- host-lacks:end -->
- **The five `NSUndoManager` rows**: a policy question, not a build. The release's own manager keeps
  its stack private and exposes no count, so a category cannot answer `undoCount` truthfully and a
  count answering 0 is the silent fake the worker brief forbids; `inert` against `ignored` is the
  owner's call.
- **The seven `NSXPC*` rows**: Mach XPC on 4.3 and 6.1.3 is a real port of the machinery, not a slice.
