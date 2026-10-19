# The pathfinding graphs

`GKGraph` and everything built on it: **18 classes, 26 properties, 87 methods, 131 rows**, in two
objects -- the 9.0 classes (`GKGraph`, `GKGraphNode`, `GKGraphNode2D`, `GKGridGraph`,
`GKGridGraphNode`, `GKPath`, `GKObstacle`, `GKCircleObstacle`, `GKPolygonObstacle`, `GKObstacleGraph`)
and the 10.0 ones (`GKGraphNode3D`, `GKSphereObstacle`, `GKOctree`, `GKQuadtree`, `GKMeshGraph`,
`GKRTree`, and the 3D half of `GKPath`). Measured against the host's own GameplayKit by
`tests/backports/host/gameplaykit-graph/measure.m` and held to it by that directory's
`differential.m`: **152 checks, 0 failures**.

None of it needs the device. `GameplayKit.framework` carries no code at all before iOS 8, and iOS 6 has
none of the logic this is: every class here is a region of the plane, a search over it, and the shape of
an obstacle.

## The two objects, and why the split is where it is

An object carries the API of exactly one release (`modules/apple/backports.lua`'s `check_releases`,
read by `tools/release-split.lua`). `GameplayKitBase.h:26` defines `GK_BASE_AVAILABILITY` as
`NS_CLASS_AVAILABLE(10_11, 9_0)` and `:27` defines `GK_BASE_AVAILABILITY_2` as
`NS_CLASS_AVAILABLE(10_12, 10_0)`; `GKPath.h:22-23` and `:31-32` mark the 3D initialisers and the two 3D
accessors `API_AVAILABLE(ios(10.0))`. So the 9.0 classes are `GKGraph9.m` and `GKObstacleGraph9.m` --
two files because `relcheck` refused one: `GKObstacleGraph` is 9.0 while everything else in that file was
10.0.1, and one object cannot hold two releases. The 10.0 classes are `GKGraph10.m`, and the shared
arithmetic and the one search are `CharonGKGraph.m`, a file that exports **no** API symbol: that is the
trap `charon/AGENTS.md` names, and a file whose exports a band's release already has is left out of that
band, so the call is `Undefined symbols` in later bands only.

## What the host answers, where it is surprising

**A node's cost is the length of the line between its ends** and its estimate is the same number.
(0,0) to (3,4) is 5 for both. A node with no position of its own -- a plain `GKGraphNode` -- charges
**1** and estimates **0**; a `GKGridGraphNode` charges the distance between the two **cells**:
(0,0)->(1,1) is 1.41421354 and (2,3)->(1,1) is 2.23606801, both `sqrt(2)`-family values to the last bit a
float carries. The 3D node answers the 3D version: the origin and (1,2,2) are 3 apart.

**The edges are a list, not a set.** Adding the same edge twice lists it twice -- measured, adding n1 and
n2 and then the same two again answers four entries -- and `-removeConnectionsToNodes:` takes out
**every** copy of a node it is given and leaves the rest. The header says "a new connection is not
created if it already exists"; the host does not do that, and neither does the port.

**The search is A\*, and the open set is scanned rather than heaped.** A three-node chain answers four
nodes, a node asked for a path to itself answers itself alone, and a target that cannot be reached
answers an **empty array**, not nil. Two details are measured rather than chosen, and both are load
bearing:

- The ordering is `cost reached + cost estimated`, which is what `-estimatedCostToNode:` is for. Across
  a 3x2 grid from (2,3) to (4,4) the host answers (2,3) (3,3) (3,4) (4,4) -- the way that goes **up**
  before it goes right -- and not (2,3) (3,3) (4,3) (4,4), though the two are the same length. At (3,3)
  the cell above is one step from the goal and the cell to the right is two, so A*'s `f` picks the
  first; a plain Dijkstra ordering picks the second, and `differential.m` fails on exactly that.
- A remaining tie keeps the **later** node of the open set. Two nodes joined to a third and a fourth at
  (10,0), where the direct edge and the two-step way cost the same in total: the host answers the
  direct one.

