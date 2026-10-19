# Constraint conflicts, iOS 9.0

iOS 9 let an entity declare uniqueness constraints, and a store that finds two objects
with the same values for one hands the merge policy an `NSConstraintConflict` to
resolve. The class is what an application's own merge policy names.

Source: CoreData of the arm64 shared cache of iOS 12.0 -
`-[NSConstraintConflict initWithConstraint:databaseObject:databaseSnapshot:conflictingObjects:conflictingSnapshots:]`,
`-description` and `-encodeWithCoder:`; the host's Core Data beside the port
(`tests/backports/host/constraintconflict`).

## What is carried

A value made with the constraint (an array of key names), the database object and
snapshot, and the conflicting objects and snapshots. The constraint and the two arrays
are copied. The constraint values are read when it is made: each key of the constraint
is asked of the **last** conflicting object with `-valueForKey:`, and a `nil` answer is
an `NSNull`; a key the object does not have raises the object's unknown key exception.
The description is `NSConstraintConflict (<address>) for constraint <the constraint>:
database: <the database object's object ID>, conflictedObjects: <the conflicting
objects' object IDs>`, with an empty list for none.

## Where iOS 6 differs

- The store of iOS 6 checks no uniqueness constraint, so no save makes a conflict, and
  `NSEntityDescription.uniquenessConstraints` and `-[NSMergePolicy
  resolveConstraintConflicts:error:]` are absent: a constraint that was declared and
  never enforced would let in the duplicates the model says cannot exist.
- iOS 12 codes a conflict only for a store that lives in another process, and logs the
  coder, the delegate and a message that conflicts "should not be archived or serialized"
  before it traps for any other coder. The port raises an `NSInvalidArgumentException`
  with the same words instead, for both the encoding and the decoding.
