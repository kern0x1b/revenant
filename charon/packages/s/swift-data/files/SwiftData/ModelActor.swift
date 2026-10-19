// The model actor: a model run on its own executor, and the serial executor that executor is.
//
// Review finding 2 was that the pilot's `asUnownedSerialExecutor` was a `fatalError` standing in
// for an implementation. It is an implementation here, and it is the one the name says: a
// `SerialModelExecutor` IS a `SerialExecutor`, and a serial executor is its own unowned executor.
// So `unownedExecutor` hands back `UnownedSerialExecutor(theExecutor)` with no queue and no flag to
// get wrong. The legacy `UnownedSerialExecutor(impl:)` form, which this used to need, is gone from
// the standard library on this toolchain - there is no `UnownedSerialExecutorImplProtocol` - and the
// modern form is the shorter of the two anyway.

import Foundation
import CoreData
import Dispatch
import _Concurrency

/// What runs a model's work. An `Executor` is what an actor runs on; a `ModelExecutor` is one that
/// also names the context its models live in, so a model read off the executor needs nothing else
/// to find them.
public protocol ModelExecutor: Executor {
    var modelContext: ModelContext { get }
}

/// A `ModelExecutor` that runs one job at a time, which is what a `ModelContext` needs: Core Data
/// of the release is not thread-safe, and a private-queue context serialises its own work, so the
/// executor that owns one is serial by construction.
public protocol SerialModelExecutor: ModelExecutor, SerialExecutor {}

/// A model on its own executor. An actor, so every property it touches is isolated to that
/// executor; the container and the executor are readable from anywhere, because a caller needs them
/// before it can send anything.
public protocol ModelActor: Actor {
    nonisolated var modelContainer: ModelContainer { get }
    nonisolated var modelExecutor: any ModelExecutor { get }
}

extension ModelActor {
    /// The executor this actor runs on, as an unowned one. A serial executor is its own unowned
    /// serial executor, which is the whole of the answer.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        let executor = modelExecutor
        if let serial = executor as? any SerialExecutor {
            return UnownedSerialExecutor(serial)
        }
        // An executor that is not serial has no unowned *serial* form, and the value cannot be
        // made up: UnownedSerialExecutor takes a SerialExecutor and nothing else. That is the
        // conformer's own mistake, and it is said with the name of it.
        preconditionFailure("\(type(of: executor)) is a ModelExecutor and not a SerialModelExecutor, "
                            + "and UnownedSerialExecutor can only be built from a SerialExecutor")
    }

    /// The context this actor's models live in.
    public var modelContext: ModelContext { modelExecutor.modelContext }

    /// The model a persistent identifier names, in the context this actor reads and writes.
    public subscript<T>(id: PersistentIdentifier, as as: T.Type) -> T? where T: PersistentModel {
        modelContext.registeredModel(for: id)
    }
}

/// The default serial executor: a context's own private queue, and the job is the context's.
public class DefaultSerialModelExecutor: @unchecked Sendable, SerialModelExecutor {
    public final let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// The job runs on the context's own queue, through `perform`, and not on a queue of the
    /// executor's own: one queue is what makes the actor's work and the context's own operations
    /// serial against each other, which is what an actor over a `ModelContext` means. A
    /// `DispatchQueue` here would be a second one, and a job could then read a row while the
    /// context was saving it.
    public func enqueue(_ job: consuming ExecutorJob) {
        // An `ExecutorJob` is noncopyable and `~Escapable`, so it cannot be captured by
        // `perform`'s escaping closure: "noncopyable 'job' cannot be consumed when captured by an
        // escaping closure", and a typecheck does not diagnose it while the compile does.
        // `UnownedJob(job)` is the standard library's own form of the job that is copyable and
        // escapable - it borrows the job's executor rather than owning it, which is all a queue
        // needs - so the context's queue can run it on the unowned executor this object already
        // is. This is how the public examples of a custom executor on top of dispatch are written.
        let unowned = UnownedJob(job)
        let serial = self.asUnownedSerialExecutor()
        let context = modelContext.context
        context.perform { unowned.runSynchronously(on: serial) }
    }

    @objc deinit {}
}
