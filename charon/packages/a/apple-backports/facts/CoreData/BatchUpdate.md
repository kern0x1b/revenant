# Batch update, iOS 8.0

iOS 8 let an application set values on every object a predicate finds without loading them, in one
statement of the SQLite store. The request is executed with `-[NSManagedObjectContext executeRequest:error:]`.

Source: CoreData of the arm64 shared cache of iOS 12.0 (`-[NSBatchUpdateRequest initWithEntityName:]`,
`-initWithEntity:`, `-setPropertiesToUpdate:`, `-_newValidatedPropertiesToUpdate:error:`, `-entity`,
`-description`, `-requestType` and `-[NSBatchUpdateResult initWithResult:type:]`, with the strings of the
messages); the host's Core Data, run on a twin store next to the port for every case below
(`tests/backports/host/batchupdate`, 196 checks); an iPad 2 running 6.1.3
(`tests/backports/device/coredata8.m`), where the same expectations also hold against the host's own Core Data.

## The request

- Made with `-initWithEntityName:` (or `+batchUpdateRequestWithEntityName:`) or `-initWithEntity:`. It includes
  subentities, has result type status only and no predicate. The request type is 6. `-entityName` of one made
  with an entity is the entity's name; `-entity` of one made with a name raises `NSObjectInaccessibleException`
  ("This batch update request (%p) was created with a string name (%@), and cannot respond to -entity until used
  by an NSManagedObjectContext").
- `propertiesToUpdate` takes strings or property descriptions as keys and constants or expressions as values. With
  an entity, the keys are checked when the dictionary is set and it answers the checked dictionary, whose keys are
  the entity's attribute descriptions and whose values are all expressions (a constant is wrapped, `NSNull` too);
  with a name, the dictionary is kept as it was and checked when the request is executed.
- The keys raise `NSInvalidArgumentException`: a string with a dot ("Invalid string keypath %@ passed to
  propertiesToUpdate:"), a string the entity has no property of ("Invalid string key (null) passed to
  propertiesToUpdate:", the null being what the release prints), a description whose name is not the entity's
  ("Attribute/relationship description names passed to propertiesToUpdate must match name on fetch entity ((null))"),
  a relationship, to-one or to-many ("Invalid relationship (%@) passed to propertiesToUpdate:"), and a key that is
  not a description and has no `name` raises the unrecognised selector. A description of another entity is accepted
  when the entity has a property of its name.
- The values are checked when the request is executed: `NSNull` for a required attribute raises "Invalid NULL value
  for key (%@) passed to propertiesToUpdate:" with the key, the entity and the value in the user info; a variable,
  the object itself, an aggregate or any expression that is not a constant, a function or a key path raises "Invalid
  expression (%@) in propertiesToUpdate"; a key path with a dot, or one that is not an attribute, raises "Can't
  generate SQL for keypath %@ : invalid keypath"; a subquery raises "Unsupported subquery (non-aggregate not allowed
  in select or update column): %@".
- The description is `<NSBatchUpdateRequest : entity = %@, properties = %@, subentities = %d`, without the closing
  bracket, as in iOS 12 (the newest release adds the predicate). `-copy` is the superclass's and makes an empty request.

## The execution

An entity name that the model does not have raises `NSInternalInconsistencyException` ("Can't find entity for batch
update (%@)"), also for a request with no name. A `nil` or empty dictionary is not an exception: the answer is `nil`
and an `NSCocoaErrorDomain` error 134030 with `Reason` in the user info ("Empty or Null Dictionary passed to
propertiesToUpdate:").

The objects are found with the predicate in the entity and, unless it is turned off, its subentities; every value is
worked out from the object as it was before any of the values are set, so two properties can swap; the values are set and
saved. The answer is a result of the request's result type: YES, the IDs of the objects, or their number. The result
type keeps only its two low bits, as iOS 12 does.

## Where iOS 6 answers differently

- iOS 12 writes the values into the store with SQL, and the objects of the calling context stay as they were until they
  are merged. Here the objects are set in a context of its own and saved, so the model's rules apply (a value that does not
  fit its attribute, such as text in a number, fails the save and the answer is `nil` and the error, where iOS 12 stores it),
  the store's row cache is updated, and a registered object of the calling context shows the new value when it next reads it.
  The context of the port posts a did save notification, and iOS 12 posts none.
- The calling context is not touched: it has no changes afterwards, and an object of it is neither marked nor refreshed.
