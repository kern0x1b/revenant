import Foundation
import CoreData
import Dispatch
import _Concurrency

public protocol ModelExecutor: Executor {
    var modelContext: ModelContext { get }
}

public protocol SerialModelExecutor: ModelExecutor, SerialExecutor {}

public protocol ModelActor: Actor {
    nonisolated var modelContainer: ModelContainer { get }
    nonisolated var modelExecutor: any ModelExecutor { get }
}

extension ModelActor {
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        let executor = modelExecutor
        if let serial = executor as? any SerialExecutor {
            return UnownedSerialExecutor(serial)
        }
        preconditionFailure("\(type(of: executor)) is a ModelExecutor and not a SerialModelExecutor, "
                            + "and UnownedSerialExecutor can only be built from a SerialExecutor")
    }

    public var modelContext: ModelContext { modelExecutor.modelContext }

    public subscript<T>(id: PersistentIdentifier, as as: T.Type) -> T? where T: PersistentModel {
        modelContext.registeredModel(for: id)
    }
}

public class DefaultSerialModelExecutor: @unchecked Sendable, SerialModelExecutor {
    public final let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func enqueue(_ job: consuming ExecutorJob) {
        let unowned = UnownedJob(job)
        let serial = self.asUnownedSerialExecutor()
        let context = modelContext.context
        context.perform { unowned.runSynchronously(on: serial) }
    }

    @objc deinit {}
}
