# `__NSArray0__` and `__NSDictionary0__`, iOS 9

Source: the host's own CoreFoundation, asked through `dlsym` for both symbols, and Foundation of iOS 6.0 and 6.1.3
through `tests/backports/device/foundation2.m`.

## What the symbols are

CoreFoundation of iOS 9 exports two pointer variables, `__NSArray0__` and `__NSDictionary0__`. Each holds the one
immutable empty array or dictionary of the process, an instance of the private classes `__NSArray0` and
`__NSDictionary0`. On the host the pointer is the very object `+[NSArray array]`, `+[NSDictionary dictionary]` and
the literals `@[]` and `@{}` answer. Applications built for iOS 9 and later import them to hand out or to compare
against the empty collection.

## What iOS 6 does

The release already keeps one empty immutable array and one empty immutable dictionary: `+array`, `+new`,
`-[[NSArray alloc] init]` and the copy of an empty mutable array all answer the same object, and so do the
dictionary's constructors. Its class is `__NSArrayI` and `__NSDictionaryI`, not the private `__NSArray0` and
`__NSDictionary0` of the newer releases, so `[emptyArray class]` names another class. What the release does not have
is the two variables.

## What the backport does

The variables are there and hold that very object, taken with `+[NSArray array]` and `+[NSDictionary dictionary]` when
the library loads and retained for good. An application that compares an array against `*__NSArray0__` to detect the
empty one gets the answer it gets on iOS 9 and later, for every empty array the release makes, and the same for the
dictionary.

## What it does not do

The class of the object is the release's own, so an application that asks for the name `__NSArray0` finds another.
