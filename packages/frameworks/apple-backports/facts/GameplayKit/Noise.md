# The noise sources

`GKNoiseSource` and the nine concrete sources under it: **10 classes, 14 properties, 24 rows**, all
10.0, so one object file (`GKNoiseSource.m`). Measured against the host's own GameplayKit by
`tests/backports/host/gameplaykit-noise/measure.m` and held to it by that directory's
`differential.m`.

## A source is a description, and this is all of the family without SpriteKit

`GKNoiseSource` itself declares **no member at all**, and `-valueAtPosition:` is on `GKNoise`, not on
a source. Evaluating a source is `GKNoise`'s job, and `GKNoise.h` imports `<SpriteKit/SpriteKitBase.h>`
for its gradient members — so `GKNoise` and `GKNoiseMap` (37 more rows) wait for SpriteKit, exactly as
the corpus recorded when it deferred `SKColor textureWithNoiseMap:` as `absent`. This is the half that
does not need that header, and it is a whole family on its own.

## What the host does, and what the port answers

Each factory hands back **the class it names** with the numbers it was given — measured: the perlin,
billow, ridged, voronoi, constant, checkerboard, cylinders and spheres factories each return their own
class, not a shared one. Every property hands its number back, and a property set after the fact is
read back: the host's perlin source answers `freq=1.5 octaves=3 persistence=0.25 lacunarity=2.5 seed=11`
and then, after all five are set, `freq=4 octaves=5 persistence=0.75 lacunarity=3 seed=-3`, a negative
seed included. **Nothing validates a value** — a frequency of 0, an octave count of 0 and a seed of 0
are all kept as given, measured. The base instance is a `GKNoiseSource` and answers neither `-frequency`
nor `-value`.

## The hierarchy

All nine concrete sources answer as their headers declare: measured, perlin, billow and ridged are
`GKCoherentNoiseSource`, and voronoi, constant, cylinders, spheres and checkerboard are
`GKNoiseSource`. A base instance is a `GKNoiseSource` and answers neither `-frequency` nor `-value`.

**A correction to what I told the coordinator two turns ago.** I reported that a
`GKBillowNoiseSource` is *not* a `GKCoherentNoiseSource` on the host, with a measured `0`. The
measurement was wrong: it came from one `printf` whose arguments were evaluated in an order that
paired the wrong call with the wrong value, and re-measured with one call per line the host answers
`billow-coherent=1`. There is no divergence here, and none is registered as one.

## Where the five numbers live, and why it is not one line

`GKNoiseSource.h` declares the properties in three places:

```
GKCoherentNoiseSource:  frequency, octaveCount, lacunarity, seed     lines 37-40
GKBillowNoiseSource:    persistence                                  line 49
GKPerlinNoiseSource:    persistence                                  line 61
```

`persistence` is declared on **the two subclasses**, and not on the coherent class at all. A property
declared in a class is autosynthesised in that class, so both subclasses want an ivar of their own;
the name they want is the one `GKCoherentNoiseSource` already holds, and clang refuses — the errors are
*"property 'persistence' attempting to use instance variable '_persistence' declared in super class"*.

So all five numbers are stored in `GKCoherentNoiseSource` with the **ten real accessors written there,
once**, and each of `GKPerlinNoiseSource` and `GKBillowNoiseSource` — the two that declare the
property — implements `-persistence` and `-setPersistence:` over the same storage, by asking `super`.
That is the whole of it, and every accessor is a real one over a real ivar. The two alternatives were
tried and are recorded in `.agent-work/plan-and-analysis/api-games/noise/NOTES.md`:

- **`@synthesize persistence = _persistence;` in the two subclasses** — cannot work: `@synthesize`
  never binds to a superclass's ivar, whether private or protected. The visibility could be fixed; the
  binding cannot.
- **A dynamic property marker** — ruled out: the fleet's verifier reads it as evidence that nothing
  implements the property, and the verifier is right to: there would be nothing at this level.

The one thing that would have been wrong, and is not, is leaving the accessors to clang and letting it
synthesise a second set per subclass: that is how this family started, and it is why the header's own
line numbers are quoted above.

## What is not here

`GKNoise` and `GKNoiseMap`, 37 rows, waiting for SpriteKit. `GKNoise` needs `SKColor` for its
`gradientColors:` and `+noiseWithComponentNoises:selectionNoise:` methods, and `GKNoiseMap` takes a
`GKNoise` to sample. Neither is registered `absent` here, because the registry describes what this
series builds and neither is in it; they are in the corpus ledger as missing, and the next series on
top of SpriteKit takes them.
