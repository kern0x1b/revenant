# The host measurements, and how to re-take them

Four programs, each one printing what the host's own class and its two `NSBundle` additions answer.
Every fact in `facts/Foundation/NSBundleResourceRequest.md` that is *measured* comes from one of them,
and the commands are below. They are kept with the test rather than in `.agent-work` because they are
what the test rests on and `.agent-work` is not part of any branch.

```sh
# every binary goes under the worktree, beside the run.sh's own build directory: band output never
# goes to /tmp
runs=$PWD/.agent-work/runs/host-measurements
mkdir -p "$runs"

# the class: its superclass, conformances, and which of the eleven members answers
xcrun clang -fobjc-arc -Wno-unguarded-availability -o $runs/host-methods \
    tests/backports/host/bundlerequest/measure/host-methods.m -framework Foundation && $runs/host-methods

# -init's refusal, -initWithTag:'s answer, and the two additions' behaviour on a bundle with and
# without a manifest
xcrun clang -fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability -o $runs/host-init \
    tests/backports/host/bundlerequest/measure/host-init.m -framework Foundation && $runs/host-init

# the manifest: a bundle written on the spot with such a plist in it, read back through the release's
# own -[NSBundle pathForResource:ofType:], and the two constants by dlsym
xcrun clang -fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability -include dlfcn.h \
    -o $runs/host-plist tests/backports/host/bundlerequest/measure/host-plist.m -framework Foundation && $runs/host-plist

# the step-by-step facts: the eight properties, the two initialisers, the four properties under the
# manifest's rules, the two additions per language, and the pronoun-shaped corners
xcrun clang -fobjc-arc -Wno-deprecated-declarations -Wno-unguarded-availability -o $runs/host-facts \
    tests/backports/host/bundlerequest/measure/host-facts.m -framework Foundation
for step in 0 1 2 3 4; do $runs/host-facts $step; done
```

Two things no program here can print, and the facts file says so where it uses them:

- the values of `NSBundleResourceRequestLoadingPriorityUrgent` and of
  `NSBundleResourceRequestLowDiskSpaceNotification`: both are `API_UNAVAILABLE(macos)` and the macOS
  framework emits neither, so there is nothing on the host to read;
- the two plist key names: `NSBundleResourceRequestTags` and `NSBundleResourceRequestPath` are in no
  Foundation header on this machine, in the 16.4 SDK or the 26.2 one.
