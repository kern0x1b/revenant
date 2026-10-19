# WKContentRuleList and WKContentRuleListStore (iOS 11.0)

What a content rule list is, what a compile refuses, and where every answer below was measured. A
content rule list is the one part of a web extension API that needs no web view to be real: it is a
JSON file the release parses once, keeps, and hands back as an object carrying the identifier it was
compiled under. So this family carries on a release with no WebKit at all, like `WKWebExtension`
itself (facts/WebKit/WebExtension.md).

The measurements are `tests/backports/host/webkit/contentrulelist_scenario.h`, asked of the host's own
WebKit under Mac Catalyst by `contentrulelist_system.m` with no port code in the process and then asked
of the port by `contentrulelist_test.m` against the same answers. 106 cases. `run.sh` builds both, and
its exit status is the verdict.

## What a compile refuses, and in what order

Every refusal is `WKErrorDomain` with `WKErrorContentRuleListStoreCompileFailed`, and the reason is in
the error's `NSHelpAnchor`, which is the only thing that separates two failures carrying the same code.
The port writes the host's own sentences, and the differential compares them verbatim: a WebKit that
rewords one turns the comparison red rather than quietly agreeing on less.

| the list | the sentence under `NSHelpAnchor` |
| --- | --- |
| not JSON at all, or no list at all | `Failed to parse the JSON String.` |
| a JSON object, string or null | `Invalid input, the top level structure is not an array.` |
| an empty array | `Empty extension.` |
| an entry that is not an object, including null | `Invalid rule.` |
| no trigger, or a trigger that is not an object | `Invalid trigger object.` |
| a resource-type or load-type that is not an array | `Invalid trigger flags array.` |
| a resource type or load type the release has not heard of | `Invalid string in the trigger flags array.` |
| an if-domain or unless-domain that is not an array, or is empty | `Invalid list of if-domain, unless-domain, if-top-url, or unless-top-url conditions.` |
| both if-domain and unless-domain on one trigger | `A trigger cannot have more than one condition (if-domain, unless-domain, if-top-url, or unless-top-url)` |
| no action, or an action that is not an object | `Invalid action object.` |
| an action type that is not one of the five | `Invalid action type.` |
| `css-display-none` with no selector | `Invalid css-display-none action type. Requires a selector.` |
| no url-filter, or one that is not a string | `Invalid url-filter object.` |
| a url-filter or a domain pattern the release's own engine will not compile | `Invalid or unsupported regular expression.` |
| the store cannot be written, which a program can arrange by putting a regular file where the store's directory goes | `Unspecified error during compile.` |

**The order is not the order the keys are read in**, and it was measured rule by rule rather than
assumed: a rule with a bad action type and an unbalanced url-filter reports the **action**, and a rule
with a bad resource type and a bad action reports the **flag array**. So the port checks the trigger's
shape, then its flag arrays, then the action's shape and type, and only then the url-filter and the
domain patterns.

Three things about that table are worth stating because they are not what the keys suggest:

- **An empty identifier is an identifier, and so is none at all.** The release compiles under `""` and
  under no identifier, and hands back a list whose own `identifier` is the empty string. The port does
  the same rather than refusing one.
- **An empty domain list is refused and an empty resource-type list is not.** `if-domain: []` carries
  the "Invalid list of ..." sentence; `resource-type: []` compiles.
- **A refused compile leaves the store exactly as it was**, which is the host's own answer for an
  identifier that was stored before and is asked to compile something unusable after.

## The url-filter grammar is the release's own engine, not ICU's

A rule list is matched against every request a web view loads, so the release compiles each pattern
once into YARR, and YARR refuses everything it does not implement. Fifty patterns were asked one at a
time; the port refuses exactly what YARR refuses.

