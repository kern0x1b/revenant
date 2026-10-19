# The scratch files this band's facts used to cite, and what happened to each

A fact that cites a file only one worktree has cannot be read by a reviewer. Every `.agent-work`
path my four packages' facts named, and what is done with it — the substance moves into the tree, or
the citation becomes provenance.

| the scratch path | what it was | what it is now |
| --- | --- | --- |
| `.agent-work/host/classify.py` | the row classifier behind `Unplaced.md`'s buckets | **moved into the tree, then deleted** |
| `.agent-work/host/probe-appintents-equality.swift` | the equality call site that placed `IntentParameter`'s and `IntentPerson`'s `==` rows | **moved**: `packages/a/appintents/tests/probe-appintents-equality.swift` |
| `.agent-work/host/probe-intentperson-coding.swift` | the coding call site that placed `IntentPerson`'s four rows | **moved**: `packages/a/appintents/tests/probe-intentperson-coding.swift` |
| `.agent-work/host/probe-comparators.swift` | the comparator call site behind `Comparators.md` | **moved**: `packages/a/appintents/tests/probe-comparators.swift` |
| `.agent-work/host/probe-intembuilder.swift` | the call site for `IntentItem.Builder`'s four rows | **moved**: `packages/a/appintents/tests/probe-intembuilder.swift` |
| `.agent-work/host/probe-itembuilder.swift` | the call site for `IntentItemSection.Builder`'s three rows | **moved**: `packages/a/appintents/tests/probe-itembuilder.swift` |
| `.agent-work/host/invented-names.py` | the name census | **moved, then deleted** |
| `.agent-work/host/apple-tipkit.txt` | Apple's twelve answers in the TipKit differential | **provenance**: *measured 2026-09-28; output not kept* — the result (37 of 37) is in `facts/TipKit/Rendering.md` |
| `.agent-work/host/tipkit-diff.txt` | the diff of that run | **provenance**: *not kept*; same result, same place |
| `.agent-work/host/README.md` | the host-differential writeup, four modules | **provenance**: *not kept*; each module's results are in its own facts |
| `.agent-work/runs/kits/AppIntents-missing.tsv` | the missing-rows list behind the counts | **provenance**: *regenerated* from the corpus ledger and a digester dump of the built module; the count is what the facts carry |
| `.agent-work/runs/kits/WidgetKit-missing.tsv` | the same, for WidgetKit | **provenance**: *regenerated*; the count is in `facts/WidgetKit/Providers.md` |
| `.agent-work/runs/kits/ActivityKit-missing.tsv` | the same, for ActivityKit | **provenance**: *regenerated*; the count is in `facts/ActivityKit/Unplaced.md` |
| `.agent-work/runs/appintents-build.sh` | the device compile | **provenance**: the compile is this package's own recipe, `xmake.lua:95-180`; the script is not kept |
| `.agent-work/kits/` | the extracted 26.2 interfaces | **superseded**: the deleted `invented-names.py` read the machine's own `charon@iphoneos-sdk` 26.2 install |
| `.agent-work/worktrees/verify-r5` | the fresh checkout the counts were re-recorded in | **provenance**: *used once on 2026-09-28; not kept* |
| `.agent-work/runs/packages/emulate/build/configure.log` | an emulator run's log | **provenance**: *not kept*; the emulator run has no verdict |

**The rule for anything that is only a log or an output**: the facts carry the *number* and the date
it was measured, and the file is named as provenance. A reviewer can re-measure from the tracked
script; a reviewer cannot read a log that is not in the tree, and nothing in these facts asks them to.
