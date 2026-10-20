# NSTextContainer.exclusionPaths, iOS 7

Introduced in iOS 7.0: the paths - in the container's coordinates - that the text of a container flows round.

Source: the host's own UIKit under Mac Catalyst (`host/exclusion/run.sh`): one text of 171 characters in Courier 14 in a container 200 by 400,
laid out plainly and beside a rectangle at the top right, at the top left, in the middle (the text splits into a left and a right fragment
on one line), an oval, a triangle, two rectangles, a band across the whole width (the lines move below it), a rectangle wider than the
container, a gap of five points that no glyph fits (the lines move below the rectangle) and a rectangle below the text - each recorded as
every line fragment's glyph range, rectangle and used rectangle. `device/exclusion.m` builds the same layouts on iOS 6 and compares the glyph
ranges exactly and the rectangles to two points.

## How the port does it

The release's typesetter asks the container for the rectangle of a line by its Mac-era method, with a proposed rectangle, a sweep direction
and a direction to move in, and lays a line into the rectangle it gets and into the remaining one after it. The port lets the release clip the
proposed rectangle to the container, then takes from it what the paths cover in the strip of the line: each path is flattened (curves in
sixteen steps) and its horizontal extent found at the top and bottom of the strip, at every vertex of the path inside it and between
them, so a curve or a slant that widens through the strip is counted at its widest; the rest of the strip is the free part. The first free segment in the
sweep direction that is at least two paddings wide is the fragment, the rest of the strip to the far edge is the remaining rectangle, and a strip with
no such segment is moved down to the lower edge of the next path, until the container is full. A container with no exclusion paths is answered
by the release unchanged.

## What differs

The extent is the widest the path is in the strip, so a slanted or curved edge leaves the strip narrower than the rows of glyphs that
would fit under the curve's upper part; the host does the same to within a point. A segment narrower than two paddings and one point is
skipped; wider ones are offered to the typesetter, which skips those no glyph fits. The two releases' fonts differ by about a tenth of
a point in width, so the rectangles agree to two points and the glyph ranges exactly.
