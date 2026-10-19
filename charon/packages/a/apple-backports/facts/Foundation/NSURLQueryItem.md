# NSURLQueryItem, iOS 8

Source: the host's own Foundation, asked six items and seven comparisons and held against the backport by the
`queryItem.*` records of `tests/backports/host/foundation2/run.sh`; and iOS 6.0 and 6.1.3 on the emulator, an iPad 2 and
an iPhone 4S, through `tests/backports/device/foundation2.m`. How `NSURLComponents` reads and writes its query with the
items is in `NSURLComponents.md`.

An item is a name and an optional value, both kept as copies: a name made from a mutable string that is changed
afterwards still reads what it was made from. `-init` makes an item with an empty name and no value, and a nil name is
an empty name, not a missing one, in `-initWithName:value:` as in the class method. A value of nil and a value of the
empty string are different: `k` with no value is not equal to `k` with an empty value, and the two describe themselves
differently.

Two items are equal when their names are and their values are, with a missing value equal to a missing value only.
An item is not equal to nil or to a string, its copy is equal to it, and equal items have equal hashes; the seven-item
matrix of the record has no pair that is equal with different hashes. A set of `k=v`, another `k=v` and `k` with no value holds
two.

`-description` is `<class address> {name = k, value = v}`, with `(null)` for a missing value. The class the host names
in it is its own, and the port names its own, so the record holds what follows the address.

The class supports secure coding and is archived by two keys, `NS.name` and `NS.value`; an item, with or without a value,
is read back by `+unarchivedObjectOfClass:fromData:error:` equal to itself, with the same name and value, including
names and values that are not ASCII.

`-copy` answers an object equal to the item, and the port makes a new one where a class of no mutable variant could answer
itself, since that is what the host does.
