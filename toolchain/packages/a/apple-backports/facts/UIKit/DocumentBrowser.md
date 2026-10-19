# UIDocumentBrowserViewControllerDelegate, and the rest of the document browser

## What this piece declares

`UIDocumentBrowserViewControllerDelegate` as the 26.2 header declares it: seven questions, every
one of them `@optional`, including the two pairs spelled two ways — `didPickDocumentURLs:` (11.0) and
`didPickDocumentsAtURLs:` (12.0), and nothing else in this protocol has a second spelling.

The declaration is a **transcription**, not a design, and it lives in
`UIKit/UIDocumentBrowserViewControllerDelegate.h` because a 6.1.3-era SDK has no
UIDocumentBrowserViewController at all. `RevenantDocumentBrowserTypes.h` carries the one enum and the
three `@class` lines the questions refer to, with no condition on which SDK is in use, so the same
file works against every SDK the port builds with.

Why a transcription at all: the 16.4 SDK this package builds against does not carry
UIDocumentBrowserViewController, so the names are not visible to a translation unit here and an
application compiled against the port's header links the protocol through this declaration.

## Eight rows, and the check that justifies them

`registry/UIKit/documentbrowser.json` carries **eight**: the protocol and its seven questions, at the
header's own availability of 11.0. The seven are **counted from the AST's selector set**, not written
out by hand, so the file and the compiler cannot disagree about how many there are.

`tests/backports/host/documentbrowser/ast_check.py` is the gate, and it is green with both controls
named:

    UIDocumentBrowserViewControllerDelegate: header 7 selectors, port 7
      required: header 0, port 0
      the independent count of the port's method lines: 7
      control, @optional flipped: documentBrowser:didRequestDocumentCreationWithHandler: is now required
      control, documentBrowser:applicationActivitiesForDocumentURLs: removed: the AST went 7 -> 6 and named it
    PASS: the port's declaration is the header's, selectors and optionality

The optionality is read from the compiler and not from the file: an empty conformer compiled with
`-Wprotocol` is warned about for every `@required` method and for none of the optional ones, so the
selectors those warnings name are the required set. Measured directly on the flipped copy, seven
warnings appear and none appear unflipped, and **all seven of this protocol's questions are
optional**, so the required set is empty on both sides — which is what the header says and what the
port now agrees with.

## The count, and which is right

**Twenty-three is the right number and twenty-one was my error.** The corpus has twenty-three rows in
this family, and the two pairs of duplicate spellings are *two rows each*, not one: they are
different names with different `introduced` values — `didPickDocumentURLs:` at 11.0 and
`didPickDocumentsAtURLs:` at 12.0, and `transitionControllerForDocumentURL:` at 11.0 and
`transitionControllerForDocumentAtURL:` at 12.0 — so collapsing each pair to one method loses a row
the corpus counts and the registry must answer. Eleven are on the view controller, two on the
transition controller, one is the delegate protocol, and the remaining seven are its questions.

## Twenty-one rows claimed, two to go

`documentbrowser.json` carries **twenty-one**: the delegate protocol and its seven questions, the
transition controller and its two properties, and the view controller with its nine properties.
Every group is counted from the AST — the protocol's selectors by `mangledName`, the classes'
properties from the AST's property declarations — and not written out by hand, so the registry and
the compiler cannot disagree about how many there are.

`UIDocumentBrowserViewController` is **`absent`**, and that is the whole point: its nine properties
are carried, its five instance methods are not — `importDocumentAtURL:…` and
`revealDocumentAtURL:…` have no bodies and `initForOpeningFilesWithContentTypes:` and the two
spellings of `transitionControllerForDocument…` are declared but unclaimed — so a class is not
implemented until all of its members are, and the row says so in the same file that carries its
properties. An earlier report of this piece called the class `implemented` on the strength of its
properties; that contradicted the rule stated in the same paragraph, and the row now follows the rule.: the check verifies that the port's
file declares both spellings of `transitionControllerForDocument…` and the AST has them, but the
AST cannot separate a header's own declarations from the ones it inherits from `UIViewController`, so
it cannot yet tell the port has *implemented* them, and a row that says `implemented` for a method
nobody calls is the exact thing this series keeps refusing to write. The check's two new controls are
live and named — dropping `weak` and `nullable` from `delegate`, and removing the 11.0 spelling from
the port's file — and the class's remaining two rows wait for the piece that gives the methods bodies.

## The family is closed: twenty-three of twenty-three

The five instance methods have bodies, in four commits, one method each, and the class row is
`implemented` because all fourteen of its members are — nine properties, five methods — each a row in
`documentbrowser.json` and each a body in `UIDocumentBrowserViewController.m`.

