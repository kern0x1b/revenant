# UITableView estimated heights, iOS 7

Introduced in iOS 7.0: `estimatedRowHeight`, `estimatedSectionHeaderHeight` and `estimatedSectionFooterHeight`, the heights a table assumes for what it has not
measured yet, so that it need not ask its delegate for every row before it shows the first.

Source: the host's own UIKit under Mac Catalyst (`host/tableestimates/run.sh`): the defaults of the three (automatic, -1, on a plain and on a grouped table), the value
that is kept, a zero and the automatic value, the refusal of any other negative value with `NSInternalInconsistencyException` and its words for each of the three, and setting the
row estimate by key-value coding and reading it back. `device/tableestimates.m` holds iOS 6 to them.

The release of iOS 6 has none of the three: its table asks the delegate for the height of every row and of every header and footer when it loads and lays them out from
the answers. The port keeps the three values (default automatic), refuses as the host does, and the table is laid out as it was; an estimate has nothing to do
where every height is known. An application that sets the row estimate and answers no height for its rows (self-sizing rows, `rowHeight` automatic) gets the release's
row height, which is 44 unless it says otherwise - the port does not measure the cells of a table.

The three are `inert`. An application that sets the estimate through key-value coding - a storyboard does - no longer stops at `setValue:forUndefinedKey:`.
