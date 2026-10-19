# NSExpression conditional, iOS 9

Source: the host's own Foundation, asked one conditional expression seventeen questions and held against the
backport by the `expression.conditional` record of `tests/backports/host/foundation2/run.sh`; and iOS 6.0 and 6.1.3
on the emulator, an iPhone 4S and an iPad 2, through `tests/backports/device/foundation2.m`.

`+expressionForConditional:trueExpression:falseExpression:` makes the expression the format syntax spells
`TERNARY(predicate, true, false)`. The one made from `value > 10`, the constant `"big"` and the key path `name` is of
expression type 20, describes itself as `TERNARY(value > 10, "big", name)`, answers `value > 10` for its predicate
and `"big"` and `name` for its two branches, and evaluates to `big` for `value` 20 and to the name for `value` 5. It is equal to the
expression the format string `TERNARY(value > 10, 'big', name)` parses to, equal to its own copy, survives a keyed
archive and unarchive equal to itself, and works inside a predicate: `%@ == 'big'` evaluates true for 11 and false for
a value of 1 with the name `small`, and a variable substituted into a predicate that holds one is evaluated after the
substitution.

The release already has the expression type and the format syntax under another name, its ternary, and the class
method is that method under the name the newest release gave it; nothing else is added.