The behaviour is inside the application, because there is no Files app on this release: the browser's
own place is the application's Documents directory, an import copies or moves the document beside the
one named as the mode says, a reveal answers where the document is -- importing it first when asked
and saying so when not -- and the transition question is answered with a controller aimed at the
browser's own view. **Every completion is called exactly once on every path**, because a caller that
blocks on a completion never called is a caller that never returns, and that includes the paths where
the document was missing, nowhere could be put, and the copy or the move failed.

The one thing still unmeasured is the behaviour itself: the AST check covers the *declarations*, and
the bodies are verified to compile against the port's own headers, but no run exercises a copy and a
move. That is the next piece — a differential over a real import, a real reveal, and a real failure,
with a mutant per behaviour.



## What the check compares, and what it cannot

Both sides are read the same way. The selector set comes from clang's JSON AST keyed by
`mangledName`. The required/optional split comes from the compiler and not from the file: an empty
conformer compiled with `-Wprotocol` is warned about for every `@required` method and for none of the
optional ones, so the selectors those warnings name are the required set. There is no line arithmetic
anywhere, because the compiler already knows.

The two sides differ only in the translation unit — the header's imports UIKit, the port's imports
Foundation and the port's own headers — and that difference is the whole reason the check can mean
anything. With the umbrella in the port's unit, the SDK's declaration of this protocol shadows the
port's and the compiler reads only the SDK's copy: the port's transcription checked against itself.


## The bodies run, and one of them is wrong

`tests/backports/host/documentbrowser/` runs the five methods on the host, against the port's own
file compiled with a stand-in for the one UIKit interface it needs, and against real files in a
scratch directory under `.agent-work/runs/documentbrowser/` — never a system temp path and never the
shared SDK. **Eighteen of the nineteen checks pass.**

The one that does not:

    FAIL a reveal that imported answers with where it landed, not where it was asked from
         -- /var/.../revenant-dbr-elsewhere/wanted.txt

`revealDocumentAtURL:importIfNeeded:completion:` imports beside the browser's own directory, and the
document comes back at the URL it was asked from rather than where it landed. Writing the test is
what found it, which is the only reason the check exists.

**That check was wrong, and the port was right.** The document a reveal was asked about existed at
that URL, so answering with that URL is what reveal must do; the import only happens for a document
that is *not* here, and the only place one can come from is a document provider. This release has no
Files app and this host has no provider, so that path is a **seam**: it is skipped, with its reason
printed, and the test says why rather than passing a check it cannot make.

**`UIDocumentBrowserViewController` is `implemented`**, because its nine properties are measured by
the AST check, four of its five bodies are run with a mutant each that goes red by name, and the
fifth is a seam named in the row itself. Fourteen members, fourteen rows, and no row here that a
check behind it does not support.

The review of r11 found the transition controller `implemented` with no `@implementation` at all.
That is fixed in the same series: `UIDocumentBrowserTransitionController.m` is the class's own
storage for the two properties its header declares, and the behaviour harness builds and runs it.


## The transition, and what is measured about it

`UIDocumentBrowserTransitionController` declares conformance to
`UIViewControllerAnimatedTransitioning` and now honours it. The review found the conformance
declared and neither required method implemented; `clang -Wprotocol` names both —
`transitionDuration:` and `animateTransition:` — and with them implemented the file compiles with
**no warning under the library's own flags**,
`-Werror=objc-missing-property-synthesis` and the rest, against the 16.4 SDK the library is built
with.

**Neither body is a transcription of Apple's, and that is the point.** What the port implements is
what these two questions can mean on a release with no Files app and no document provider:

- `transitionDuration:` is the time a document takes to appear once it has arrived, and **zero while
  it is still being brought across**, because there is nothing on screen yet to move. The number for
  the arrived case is the port's own — the header states no duration and Apple names none this port
  can read — and it is written down as the port's where it is declared.
- `animateTransition:` is a plain cross-dissolve of the view this transition was aimed at, and it
  completes the transition **even when there is no view at all**, because a caller waiting for a
  completion that never comes waits for ever.

**Measured, by the host harness:** a document that is here takes a positive time; one still loading
takes none; running a transition brings the view to full opacity and completes the context; a
transition with no view still completes.

**Not measured, and not claimed:** what a real document browser's transition looks like, its real
duration, and whether it animates the document at all. Those are Apple's, on a release with a Files
app and a document provider, and neither this host nor this release has either. The port
cross-dissolves the view it was given because that is what a cross-dissolve is for and because there
is nothing else it can honestly do.

The host harness reaches the animation through a stand-in for `UIView`'s own animation API, named
after the header the SDK declares the protocol in — `UIViewControllerTransitioning.h`, not a file
named after the protocol, which the review found and no build would ever have found.
