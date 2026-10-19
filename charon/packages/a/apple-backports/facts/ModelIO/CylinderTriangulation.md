# The cylinder generator: the triangulation, and what the counts could not show

Command: `./tests/backports/host/modelio/run.sh`, then `grep ^tri` on `host/answers.txt` and
`port/answers.txt`. Every triangle is printed as three (ring, column) pairs, the ring being the
vertex s y level and the column its angle round the axis.

## WHAT THE TRIANGULATION SHOWS, AND NO COUNT COULD

At radial 3 vertical 1 the system emits 16 triangles and the port 18, and the counts said
only that. The printed list says something else:

    $ grep "^tri r3 v1" host/answers.txt | grep -oE "\([0-9]+," | sort | uniq -c
      24 (0,
      24 (2,

**the system has NO ring 1 at all.** Its rings are 0 and 2 only. The port has rings 0, 1 and 2 - it
inserts a ring per vertical segment, and the system does not.

That is the whole of the difference at this size, and it is structural rather than arithmetic: the
extra triangles are not a wider cap fan, they are an extra ring of quads running round the middle of the
tube that the system never builds. Every count taken before - the gap rule, the sweep, the two
sweeps, and the class decomposition - summed correctly while the wall and the caps traded places
underneath, which is why none of them could be turned into a rule.

## What the system s list looks like, in full

    tri r3 v1 t0  (0,2), (0,3), (0,0)
    tri r3 v1 t4  (0,3), (2,3), (2,0)
    tri r3 v1 t5  (0,0), (0,3), (2,0)
    tri r3 v1 t6  (0,0), (2,0), (2,2)
    tri r3 v1 t12 (2,2), (2,0), (2,3)

Two things are visible in it that a count could not give: triangles like `(0,3), (2,3), (2,3)
carry a repeated vertex, which is what the third class called atposition actually IS - the fan
closing on itself - and the rings run 0 to 2 with nothing between, so the tube is closed by caps over
two rings and no wall quads at all at vertical 1.

## The port s list, for the same case

    tri r3 v1 t0  (0,2), (1,2), (0,3)
    tri r3 v1 t1  (0,3), (1,2), (1,3)
    tri r3 v1 t6  (1,2), (2,2), (1,3)

Ring 1 is there, which is the extra structure.

## OWED, and not to be derived from counts again

The port cylinder must be rebuilt so its index list EQUALS the system s, element for element, at
these four sizes first and then widened. The reconstruction to read off the lists is: ring
order, whether a ring is inserted per vertical segment, the seam column, how a pole is closed, and
the winding of each fan.

**Not attempted here.** The four smallest cases are dumped and readable; matching them exactly needs
the whole ring layout, which is the next piece of work and not a counting exercise.

## The bounded attempt at the one-line semantic

The tube is handed two counts — `around` = the radial and `up` = the vertical — and the ring count was
built from the wrong one:

```
NSUInteger rings = up + 3;                       <- three rings of quads more than the caller asked for
float v = (float)ring / (float)(up + 1);         <- and v spanned the extra rings
```

changed to

```
NSUInteger rings = up + 1;
float v = (float)ring / (float)up;
```

**Result, whole-array comparison, not counts:**

```
r3 v1  host 16 triangles, port 18  IDENTICAL ARRAY: False    host rings [0,2]   port rings [0,1,2]
r4 v1  host 20 triangles, port 24  IDENTICAL ARRAY: False    host rings [0,2]   port rings [0,1,2]
r5 v1  host 24 triangles, port 30  IDENTICAL ARRAY: False    host rings [0,2]   port rings [0,1,2]
r3 v2  host 24 triangles, port 24  IDENTICAL ARRAY: False    host rings [0,2,3] port rings [0,2,3]
      first differing triangle, index 0:
        host ((0,2), (0,3), (0,0))
        port ((0,2), (2,2), (0,3))
```

**What it fixed:** at vertical 2 the ring SET now matches — `[0,2,3]` on both sides — where before the port
carried a ring the system did not. The ring count was the right thing to look at.

**What is still different, in two parts:**

1. **At vertical 1 the port still emits a middle ring.** The system builds rings 0 and 2 and nothing between
   them; the port builds 0, 1 and 2. With `rings = up + 1` and `up = 1` there should be two rows, so
   something else is still adding a y level — most likely the pole rows, which are emitted by the cap block
   and not by this loop.

2. **The first triangle already differs at r3 v2**, where the ring sets agree. The host opens with
   `(0,2), (0,3), (0,0)` — a fan INSIDE ring 0. The port opens with `(0,2), (2,2), (0,3)` — a quad
   SPANNING ring 0 to ring 2. So the order of the emission differs before any cap question arises: the
   system's ring-0 fan comes first and the port's wall quads come first.

**OWED, with the reads that settle it:** the ring layout is one of these two — a system with a middle ring
at vertical 1 that is not one of the rows this loop makes, or a pole row counted as a ring by my printer —
and the emission ORDER is different, not only the membership. Both are read off the four dumped lists in
the file above. Not attempted further in this turn: the time box is reached and this series has already spent
too many turns fitting a cylinder that has to be read.

## The emission order, and what is left after fixing it

The system s list at radial 3 vertical 1 reads, in order:

    t0  (0,2) (0,3) (0,0)     all three inside ring 0  - a fan, not a quad
    t1  (0,2) (0,0) (0,2)
    t2  (0,2) (0,2) (0,3)
    t3  (0,3) (0,3) (0,3)
    t4  (0,3) (2,3) (2,0)     spans ring 0 to ring 2  - the wall
    …
    t12 (2,2) (2,0) (2,3)     all three inside ring 2  - the other fan

**Bottom cap, then wall, then top cap.** The port emitted both caps after the wall, so its list opened with a
quad spanning rings 0 to 2 where the system s opens with a fan inside ring 0. The cap loop now emits the
BOTTOM cap before the wall loop and the TOP cap after it.

After that change the first triangle is a ring-0 fan on both sides for the first time, and the remaining
difference in it is one vertex:

    host ((0,2), (0,3), (0,0))
    port ((0,2), (0,3), (0,2))

The system s third vertex is column 0 - the seam - and the port s is column 2, the one it started from. So the
fan does not step column by column from where it began: it visits the ring and wraps to the SEAM COLUMN, which
at three segments is column 0 rather than column 3. That is a seam-column rule, and it is the next thing to
read off the list rather than fit.

**Still owed:** the seam column, and whether the port s extra middle ring at vertical 1 is a pole row the
cap block adds - the ring count itself now matches, at vertical 2, where the ring sets are [0,2,3] on both
sides.

## THE RING RULE, READ OFF THE VERTICES

The vertices themselves, grouped by their y level, with the column of each:

    verts r3 v2 count 22 levels 3
      level 0 y -2.0000 count 9  cols 3,0,2,3,3,0,2,3,2
      level 1 y  0.0000 count 4  cols 3,0,2,3
      level 2 y  2.0000 count 9  cols 3,0,2,3,3,0,2,3,2
    verts r4 v3 count 32 levels 4
      level 0 y -2.0000 count 11 cols 4,0,1,3,4,4,0,1,3,4,3
      level 1 y -0.6667 count 5  cols 4,0,1,3,4
      level 2 y  0.6667 count 5  cols 4,0,1,3,4
      level 3 y  2.0000 count 11 cols 4,0,1,3,4,4,0,1,3,4,3
    verts r3 v1 count 18 levels 2

Three facts fall out, and each is a rule rather than a fit:

* **The number of levels is `vertical + 1`.** v=1 gives two levels, v=2 gives three, v=3 gives four. At
  vertical 1 there is NO middle level, which is what the port gets wrong: it builds one.
* **A POLE LEVEL carries `2*around + 3` vertices, a MIDDLE level carries `around + 1`.** 2*3+3 = 9 and
  2*4+3 = 11 at the poles; 3+1 = 4 and 4+1 = 5 in the middle. Both are exact at both radials.
* **The pole columns REPEAT** - 3,0,2,3,3,0,2,3,2 - because the cap fan closes on itself, which is what
  the third class called atposition. The host does not avoid that; it builds it and the triangles come out
  degenerate, and the port must build the same vertices for the same indices.

The total follows: at r3 v2 it is 9 + 4 + 9 = 22, the host s count, and at r4 v3 it is 11 + 5 + 5 + 11 =
32, also the host s.

The port produced 14 and 22 at those sizes (measured). **Its layout across the levels has not been
read yet, and it is NOT `around + 1` at every one of a set of `vertical + 2` levels - that would give
16 and 25, not 14 and 22.** An earlier note here claimed that as the cause and it does not follow from
the numbers it was offered as evidence for; it is withdrawn. The port s counts are the measurement and
the port s arrangement behind them is open.

**OWED, and it is now a specification rather than a search:** rewrite the ring loop so that the levels are
`vertical + 1`, the first and last carry `2*around + 3` vertices and the rest carry `around + 1`, and the
cap fans run over the pole ring s own columns - which repeat - instead of over `around` columns. The emission
order from modelio-4 stands: bottom cap, wall, top cap.