**A graph answers a path to a node it does not hold**, because the edge out of the one it does hold
reaches it. `-copy` is a **deep** copy: the copy's nodes are different objects at the same positions,
and an edge of the copy names the copy's own node. `-addNodes:` does **not** filter: a graph built from
`@[a, a]` holds `a` twice, and adding a node it already holds answers three where there were two.
`-removeNodes:` strips the node from its neighbours' edges, so the ends of a removed node's path answer
no edges. `-connectNodeToLowestCostNode:bidirectional:` joins the node to the node of the graph whose
cost from it is lowest -- measured, with nodes at (5,0), (0,0) and (1,0) it joins (5,0) to **itself**,
twice when bidirectional is YES and once when it is NO, because (5,0) is nearest to (5,0). A node the
graph does not hold, and a graph with no nodes, leave it alone.

**The archives round trip, and what they carry.** A polygon of four points answers 342 bytes and comes
back with its four vertices in order. A two-node graph whose ends are joined answers 558 bytes and
decodes to two nodes at their positions **with the edge between them**, so the decoded graph is walkable.
The nodes go into the archive as objects rather than as class names, and that is what keeps the edges
naming the decoded nodes. A node class that overrides `-initWithCoder:` must declare
`+supportsSecureCoding`, or the archiver answers nil and the unarchiver `NSCocoaErrorDomain 4864` --
measured, with that exact explanation, before the declaration was added.

**The refusals are the host's own, spelling and all.** `-init` on `GKCircleObstacle` raises
`NSInternalInconsistencyException` with the reason `initWithRadius: is the destignated initialize for
GKCircleObstacle.  Use that instead`; on `GKPolygonObstacle` and `GKSphereObstacle` the same shape with
their own names. A path of fewer than two points raises
`GKPathLessThanTwoPointsException: GKPaths MUST be initialized with 2 or more points.  Single point
paths are not allowed`, and one of fewer than two nodes raises `GKPath: must be initialized with 2 or
more graph nodes.  Single node paths are not allowed`. An obstacle graph given a node class that is not
a `GKGraphNode2D` raises `initWithObstacles: nodeClass does not descend from GKGraphNode2D`.

**A cell size is a power of two, not the minimum.** The minimum cell size is a **floor** on the size:
the tree halves, so the size is the smallest power of two at or above the minimum, capped at the extent
of the box. Measured over eleven minimums against a box of extent 8:

| minimum | cells for 1.9, 5.5, 7.9, 3.3 | size |
| --- | --- | --- |
| 0.25 | 1.75-2, 5.5-5.75, 7.75-8, 3.25-3.5 | 0.25 |
| 0.5 | 1.5-2, 5.5-6, 7.5-8, 3-3.5 | 0.5 |
| 1 | 1-2, 5-6, 7-8, 3-4 | 1 |
| 1.5 | 0-2, 4-6, 6-8, 2-4 | 2 |
| 2 | 0-2, 4-6, 6-8, 2-4 | 2 |
| 3 | 0-4, 4-8, 4-8, 0-4 | 4 |
| 4 | 0-4, 4-8, 4-8, 0-4 | 4 |
| 5, 7, 16 | 0-8 for all four | 8 |

A minimum of **0 traps on the host** (SIGBUS, measured), so it is not a case this rule has to answer.

**A point element answers for its whole cell; a region element does not.** An element added with a
point at (1.9,1.9,1.9) in a tree of minimum cell size 2 is answered at (1.1,1.1,1.1) and not at
(2,0,0). An element added with a **box** is answered only where its **own box** holds the point: the box
(3,0,0)-(5,2,2) is answered at (4,1,1) and **not** at (5.5,1,1), and the two share a cell -- without that
second test a box element would answer the whole of every cell it touches. A box element is filed in
**every** cell it touches, one per cell, which is what makes a lookup find it wherever the box is; the
node the method hands back is the one of the box's low corner.

