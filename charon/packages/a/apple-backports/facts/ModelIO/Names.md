# The ModelIO names and counts the differential measures

## The PLY comment divergence, measured rather than encoded

`tri-comment.ply` is the same bytes as `tri.ply` with one `#` line put back **inside the face element's
data**. The system reads it as a point cloud — **12 indices, geometry 0** — where the file plainly declares
`element face 2` with `3 0 1 2` and `3 0 2 3`, which is two triangles: 6 indices, geometry 2. The port
reads the two triangles, which is the correct reading of a comment-free file.

Four variants of the same bytes, all measured with the host:

| fixture | comment position | host answers |
| --- | --- | --- |
| `tri.ply` | none | **6 indices, geometry 2** (triangle) |
| variant A | before the first face | **3 indices, geometry 2** — a face is **dropped silently** |
| variant B | between two faces | **6 indices, geometry 2** — ignored |
| variant C | in the **header** | **12 indices, geometry 0** (point cloud) |

The behaviour is **position-dependent, not comment-dependent**, and no single consistent rule fits: variant A
loses a face without saying so, which is not behaviour to copy into a port. So:

- `tri.ply` is written **comment-free**, so both sides measure the same file and agree;
- `tri-comment.ply` is a **separate fixture** that keeps the comment, and the divergence is recorded here;
- **the port encodes no comment rule.** The row for the comment fixture's point-cloud reading is owed, not
  absent, and is counted in the differential's tally rather than designed away.

Parity policy applies: the host is the truth about *what Apple does*, but an accident is not encoded
silently. Variant A is the reason — copying the host here would make the port silently drop faces.
