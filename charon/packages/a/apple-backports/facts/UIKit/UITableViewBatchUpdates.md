# The batch updates of a table view, iOS 11.0

Introduced in iOS 11.0: one call that groups a table's insertions, deletions,
moves and reloads and tells the caller when the animation is done.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`-[UITableView performBatchUpdates:completion:]` at `0x18a2cc288`, which passes
the two blocks to `-_performBatchUpdates:withContext:completion:` at
`0x18a1b6768`) and the differential test against the host's UIKit
(`tests/backports/host/batchupdates`).

## Behaviour

The update block runs **synchronously**, inside the call, and the completion
runs later, once the table's animation has finished — after the run loop has
turned, never inside the call. The whole group behaves as one update: the table
ends with the rows the group leaves it, and one call brings exactly one
completion.

A `nil` update block and a `nil` completion are both accepted without
complaint, and so is an empty block. A call nested inside another update block
works: the inner block runs where it stands, and the rows of both land
together.

The port wraps iOS 6's own `-beginUpdates` and `-endUpdates`, which have grouped
a table's changes since iOS 2, in a Core Animation transaction whose completion
block carries the caller's completion.

## When the completion comes on iOS 6

On an iPhone 4S running 6.1.3, a transaction's completion block does not run
when that transaction commits. It runs when the **outermost** transaction
commits, and in an application that is the implicit transaction of the current
turn of the run loop, committed once the code that is running returns.

So when `-performBatchUpdates:completion:` is called from an event, a timer or
a queued block, the completion comes on the following turn, after the call has
returned - the order Apple gives: `before`, `inside`, `after the call`,
`completion`.

The one case where the two differ is code that turns the run loop itself
without returning, with `-runUntilDate:` inside the same handler. There the
completion waits until the handler returns, while on the host it arrives inside
that nested turn.

Measured on the device with the table outside any window and inside a window,
and with an empty transaction beside it: all three completions came together,
1.5 and 3.1 seconds after the calls, once the handler had returned. None came
inside a nested turn. The completion of a `UIView` animation on the same
release does come inside a nested turn, which is why this is a property of
Core Animation transactions and not of tables.

The device test calls the method from inside a handler and checks the order
only after that handler has returned. It expects `before | inside | after the
call | completion finished 1`.

## The one thing the port cannot tell

Apple's completion receives whether the animation actually finished, and answers
`NO` when it was cut short — a table outside a window, for instance, reports
`NO` in the host test. A Core Animation transaction does not hand that back, so
the port always reports `YES`. Everything else about the completion — that it
runs, that it runs once, and that it runs after the animation rather than inside
the call — matches.
