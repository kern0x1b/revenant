# The Metal error domains: MTLCommandBufferErrorDomain, MTLLibraryErrorDomain, MTLIOErrorDomain

The SDK declares three Metal error domains as `NSErrorDomain` constants and never spells their strings. The port
defines them in `Metal/MTLErrorDomains8.m` (the first two, which arrived with iOS 8) and `Metal/MTLIOErrorDomain16.m`
(the third, with iOS 16).

## The values, measured

`tests/backports/host/error-domains/run.sh` opens Apple's Metal by path and reads each constant with `dlsym`, then
compares the port's value byte for byte:

| constant | value |
| --- | --- |
| `MTLCommandBufferErrorDomain` | `"MTLCommandBufferErrorDomain"` |
| `MTLLibraryErrorDomain` | `"MTLLibraryErrorDomain"` |
| `MTLIOErrorDomain` | `"MTLIOError"` (not `"MTLIOErrorDomain"`) |

A planted name is not in Apple's Metal, so the lookup can say a symbol is absent. A mutant that adds a suffix to the
library domain turns that comparison red.

## What the constants do here

A caller compares an `NSError`'s domain with one of these strings. No error this port raises carries any of the three
domains: the port's own errors carry the domain of the class that raises them, so a caller that switches on
`MTLCommandBufferErrorDomain` never matches one. The constants answer what Apple's do, and nothing in the port depends
on them.
