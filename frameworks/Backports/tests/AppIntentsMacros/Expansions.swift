import AppIntents

public struct Thing: AppEntity {
    public static var displayRepresentation: DisplayRepresentation = DisplayRepresentation(title: "Thing")
    public var id: String

    @ComputedProperty()
    public var rating: String = "unset"

    public init(id: String) { self.id = id }
}

public struct ThingExpanded {
    public var rating: String = "unset"
    private var _rating: String = "unset"
    public var comment: String?
    private var _comment: String?
}
