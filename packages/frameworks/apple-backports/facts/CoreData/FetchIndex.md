# Fetch indexes, iOS 11.0

iOS 11 let a model describe an index of an entity: a name, elements of a property each
with a collation type and a direction, and a predicate for a partial index, with
`NSFetchIndexDescription`, `NSFetchIndexElementDescription` and
`NSEntityDescription.indexes`. It replaced the compound indexes and the `indexed` flag
of a property. The documentation of `indexes` says the value "may be ignored by stores
which do not natively support indexing", and the store of iOS 6 builds no index from it.

Source: CoreData of the arm64 shared cache of iOS 12.0 - the methods of
`NSFetchIndexElementDescription`, `NSFetchIndexDescription` and `NSEntityDescription`
named below, read case by case with the strings of the messages. The host's Core Data,
side by side with the renamed classes and selectors (`tests/backports/host/fetchindex`),
and an iPad 2 running 6.1.3.

## What is carried, and checked

- `NSFetchIndexElementDescription`: made with a property and a collation type
  (binary or rtree). A missing property, an unnamed property and a property that is neither an
  attribute nor a relationship (a fetched property) are refused with an
  `NSInvalidArgumentException` and the messages of iOS 12. Rtree needs an attribute of type
  integer 16, integer 32 or float, and refuses a relationship ("only be created on
  attributes") and every other attribute type ("floats or integers < 32 bit"). It starts
  ascending and in no index. Changing its collation type revalidates it and, when it is
  the only element of its index, raises "Can't change an collation type in a multi-element
  index" - the release's own words for it, which read the wrong way round: the check is
  `count <= 1`.
- `NSFetchIndexDescription`: made with a name and elements. A nil name raises "Can't
  create an index with no name"; nil elements and no elements are accepted; elements of
  more than one collation type raise "Can't mix and match collation types."; an element
  that is not an attribute or a relationship raises "Unsupported property type for
  index." The name and the predicate are kept as they are given, without a copy, the
  array of elements is copied, and an element made part of an index by `-initWithName:elements:`
  knows it. `-setElements:` checks the elements and does not tell them. Setting a name to
  nil raises "Can't set an index name to nil".
- Copies are new objects with copies of the elements, and the index copy keeps its entity.
  Two elements are equal when their property name, collation and direction are, two
  indexes when their name, elements and predicate are; the hash is that of the name.
  The descriptions are `<NSFetchIndexDescription : (Entity:name, elements: (...), predicate: ...)>`
  and `<NSFetchIndexElementDescription : (name (modeled property), 0, ascending)>`.
- Both classes code securely: an index with `NSIndexName`, `NSIndexElements`, `NSEntity`
  and `NSPartialIndexPredicate`, an element with `NSPropertyName`,
  `NSFetchIndexElementType`, `NSAscending` and `NSFetchIndexDescription`.
- `-[NSEntityDescription indexes]` answers an empty array to begin with. Setting it
  raises for a model in use (`Can't modify an immutable model.`), refuses two indexes of
  one name ("Entity E already has an index with name x") and an element whose attribute or
  relationship the entity does not have ("can't find attribute named x", "can't find
  relationship named x"), and tells each index its entity. `coreSpotlightDisplayNameExpression`
  is kept, and nothing reads it.

## What is not carried

The entity does not put the indexes into its own coding or its version hash, as iOS 12
does with a key of its own, and the store of this release builds no index from
them. The compound indexes and the indexed flag, which the release does honour, are left as
the application sets them. `NSCoreDataCoreSpotlightDelegate` and
`NSPersistentStore.coreSpotlightExporter` are absent: there is no Core Spotlight for them to
index into, and a delegate that seemed to index would mislead.