**An R-tree query answers what the rectangle WHOLLY holds.** With elements at (0,0)-(1,1) and (2,2)-(3,3):
a query over (0,0)-(1.5,1.5) answers the first alone, and a query over (0.5,0.5)-(3,3) answers the
second alone although the first overlaps it by half. That is `GKRTree.h:20`'s own words, and an
intersection test would answer both of those with both elements.

**A mesh graph's three modes are three sets of positions that do not overlap.** One 10x10 rectangle
answers 4 nodes in the vertex mode, 2 in the centre mode, 5 in the edge-midpoint mode and **11** with
all three set -- and 11 is 4+2+5. A rectangle with nothing in it is two triangles and four corners, in
the host's own order: (0,10), (10,0), (10,10), (0,0).

**The refusals the port reproduces and the ones it does not.** `-removeAllObstacles` takes every
obstacle and every node out; adding an obstacle re-scans, so a graph of one obstacle answers four nodes
and after a second is added answers **eight** -- four and four, not six, so the first obstacle's four are
the same four. An R-tree's `-queryReserve` is **1** on a fresh tree and after six additions, and
`-setQueryReserve:` changes nothing and the getter keeps answering 1; the port does not keep a value the
host would not read back.

## Three members where the host contradicts its own headers, and what the port does instead

These are measured, they are held by `contract(...)` checks rather than `host(...)`, and **none of the
host's answers is reproduced** -- each one carries no information about the thing it is asked about, which
is the silent fake `coordination/crutches.md` forbids.

1. **`-[GKGraphNode findPathFromNode:]` traps.** Every input raises SIGBUS inside GameplayKit, including a
   node asked for a path to itself and a node in no graph at all. There is no host answer to compare
   with, so the port implements what `GKGraphNode.h:55-56` says in one sentence: it is
   `-findPathToNode:` with this node as the goal.

2. **`-[GKQuadtreeNode quad]` answers the zero quad** for every node of every tree tried -- a quad added at
   (3,3)-(5,5), a point at (1.1,1.1), a node in a 2x2 tree and a node in an 8x8 one, all four answer
   0,0..0,0. A node that comes back with a region of zeros describes no region at all, so the port
   answers the cell the element was filed in, which is what `GKQuadtree.h:11-12` declares.

3. **`-elementsAtPoint:` for a region element answers the NODE, not the element's own extent.** I got this
   wrong first and the coordinator corrected it; the correction is right and the header says so.
   `GKQuadtree.h:61` calls it "all of the elements in the quadtree node this point would be placed in" and
   `:69` calls `-elementsInQuad:` the elements "that reside in quad tree nodes which intersect the given
   quad". The host does exactly that, and the rule is now derived and reproduced:

   * an element is filed in the NODE one level above the cell its LOW CORNER falls in -- node size is
     **twice** the cell size -- while a **point** element is filed in the CELL itself. Measured: a quad at
     (1,1) in a tree of minimum cell size 1 is answered from the node 0..2 and not from the cell 1..2; one
     at (5,5) from the node 4..8 and not from 0..4; one at (7,7), on the boundary, from 4..8. A point at
     (5.5,5.5,5.5) in a tree of minimum cell size 2 hands back a node of 4..6, which is the cell, while a
     box at (1,1,1)-(2,2,2) hands back a node of 0..4.
   * with one quad element at (1,1)-(2,2) in a tree of minimum cell size 1, `-elementsAtPoint:` answers at
     (1.5,1.5), **(0.5,0.5), (0,0)** and (1,1) -- three of those four are outside the quad's own extent --
     and at (2.5,2.5), (3,3), (1.5,3.5), (3.5,1.5), (6,6), (4,4), (7.9,0.1) and (2,2), which are not.
     `-elementsInQuad:` answers for (0,0)-(0.5,0.5), (0,0)-(4,4) and (1.2,1.2)-(1.8,1.8), and not for
     (3,3)-(4,4) or (2.5,0)-(4,1). Both are the node's answer.
   * **the two queries are not symmetric**: a POINT element is in `-elementsInQuad:`'s answer and in
     **nobody's** `-elementsAtPoint:` answer, at any point and any cell size -- measured, a point element at
     (1,1) answers nothing of a dense 256-point sweep. The octree's mirror image: `-elementsAtPoint:` there
     answers point elements and **never** a box element (measured over 256 points, every one inside the
     box, at cell sizes 1, 2 and 4: all empty), while `-elementsInBox:` answers a box element where the box
     meets the query -- its own extent, not the node it is filed in.
   * `-[GKQuadtreeNode quad]` still answers the zero quad for every node of every tree tried, and that one
     stays a caveat: the header says the node's quad is the one the element was added with
     (`GKQuadtree.h:11-12`), and zeros describe no region.

