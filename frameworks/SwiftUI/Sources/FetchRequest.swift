import UIKit
import CoreData

final class FetchBox<Result: NSFetchRequestResult>: NSObject, NSFetchedResultsControllerDelegate {
    weak var node: CompositeNode?
    var controller: NSFetchedResultsController<Result>?
    var context: NSManagedObjectContext?
    var request: NSFetchRequest<Result>
    var sectionKey: String?
    var animation: Animation?

    init(request: NSFetchRequest<Result>, sectionKey: String? = nil) { self.request = request; self.sectionKey = sectionKey }

    func attach(_ context: NSManagedObjectContext) {
        guard context !== self.context || controller == nil else { return }
        self.context = context
        let made = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: sectionKey, cacheName: nil)
        made.delegate = self
        do {
            try made.performFetch()
        } catch {
            NSLog("%@", "[SwiftUI] FetchRequest failed: \(error)")
        }
        controller = made
    }

    func refetch() {
        guard let controller else { return }
        controller.fetchRequest.predicate = request.predicate
        controller.fetchRequest.sortDescriptors = request.sortDescriptors
        try? controller.performFetch()
        node?.invalidate()
    }

    var objects: [Result] { controller?.fetchedObjects ?? [] }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let animation { withAnimation(animation) { node?.invalidate() } } else { node?.invalidate() }
    }
}

public struct FetchedResults<Result: NSFetchRequestResult>: RandomAccessCollection {
    let objects: [Result]
    public var startIndex: Int { 0 }
    public var endIndex: Int { objects.count }
    public subscript(position: Int) -> Result { objects[position] }
}

@propertyWrapper
public struct FetchRequest<Result: NSFetchRequestResult>: DynamicProperty, DynamicPropertyInstaller {
    let request: NSFetchRequest<Result>
    let animation: Animation?
    var box: FetchBox<Result>?

    public var wrappedValue: FetchedResults<Result> { FetchedResults(objects: box?.objects ?? []) }

    public struct Configuration {
        let box: FetchBox<Result>?
        public var nsPredicate: NSPredicate? {
            get { box?.request.predicate }
            nonmutating set { box?.request.predicate = newValue; box?.refetch() }
        }
        public var sortDescriptors: [NSSortDescriptor] {
            get { box?.request.sortDescriptors ?? [] }
            nonmutating set { box?.request.sortDescriptors = newValue; box?.refetch() }
        }
    }
    public var projectedValue: Binding<Configuration> {
        let box = self.box
        return Binding(get: { Configuration(box: box) }, set: { _ in })
    }

    public init(fetchRequest: NSFetchRequest<Result>, animation: Animation? = nil) {
        request = fetchRequest; self.animation = animation
    }
    public init(entity: NSEntityDescription, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) {
        let made = NSFetchRequest<Result>()
        made.entity = entity
        made.sortDescriptors = sortDescriptors
        made.predicate = predicate
        self.init(fetchRequest: made, animation: animation)
    }
    public init(sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) where Result: NSManagedObject {
        let made = NSFetchRequest<Result>(entityName: String(describing: Result.self))
        made.sortDescriptors = sortDescriptors
        made.predicate = predicate
        self.init(fetchRequest: made, animation: animation)
    }

    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: FetchRequest<Result>.self)
        let box = (node.storages[key] as? FetchBox<Result>) ?? {
            let made = FetchBox(request: p.pointee.request)
            made.node = node
            made.animation = p.pointee.animation
            node.storages[key] = made
            return made
        }()
        box.attach(node.env.managedObjectContext)
        p.pointee.box = box
    }
}

public struct SectionedFetchResults<SectionIdentifier: Hashable, Result: NSFetchRequestResult>: RandomAccessCollection {
    public struct Section: Identifiable, RandomAccessCollection {
        public let id: SectionIdentifier
        let objects: [Result]
        public var startIndex: Int { 0 }
        public var endIndex: Int { objects.count }
        public subscript(position: Int) -> Result { objects[position] }
    }
    let sections: [Section]
    public var startIndex: Int { 0 }
    public var endIndex: Int { sections.count }
    public subscript(position: Int) -> Section { sections[position] }
}

@propertyWrapper
public struct SectionedFetchRequest<SectionIdentifier: Hashable, Result: NSFetchRequestResult>: DynamicProperty, DynamicPropertyInstaller {
    let request: NSFetchRequest<Result>
    let sectionKey: String
    let animation: Animation?
    var box: FetchBox<Result>?

    public var wrappedValue: SectionedFetchResults<SectionIdentifier, Result> {
        let sections = box?.controller?.sections ?? []
        return SectionedFetchResults(sections: sections.map { info in
            SectionedFetchResults.Section(id: (info.name as? SectionIdentifier) ?? (info.name as Any as! SectionIdentifier),
                                          objects: (info.objects as? [Result]) ?? [])
        })
    }

    public init(fetchRequest: NSFetchRequest<Result>, sectionIdentifier: KeyPath<Result, SectionIdentifier>, animation: Animation? = nil) {
        request = fetchRequest
        sectionKey = NSExpression(forKeyPath: sectionIdentifier).keyPath
        self.animation = animation
    }
    public init(sectionIdentifier: KeyPath<Result, SectionIdentifier>, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, animation: Animation? = nil) where Result: NSManagedObject {
        let made = NSFetchRequest<Result>(entityName: String(describing: Result.self))
        made.sortDescriptors = sortDescriptors
        made.predicate = predicate
        self.init(fetchRequest: made, sectionIdentifier: sectionIdentifier, animation: animation)
    }

    static func install(_ pointer: UnsafeMutableRawPointer, _ node: CompositeNode, _ key: Int) {
        let p = pointer.assumingMemoryBound(to: SectionedFetchRequest<SectionIdentifier, Result>.self)
        let box = (node.storages[key] as? FetchBox<Result>) ?? {
            let made = FetchBox(request: p.pointee.request, sectionKey: p.pointee.sectionKey)
            made.node = node
            made.animation = p.pointee.animation
            node.storages[key] = made
            return made
        }()
        box.attach(node.env.managedObjectContext)
        p.pointee.box = box
    }
}

struct ManagedObjectContextKey: EnvironmentKey {
    static var defaultValue: NSManagedObjectContext { AppRuntime.defaultContext }
}

extension AppRuntime {
    nonisolated(unsafe) static var fallbackContext: NSManagedObjectContext?
    static var defaultContext: NSManagedObjectContext {
        if let fallbackContext { return fallbackContext }
        let made = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        fallbackContext = made
        return made
    }
}

extension EnvironmentValues {
    public var managedObjectContext: NSManagedObjectContext {
        get { self[ManagedObjectContextKey.self] }
        set { self[ManagedObjectContextKey.self] = newValue }
    }
}