refused: an unescaped `|` ("Disjunctions are not supported yet"), `(?=`, `(?!`, `(?<=` and `(?<!`, a
`{2}` or `{2,3}` counted repetition, any `(?...)` that is not `(?:` or `(?<name>`, `\b` and `\B` ("Word
boundaries assertions are not supported yet"), `\k<name>` ("Patterns cannot contain backreferences"), a
quantifier with nothing in front of it, a class or a group left open, and two groups sharing a name.

accepted: literals, a dot, character classes with POSIX classes inside them (including one the release
has no name for, `[[:foo:]]`), `^` and `$`, `+` `*` `?` and their lazy forms, groups including the empty
one, `(?:...)` and `(?<name>...)`, escaped metacharacters (`\|` `\\(` `\\)` `\\{` `\\}` `\\.`), numeric
backreferences, `\\Q...\\E`, `\\p{L}`, an unpaired `{`, and a lone `]`.

Two of these are the reason the port does **not** use `NSRegularExpression`, which would have been wrong
in both directions: ICU refuses `a{` and `*example.com`, which YARR accepts in a domain condition, and
ICU accepts `a{2}` where YARR refuses. And the leading quantifier is refused in a **url-filter** and
accepted in a **domain condition** -- measured both ways, so the two are not the same check.

`redirect` and `modify-headers` are action types the host knows and this port refuses as unknown, with
the same "Invalid action type." sentence. They are additions to Safari's list and not of the 11.0 API
this object carries, whose header declares five action types; `webtransport`, `webbundle`, `manifest`
and `xslt` are refused the same way as resource types.

## The store, and what is not part of its API

The release's store is a **directory** at the url with a file per compiled list in it, some named after
the identifier and some not (measured: the url is a directory, and its contents are the identifiers'
files plus a second file per list). That naming is Apple's and not an API, so the port keeps the shape
and its own file: one directory at the url, one file in it holding every identifier with the list
stored under it. What the API promises -- a list written in one process is there in the next -- holds
either way, and the differential holds it: the system side runs first against one directory and the
port side second against that same directory.

`+defaultStore` answers the same object on every call (measured), over the app's Application Support
directory, which the 4.3 band this library also builds for does not have: HomeKit's own store falls back
to the temporary directory the same way.

**The order `getAvailableContentRuleListIdentifiers` answers is not part of the API.** The release
answers whatever order its directory hands over -- measured over fifteen lists stored in one order and
read back in another, and the answer was neither that order nor sorted. The port answers the order it
stored them in, which is at least deterministic, and the differential sorts both sides before comparing
them and compares the count separately.

Every answer is delivered on the main thread, which is what the host does whether the call came from
the main thread or from another one (measured both ways). Whether it is delivered *before* the call
returns is not consistent in the host either -- its cheap refusals answer inside the call and its
expensive ones answer from the run loop -- so the port answers inside the call when it is already on
the main thread and hops to it when it is not. That is not part of the API either, and the differential
turns the run loop until every case is answered, which is the only thing it needs.

## What this port cannot do

A compiled list is applied by a web view's content blocker, and this port has no web view: the rules
are validated and kept, and **no rule of them is ever run**. `WKUserContentController`'s three
rule-list methods, which hand a list to the web view that would apply it, are not carried for that
reason and are named in the band report.

## The one refusal a program can arrange, and the one branch no probe reached

A store whose url a **regular file** occupies is the one refusal a program can bring about, and the
release answers its own sentence for it -- measured by writing a file where the store's directory goes:

```
  the path is a NSFileTypeRegular
  compile into a regular file: nil | WKErrorDomain 6 | Rule list compilation failed: Unspecified error during compile.
  identifiers there: ( )
  lookUp there:        nil | WKErrorDomain 7 | Rule list lookup failed: Unspecified error during lookup.
```

That sentence is NOT one of the list's own, and the port writes that one. Three cases
(`blocked.identifiers`, `blocked.compile`, `blocked.lookUp`) hold both sides to it.

One branch is still not measured, and it is named rather than covered: a store file that is not the
JSON this port wrote. The release's store keeps a compiled binary per list in Apple's own layout, so a
file this port cannot parse is not a state a program can produce there, and the port answers an empty
store for one rather than a guessed error. Its own file is the only thing it ever reads.

## The red control

`run.sh` plants one refusal in a copy of `WKContentRuleList11.m` -- the rule check returns nil -- and
this comparison has to go red on it, and does:

```
rules red control: exit=1 with a planted refusal, and the cases that moved are:
    port   case refuse.noTrigger list r6 | no error
    system case refuse.noTrigger nil | WKErrorDomain 6 | Rule list compilation failed: Invalid trigger object.
```