4. **An obstacle graph's node positions: a one-obstacle graph is all NaN, a two-obstacle graph is not.**
   This corrects what I told the coordinator, who had taken "all NaN" from my hand-over. The probe is
   `tests/backports/host/gameplaykit-graph/measure_obstacle.m`, it computes its own expectation from the
   values it prints, and it prints:

   ```
   one wall, buffer 0: 4 nodes, every position nan,nan
   one wall, buffer 1: 4 nodes, every position nan,nan
   one wall, buffer 2: 4 nodes, every position nan,nan
   two obstacles, buffer 1: 8 nodes, positions: nan,nan nan,nan nan,nan nan,nan nan,nan
                                       23.0001,-1.00009 23.0001,4.41435 nan,nan
   ```

   So a graph of **one** obstacle answers NaN for every node's `-position` at every buffer radius tried,
   and **two** of a two-obstacle graph's eight nodes carry positions -- the ones the far obstacle
   contributes, pushed out by the buffer. The **count** is well defined on the host throughout (one node per
   vertex: 4, then 8, not 6) and is reproduced. The positions are the port's own: the obstacle's vertices,
   pushed out by the buffer radius, which is `GKObstacleGraph.h:15`'s `GKGraphNode2D` and the region an
   agent may not walk into. A closed obstacle really does cut the graph: two nodes on either side of a
   square answer no common edge at all, while a node near it on one side is joined to the three corners it
   can see.

   Not probed there, because it crashes: `-connectNodeUsingObstacles:` with a node of the caller's own, on a
   graph whose nodes have already been walked, raises SIGSEGV inside GameplayKit. Measured three times.

## The harness fails when the code is wrong, proved three ways

`differential.m` is only worth reading if it can fail. Five mutations, each one line, each run against the
whole 152 checks:

| mutation | result |
| --- | --- |
| the search's tie rule `<=` -> `<` in `CharonGKGraph.m` | `FAIL host: m7 a path across the grid answers cells, start to end, both ends in it` -- `checks=149 failures=1` |
| the grid node's cost -> the constant 1 in `GKGraph9.m` | three `FAIL host:` lines, including both cost checks and the grid path -- `checks=149 failures=3` |
| an obstacle's visibility test -> always pass in `GKObstacleGraph9.m` | two `FAIL host:` lines on the cut -- `checks=149 failures=2` |
| an entry's `-charon_holdsPoint:` -> always YES in `CharonGKGraph.m` | `FAIL contract:` on the box element's own region -- `checks=149 failures=1` |

The first version of that last check did **not** fail on the third mutation, and the reason is worth
recording: it asked a question the cell already answered. A point outside the box but sharing its cell is
the only question the region's own bounds answer, so that is what the check asks now.

## What is not here

`GKNoise` and `GKNoiseMap` (39 rows) are **not** in this delivery: `GKNoise.h` imports
`<SpriteKit/SpriteKitBase.h>` for its gradient members, so the evaluation half of the noise family waits
for SpriteKit, and `facts/GameplayKit/Noise.md` already records that the description half is landed. The
two node components that wrap a scene node (`GKSKNodeComponent`, `GKSCNNodeComponent`, 8 rows) wait for
those frameworks too.