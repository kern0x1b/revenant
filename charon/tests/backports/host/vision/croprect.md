# The crop-rect table: where Core ML puts a picture, measured.
#
# `.agent-work/runs/crop-probe/croprect.m` writes this. A picture black except one white *column* and
# another with one white *row*, each brought to a target of a different aspect under Core ML's own
# `CenterCrop` and `ScaleFit`; the response is read across a row and down a column. The last two
# columns are the centre of the lit run, which is where the impulse landed, and the fifth is
# where the port's own rule puts it: `inset + source * scale`.
#
#
# `nothing lit` means the impulse was **cropped away**: it sat outside the crop, which at a
# negative inset is where the rule puts the picture's own edge, so nothing of it reaches the
# target. It is the expected outcome and it says nothing about the crop's start -- it is not a
# black frame, and it is not a measurement of anything.
#
# The rule has to explain every row before anything in the library changes.

| case | rule | scale | drawn | inset x, y | source column, row | across a row | down a column |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 100 x 50 to 224 x 224 | centre crop | 4.48 | 448 x 224 | -112, 0 | 224 || 112 to 120 | 116 || 105 to 113 | 109 |
| 50 x 100 to 224 x 224 | centre crop | 4.48 | 224 x 448 | 0, -112 | 112 || 110 to 118 | 114 || 103 to 111 | 107 |
| 16 x 8 to 32 x 8 | centre crop | 2 | 32 x 16 | 0, -4 | 16 || 15 to 18 | 16 || 1 to 4 | 2 |
| 10 x 10 to 30 x 20 | centre crop | 3 | 30 x 30 | 0, -5 | 15 || 14 to 18 | 16 || 1 to 7 | 4 |
| 20 x 10 to 20 x 20 | centre crop | 2 | 40 x 20 | -10, 0 | 20 || 9 to 12 | 10 || 7 to 10 | 8 |
| 100 x 50 to 224 x 224 | scale fit | 2.24 | 224 x 112 | 0, 56 | 112 || 111 to 114 | 112 || 109 to 112 | 110 |
| 50 x 100 to 224 x 224 | scale fit | 2.24 | 112 x 224 | 56, 0 | 56 || 111 to 114 | 112 || 109 to 112 | 110 |
| 16 x 8 to 32 x 8 | scale fit | 1 | 16 x 8 | 8, 0 | 8 || 16 to 16 | 16 || 3 to 3 | 3 |
| 10 x 10 to 30 x 20 | scale fit | 2 | 20 x 20 | 5, 0 | 10 || 14 to 17 | 15 || 7 to 10 | 8 |
| 10 x 10 to 30 x 20 | scale fit, height exact | 2 | 20 x 20 | 5, 0 | 10 || 14 to 17 | 15 || 7 to 10 | 8 |
| 5 x 10 to 30 x 20 | scale fit, height exact | 2 | 10 x 20 | 10, 0 | 4 || 13 to 16 | 14 || 7 to 10 | 8 |
| 10 x 20 to 30 x 10 | scale fit, width exact | 0.5 | 5 x 10 | 12, 0 | 2 || 14 to 15 | 14 || 4 to 4 | 4 |
