# ModelIO: what is owed, with the measurement that shows it

Every number here was measured by `tests/backports/host/modelio/run.sh` on both sides over byte-identical
inputs. The run states how many differences it expects to still be open, so a green-looking run cannot be
mistaken for a closed one.

## The cylinder generator — indices, not vertices

Five parameter points, the last one held out from the derivation:

| radial | vertical | host vertices | port vertices | host indices | port indices |
| --- | --- | --- | --- | --- | --- |
| 8 | 1 | 38 | 38 | 108 | 144 |
| 8 | 2 | 47 | 47 | 162 | 192 |
| 8 | 3 | 56 | 56 | 216 | 240 |
| 12 | 2 | 67 | 67 | 234 | 288 |
| 5 | 4 | 44 | 44 | 180 | 180 |

**Vertices agree at every point, including the held-out one.** Only the index count differs, and the excess is
exactly

    gap = 2 * (radial - vertical - 1)   triangles

which fits the four derived points and **predicts the held-out point as 0, which is what was measured**.

**The rule is not written**, and the reason is recorded so the next attempt does not repeat it. Subtracting
`2 * max(3, radial)` triangles for the two caps and fitting what is left gives `18v + 2`, which fits the three
`radial = 8` points and fails at `(12, 2)` and `(5, 4)`. So the system's cylinder is **not** this wall plus
two caps of the same kind, and the subtraction premise is false. The host's triangle counts — 36, 54, 72, 78,
60 — are not linear in either variable.

**How to finish it, exactly:** dump the index buffer and each vertex's *y*, then classify each triangle by
whether its three vertices share a `y`: one distinct value is a cap triangle, two is a wall one. That is a
counting of the host's own bytes and needs no arithmetic assumption. It is not done here.

## The generator share rows — the same family

```
  share cylinder r3 v3  vertices agree  host indices  96  port indices  90
  share cylinder r4 v2  vertices agree  host indices  90  port indices  96
  share cylinder r6 v2  vertices agree  host indices 126  port indices 144
  share cylinder r8 v2  host indices 192  port indices 162
  share cylinder r12 v2 host indices 288  port indices 234
```

Vertices agree throughout; the indices differ in **both directions** — 96 against 90 and 90 against 96 — so this
is not one missing fan but a different partition between the wall and the caps.

## A binary USD reader — owed, not a divergence

The system answers `+[MDLAsset canImportFileExtension:]` **1 for every extension except `mdl`**:

```
  obj 1   ply 1   usda 1   usd 1   usdc 1   usdz 1   abc 1   mdl 0
```

so the method describes **Apple's ModelIO**, not what any one reader supports. The port answers from the
readers it has — `obj`, `ply`, `usda` — which is what its own comment says it is for, and the differential
counts that as one difference on `canImport`.

**Scope:** `usd`, `usdc`, `usdz`, read through the extension switch beside `obj`, `ply` and `usda` in
`MDLAsset9.m`. `abc` (Alembic) is answered by the system and is **not** in scope here. Closed when a reader
exists and `canImportFileExtension:` answers those three **from it**, under a differential of its own, not
by adding names to a list.

## The voxel families and the mesh bounds — owed, numbers recorded

```
  mesh min 0.00000 0.00000 0.00000  max -1.00000 -1.00000 -1.00000
  mesh attributes 31
  voxel extent 0 0 0 to 1 1 0
  voxel indices 32 a3bb2e35
  voxels after union 3        voxels after difference 2
  voxrule 1 voxels            voxrule 2 voxels
  voxrule 3 voxels            voxrule 4 voxels
```

Not diagnosed. `voxel indices 32 a3bb2e35` carries what looks like a **checksum**, which points at
determinism rather than at shape; the eight `voxrule N voxels` rows are the same shape of difference four
times over. The mesh bounds report a maximum of **-1** where the minimum is 0, which is a single inverted
comparison worth looking at first.

## The PLY comment rule — owed, and deliberately not encoded

`tri-comment.ply` carries a `#` line inside the face element's data. The system reads it as a point cloud
(12 indices, geometry 0) where the file plainly holds two triangles. Four variants of the same bytes:

| fixture | comment position | system answers |
| --- | --- | --- |
| `tri.ply` | none | 6 indices, geometry 2 — triangle |
| variant A | before the first face | 3 indices — **a face dropped, silently** |
| variant B | between two faces | 6 indices — ignored |
| variant C | in the **header** | 12 indices, geometry 0 — point cloud |

It is **position-dependent, not comment-dependent**, and variant A loses a face without saying so, so no rule
is encoded: copying that would make the port drop faces silently. `tri.ply` is written comment-free so both
sides measure the same file, and the divergence keeps its own fixture.

## Malformed input: the system LOGS AND LOADS, and so does the port

A polygon file whose `faceVertexIndices` name a vertex the points do not have. What the system does, with the
command that produced it - `tests/backports/host/modelio/throw.m`, which wraps `initWithURL:` in `@try`/`@catch`
and prints the outcome either way, because a log line alone cannot tell a raised error from a quiet load:

```
$ ./throw bad.usda            # faceVertexIndices = [0, 1, 99] over three points
    Bad: face vertex index out of bound.
    bad.usda LOADED meshes=1
```

**It logs, and it LOADS.** No exception, the asset is not nil, and the mesh comes back with no submeshes,
because the faces after the bad one were never built.

**This section previously said the opposite** - that the host raises `NSInvalidArgumentException`,
terminates the process, and that the port should therefore do the same. That was wrong, and what it was read
off was a probe of ours:

```
$ ./inspect bad.usda           # prints mesh.vertexCount and mesh.submeshes.firstObject
    Bad: face vertex index out of bound.
    bad.usda THREW NSInvalidArgumentException: -[MDLObject submeshes]: unrecognized selector
```

`submeshes` was nil because the system had **already returned an empty mesh**, and our probe dereferenced it.
The system never raised; our probe raised about the system. Both the "terminates" claim and the
"unexercised end to end" claim that followed from it are withdrawn: the case is exercised end to end, by
`tests/backports/host/modelio/refusal.sh`.

The port's behaviour matches, and there is a test with a red control:

```
$ ./refusal.sh
    Bad: face vertex index out of bound.
    refusal: the port logs the bad index by name and loads the asset, as the system does
    exit 0
$ # with the port's refusal message removed
    FAIL  the port did not report the bad index by name      exit 1
```

The red control removes only the message and the test fails naming what it expected, so the test is about the
refusal and not about the file compiling. **Nothing about raising is owed.** Parity is reached by logging and
loading, which is what both now do.

This was the second time in this file that a "measured" claim turned out to be a fact about the instrument
rather than about the subject; the first was `MDLMeshBufferMap` reported as absent from the SDK, when a quoted
`grep` had simply not matched it. Both were caught the same way - by running the measurement again and reading
what it printed rather than what it was assumed to print.
