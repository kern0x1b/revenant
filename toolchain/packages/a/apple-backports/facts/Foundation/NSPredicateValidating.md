# NSPredicateValidating and -allowEvaluationWithValidator:error:, iOS 26.4

Two rows of `registry/Foundation/ios26.json` that cannot be written yet, and the measurement that says why.
**Neither name is declared by either SDK this package can read**, so the contract is not readable. There
are two, not one: the build SDK, and the 26.2 copy `tools/intents/generate.sh` calls `SDK_262` - which the
coordinator keeps unpacked under `toolchain/.agent-work/sdk-26.2`, a scratch directory a worktree sweep
deletes, so it is named by that variable and not by a path that will not be there.

    $ SDK164=~/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk
    $ SDK262=$HOME/Git/projects/ios/revenant/.agent-work/sdk-26.2/iPhoneOS26.2.sdk
    $ for sdk in "$SDK164" "$SDK262"; do
        echo "$(basename "$sdk") $(grep -rl NSPredicateValidating "$sdk" | wc -l) $(grep -rl allowEvaluationWithValidator "$sdk" | wc -l) $(grep -rl NSPredicate "$sdk" | wc -l)"
      done
    iPhoneOS16.4.sdk 0 0 95
    iPhoneOS26.2.sdk 0 0 88

The third number is the control that says the search does find headers at all: **0, 0 and 95** for the
build SDK, **0, 0 and 88** for the 26.2. The two counts differ because the SDKs differ - 26.2's
Foundation carries 129 header files to 16.4's 126 - which is why the control is a count and not a bare
zero.

So 16.4 declares neither name and 26.2, which is a newer header, declares neither name either. The rows'
own `introduced` is **26.4**, which no SDK here reaches - it comes from
`coordination/corpus/registry-last.tsv`, a registry-derived snapshot, so it is the corpus's number and not
a header read either. The held release ladder stops at 18.0, older than the pair, so the release's own
metadata cannot settle it:

    $ xmake l tools/cache-index/first-rung.lua --self-test | grep "rung in the table"
    ok   every rung in the table is held (53 rungs)
    $ ls ~/.revenant/dyld | tail -1
    18.0

The rows' old `source` field read `SDK 26.5, Mac Catalyst, Foundation`, and both halves of it are wrong on
what is measurable here: there is no 26.5 SDK on this machine at all, and this package carries iOS
releases, so nothing here could read a Catalyst annotation even if a SDK had one.

What that costs the port:

- `NSPredicateValidating` names a protocol whose **required selector** is the whole contract. Writing it
  from the name would be inventing a method signature, which is the one thing a row must not do.
- `-[NSPredicate allowEvaluationWithValidator:error:]` returns something and takes an `NSError **`. The return
  is `BOOL` by the shape of the name and nothing here confirms it.

Both stay `absent`, and each row's effect says what a program sees: the protocol is not declared, so a class
cannot be said to conform to it and the compiler is told so; the method is not declared, so
`respondsToSelector:` answers NO and an unchecked call raises. **What would close them** is one SDK that
declares the pair. That is a fetch, not an implementation, and it is the whole of what these two rows owe.

This is not the row `NSAllowEvaluation.md` is about, which is the iOS 7 `-allowsEvaluation` of a securely
decoded predicate: there the port is the provider, `registry/Foundation/nz-accessors.json` reads
`implemented` with `maximum: "7.0"`, and that file carries the measurement. These two are the opposite
shape - no provider, no declaration, and no contract to write down.