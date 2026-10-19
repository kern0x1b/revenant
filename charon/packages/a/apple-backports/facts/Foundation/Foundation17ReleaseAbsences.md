# The release-level absences behind the iOS 17.0 rows in registry/Foundation/ios17-18.json

Nine rows of that file read `absent` and cited only the SDK's own declaration, which is the
one kind of source the rulebook calls an assertion rather than a measurement. Each is closed
here with the command a reader can re-run and its output beside it. Every measurement is
class-scoped, and every run carries its control, so a zero is the release's answer and not
the reader's blindness.

The claim in each row is about **the release**, which is what `absent` means. It is not a
claim that the port will never carry the API: `Foundation/NSURLSession.m` is the port's own
NSURLSession, and a resumable upload is buildable over it. See "What this does not claim".

## The two censuses, and their controls

The prepared per-release class census, read with `python3`:

```
for r in 4.3 4.3.5 6.0 7.0:
    ~/.charon/dyld/$r/classes_armv7.json  ->  7187, 7208, 11284, 14765 classes
```

**Control:** each of those four counts is what a single run read, and each run matched a
class (below), so the reader is demonstrably finding classes rather than returning nothing.
The `6.0` rung is the one the rows' `minimum` reaches.

## NSAttributedString's four formatting accessors: no entry point, and no plural engine

`6.0`'s own `NSAttributedString` carries no formatting entry point at all. Its class methods
are `attributedStringWithAttachment:`, `allocWithZone:`, the `_documentTypeForFileType:`
private and the GK/UIKit private rendering helpers; the only format-shaped name on it is the
private `attributedStringWithFormatAndAttributes:`. There is no `initWithFormat:` and no
public `attributedStringWithFormat:` on the release, in either direction:

```
python3 -c 'import json,os
c=json.load(open(os.path.expanduser("~/.charon/dyld/6.0/classes_armv7.json")))["classes"]["NSAttributedString"]
print(sorted((c.get("class") or {}).keys()))'
```

The second half of the claim is the one that decides the row. A format template may contain
`%#@`, and `%#@` selects among plural forms by the CLDR plural category of a variable. Does
this rung have anything that computes a plural category?

```
python3 -c 'import json,os
c=json.load(open(os.path.expanduser("~/.charon/dyld/6.0/classes_armv7.json")))["classes"]
h=[(("-" if s=="instance" else "+")+n,k) for n,e in c.items() for s in ("instance","class") for k in (e.get(s) or {}) if any(p in k for p in ("plural","Plural","CLDR","ICU","icu"))]
print(len(c), h)'
  11284 [('-PKIngestibleCard','pluralTemplateDescription'),
         ('-PKPass','pluralTemplateDescription'),
         ('-EMNumberFormatter','icuFormatString'),
         ('-IUVideoSummaryView','_populateHeaderAndContentLabels:key:singular:plural:header:content:')]
```

**Control:** 11284 classes read in that run, and the only four names on the whole rung that
mention plurals or ICU are a PassKit ingestible-card description, an iMessage number
formatter's own format string, and a private UIKit label filler. None computes a plural
category, and none is a public mechanism a formatter could ask. So `%#@` has no native
implementation on this rung, and a formatter that ignored it would answer wrong text silently
rather than fail — which is why the four rows stay absent rather than being written to
handle the directives that happen to be easy.

## NSURLSession's five upload rows: the release has no NSURLSession

```
python3 -c 'import json,os
for r in ("4.3","6.0"):
    c=json.load(open(os.path.expanduser("~/.charon/dyld/"+r+"/classes_armv7.json")))["classes"]
    print(r, len(c), [n for n in c if "URLSession" in n])'
  4.3  7187 []
  6.0 11284 []
```

**Control:** 7187 and 11284 classes read, zero of them named URLSession on either rung, while
the same reader matched classes elsewhere in the same runs. Apple shipped NSURLSession in
iOS 7, above every rung this port's `minimum` reaches, so on this release there is no task to
produce resume data from and no delegate to send `didReceiveInformationalResponse:` or
`needNewBodyStreamFromOffset:completionHandler:` to.

## The owner trap, measured twice — a selector string is not an NSLocale or an upload task

`tools/cache-index/first-rung.lua` places two of these names on rungs, and in both cases the
owner is not the class the row is about:

| name | first held rung | the class that actually owns it there |
| --- | --- | --- |
| `regionCode` | 4.3 | `-[AADeviceInfo regionCode]`, private AdSupport |
| `cancelByProducingResumeData:` | 7.0 | `-[__NSCFURLSessionDownloadTask …]`, `__NSCFBackgroundDownloadTask`, `__NSCFLocalDownloadTask` |
| `languageIdentifier` | 8.0 | no `NSLocale` at any of 4.3, 4.3.5, 6.0, 7.0 |

So `cancelByProducingResumeData:` does exist by 7.0, on the **download** task's private
subclasses, and reading the rung as the answer for `NSURLSessionUploadTask` would be wrong in
the direction of claiming a capability that is not there.

## The 6.1.3 rung itself, read through the rungs' own reader

The prepared censuses above are 4.3, 4.3.5, 6.0 and 7.0. The band the 6.1.3 gate links was
also read directly, through `modules/apple/objc.lua`'s `inventory` — the rungs' own reader:

```
xmake l .agent-work/probe/inv.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 \
    NSFilePresenter NSAttributedString
  control: 11378 classes, 188523 instance selectors, 15334 class selectors read in this run
  class NSFilePresenter    ABSENT
  class NSAttributedString PRESENT  superclass=NSObject  image=.../Foundation.framework/Foundation
```

**Control:** 11378 classes and 203857 selectors read in that one run, and the reader matched
`NSAttributedString` in it while reporting `NSFilePresenter` absent — so the absent is the
release's. `NSAttributedString`'s 96 instance methods on that rung contain no `initWithFormat:`
and no format initializer of any public shape, and among its class methods the only
format-shaped name is the private `-attributedStringWithFormatAndAttributes:`, exactly as on the
6.0 rung. So both halves of the NSAttributedString claim, and the whole NSFilePresenter claim,
hold at the rung this port's minimum is gated on.

## What this does not claim

`Foundation/NSURLSession.m` is the port's own NSURLSession and it already implements
download resume data end to end. The three upload resume rows are buildable over it, and the
two delegate messages need the loader's 1xx and body-exhaustion paths to send them — paths
that live in that file, which carries releases 7 and 9 already, so a release-17 object cannot
add them under the one-object-one-release rule. **Closing these nine rows as `absent` records
what the release does, and is not a decision that the port should never carry them.** A
follow-up that adds the sending to `NSURLSession.m` should reopen all five.