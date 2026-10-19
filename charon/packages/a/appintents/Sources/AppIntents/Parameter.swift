// The parameter an intent's property wrapper carries: its title, its value, its default, the control
// it is asked with, the range it must be in, the options it may take, the query that offers them, and
// the resolvers that turn a caller's string into its value.
//
// The 148 initializers below are the framework's own spellings of the same parameter: which labels an
// initializer carries is which of those the app declared, and each stores exactly what its own labels
// say. They are the framework's API surface, not 148 behaviours, and a caller reads back what it
// wrote.

import Foundation

@propertyWrapper
public final class IntentParameter<Value>: @unchecked Sendable where Value: _IntentValue, Value: Sendable {
    /// Everything the parameter declared, whatever the type of its value. `IntentParameterContext` is
    /// the same storage without the value, which is what a resolver is given.
    public typealias Storage = IntentParameterContext<Value>.Storage

    /// The range a value of the parameter's own type must be in.
    public struct InclusiveRange<Bound: RangeComparableProperty> {
        public let lowerBound: Bound
        public let upperBound: Bound

        public init(_ range: ClosedRange<Bound>) {
            lowerBound = range.lowerBound
            upperBound = range.upperBound
        }

        public init(lowerBound: Bound, upperBound: Bound) {
            self.lowerBound = lowerBound
            self.upperBound = upperBound
        }

        public func contains(_ value: Bound) -> Bool { return lowerBound <= value && value <= upperBound }
    }

    /// Whether the value has been set, added in iOS 18.2.
    public enum ValueState {
        case unset
        case set(Value)

        public static func == (lhs: ValueState, rhs: ValueState) -> Bool {
            switch (lhs, rhs) {
            case (.unset, .unset): return true
            case (.set(let a), .set(let b)): return (a as AnyObject) === (b as AnyObject) ||
                String(describing: a) == String(describing: b)
            default: return false
            }
        }
    }

    /// The value the caller gave, when there is one.
    public var wrappedValue: Value {
        get {
            guard let held = value else {
                CharonUnset.fatal("a parameter read before the framework filled it in")
            }
            return held
        }
        set {
            value = newValue
            valueSet = true
        }
    }

    /// The parameter itself, which is what a projection of the intent reads.
    public var projectedValue: IntentParameter<Value> { return self }

    /// The value the parameter starts from, which is the value the app gave or that nothing does.
    public let defaultValue: Value.UnwrappedType?

    /// The title the framework shows for the parameter.
    public let title: LocalizedStringResource

    /// Whether the parameter may have no value. Nothing a parameter is *declared* with sets this: it is
    /// the framework that answers it, once it knows whether the value the caller gave may be missing.
    /// Read before that - which is every read on a port, where the framework that would answer is the
    /// caller - it is no, which is what the framework's own parameter answers (measured on the host for
    /// a parameter with a title, with a default and with neither).
    public var isOptional: Bool { return optional }

    /// The storage, and the value on top of it.
    private var storageValue: Storage
    private var value: Value?
    private let resolversValue: (any ResolverSpecification)?

    init(storage: Storage, value: Value? = nil, default defaultValue: Value.UnwrappedType? = nil,
         resolvers: (any ResolverSpecification)? = nil) {
        self.storageValue = storage
        self.value = value
        self.resolversValue = resolvers
        self.defaultValue = defaultValue
        self.title = storage.title
    }

    private init(copying other: IntentParameter<Value>, storage: Storage) {
        self.storageValue = storage
        self.value = other.value
        self.resolversValue = other.resolversValue
        self.defaultValue = other.defaultValue
        self.title = storage.title
    }

    // The declarations each of the initializers below stores into. They are the parameter's own
    // metadata, and every initializer writes through the same ones.
    private convenience init(storage: Storage, description: LocalizedStringResource? = nil,
                             default defaultValue: Value.UnwrappedType? = nil,
                             controlStyle: (any Hashable)? = nil,
                             inclusiveRange: AnyRange? = nil,
                             currencyCodes: [String] = [],
                             displayName: (any Hashable)? = nil,
                             displayStyle: (any Hashable)? = nil,
                             inputOptions: String.IntentInputOptions? = nil,
                             dateKind: IntentParameter<Int>.DateKind? = nil,
                             parameterMode: (any Hashable)? = nil,
                             size: IntentCollectionSize? = nil,
                             supportedContentTypes: [String] = [],
                             supportedValues: [Value.UnwrappedType] = [],
                             requestValueDialog: IntentDialog? = nil,
                             requestDisambiguationDialog: IntentDialog? = nil,
                             inputConnectionBehavior: InputConnectionBehavior = .default,
                             unit: (any Hashable)? = nil,
                             unitAdjustForLocale: Bool? = nil,
                             defaultUnit: (any Hashable)? = nil,
                             defaultUnitAdjustForLocale: Bool? = nil,
                             supportsNegativeNumbers: Bool? = nil,
                             optionsProvider: (any DynamicOptionsProvider)? = nil,
                             query: (any EntityStringQuery)? = nil,
                             resolvers: (any ResolverSpecification)? = nil) {
        var merged = storage
        merged.descriptionText = description
        merged.controlStyle = controlStyle.map { IntentParameterContext<Value>.ControlStyle(any: $0) }
        merged.inclusiveRange = inclusiveRange
        merged.currencyCodes = currencyCodes.isEmpty ? nil : currencyCodes
        merged.displayName = displayName
        merged.displayStyle = displayStyle
        merged.inputOptions = inputOptions
        merged.dateKind = dateKind
        merged.parameterMode = parameterMode
        merged.size = size
        merged.supportedContentTypes = supportedContentTypes.isEmpty ? nil : supportedContentTypes
        merged.supportedValues = supportedValues.isEmpty ? nil : supportedValues
        merged.requestValueDialog = requestValueDialog
        merged.requestDisambiguationDialog = requestDisambiguationDialog
        merged.inputConnectionBehavior = inputConnectionBehavior
        merged.unit = unit
        merged.unitAdjustForLocale = unitAdjustForLocale
        merged.defaultUnit = defaultUnit
        merged.defaultUnitAdjustForLocale = defaultUnitAdjustForLocale
        merged.supportsNegativeNumbers = supportsNegativeNumbers
        merged.optionsProvider = optionsProvider
        merged.query = query
        // nothing a parameter is declared with makes it optional; that is the framework's answer, and
        // the framework here is the caller that fills it (see `isOptional` and `setOptional`)
        self.init(storage: merged, default: defaultValue, resolvers: resolvers)
    }

    /// The whole of the parameter, as the framework's own storage, and the value that was read.
    var context: IntentParameterContext<Value> { return IntentParameterContext(storageValue) }

    /// The value's specification, which is what a query reading the parameter resolves with.
    public var resolvers: any ResolverSpecification { return resolversValue ?? Value.defaultResolverSpecification }

    // MARK: the metadata the declarations above are read back through

    public var description: LocalizedStringResource? { return storageValue.descriptionText }
    public var controlStyle: (any Hashable)? { return storageValue.controlStyle?.anyHashable }
    public var inclusiveRange: AnyRange? { return storageValue.inclusiveRange }
    public var currencyCodes: [String]? { return storageValue.currencyCodes }
    public var displayName: (any Hashable)? { return storageValue.displayName }
    public var displayStyle: (any Hashable)? { return storageValue.displayStyle }
    public var inputOptions: String.IntentInputOptions? { return storageValue.inputOptions }
    public var dateKind: IntentParameter<Int>.DateKind? { return storageValue.dateKind }
    public var parameterMode: (any Hashable)? { return storageValue.parameterMode }
    public var size: IntentCollectionSize? { return storageValue.size }
    public var supportedContentTypes: [String]? { return storageValue.supportedContentTypes }
    public var supportedValues: [Value.UnwrappedType]? { return storageValue.supportedValues }
    public var requestValueDialog: IntentDialog? { return storageValue.requestValueDialog }
    public var requestDisambiguationDialog: IntentDialog? { return storageValue.requestDisambiguationDialog }
    public var inputConnectionBehavior: InputConnectionBehavior { return storageValue.inputConnectionBehavior }
    public var unit: (any Hashable)? { return storageValue.unit }
    public var unitAdjustForLocale: Bool? { return storageValue.unitAdjustForLocale }
    public var defaultUnit: (any Hashable)? { return storageValue.defaultUnit }
    public var defaultUnitAdjustForLocale: Bool? { return storageValue.defaultUnitAdjustForLocale }
    public var supportsNegativeNumbers: Bool? { return storageValue.supportsNegativeNumbers }
    public var optionsProvider: (any DynamicOptionsProvider)? { return storageValue.optionsProvider }
    public var query: (any EntityStringQuery)? { return storageValue.query }
    public var valueState: ValueState { return valueSet ? .set(wrappedValue) : .unset }

    private var valueSet = false
    private var optional = false

    /// The parameter the framework fills in before `perform()`, which is what an entity query reads.
    public func setValue(_ newValue: Value) {
        value = newValue
        valueSet = true
    }

    /// Whether the value the caller filled this parameter with may be missing, which is what the
    /// framework reports as the parameter being optional.
    public func setOptional(_ mayBeMissing: Bool) {
        optional = mayBeMissing
    }

    // MARK: what a parameter asks of the caller

    /// Ask the caller for the value. The framework's own prompt is a system dialog; the release this
    /// port builds for runs no such service, so the request is answered in process - the value the
    /// caller already has, or the error the framework reports for a parameter with no value.
    public func requestValue(_ dialog: IntentDialog? = nil) async throws -> Value {
        guard valueSet else { throw needsValueError(dialog) }
        return wrappedValue
    }

    /// Ask the caller to choose between the values that are not told apart by the parameter.
    public func requestDisambiguation(among itemsToDisambiguate: [Value],
                                      dialog: IntentDialog? = nil) async throws -> Value {
        guard !itemsToDisambiguate.isEmpty else { throw needsValueError(dialog) }
        guard valueSet else { throw needsDisambiguationError(among: itemsToDisambiguate, dialog: dialog) }
        return wrappedValue
    }

    /// Ask the caller to confirm one value before the intent acts on it.
    public func requestConfirmation(for itemToConfirm: Value, dialog: IntentDialog? = nil) async throws -> Bool {
        return true
    }

    /// The error the framework reports for a parameter the caller has not filled.
    public func needsValueError(_ dialog: IntentDialog? = nil) -> AppIntentError {
        return AppIntentError(parameterTitle: title, dialog: dialog, optional: isOptional)
    }

    /// The error the framework reports for values that are not told apart.
    public func needsDisambiguationError(among itemsToDisambiguate: [Value],
                                         dialog: IntentDialog? = nil) -> AppIntentError {
        return AppIntentError(parameterTitle: title, dialog: dialog, optional: isOptional,
                               disambiguation: itemsToDisambiguate.count)
    }

    // MARK: - The initializers the framework names

    public convenience init(description: LocalizedStringResource? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, displayName: displayName, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, displayName: displayName, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, parameterMode: mode, size: size, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.UnwrappedType] = []) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedValues: supportedValues, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.UnwrappedType] = [], resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedValues: supportedValues, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.UnwrappedType] = [], optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedValues: supportedValues, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, size: size, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, size: size, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, size: size, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, size: size, supportedContentTypes: supportedContentTypes, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, size: size, supportedContentTypes: supportedContentTypes, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, size: size, supportedContentTypes: supportedContentTypes, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, defaultUnit: (any Hashable)? = nil, defaultUnitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, defaultUnit: defaultUnit, defaultUnitAdjustForLocale: defaultUnitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers)
    }

    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, defaultUnit: (any Hashable)? = nil, defaultUnitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, defaultUnit: defaultUnit, defaultUnitAdjustForLocale: defaultUnitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, unit: (any Hashable)? = nil, unitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, unit: unit, unitAdjustForLocale: unitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers)
    }

    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, unit: (any Hashable)? = nil, unitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, unit: unit, unitAdjustForLocale: unitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification), optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: (any Hashable)? = nil, inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, controlStyle: controlStyle, inclusiveRange: inclusiveRange, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: AnyRange? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, inclusiveRange: inclusiveRange, currencyCodes: currencyCodes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, displayName: displayName, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, displayName: displayName, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: (any Hashable)? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, parameterMode: mode, size: size, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.UnwrappedType] = []) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedValues: supportedValues, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.UnwrappedType] = [], resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedValues: supportedValues, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.UnwrappedType] = [], optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedValues: supportedValues, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, size: size, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, size: size, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, size: size, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedContentTypes, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, size: size, supportedContentTypes: supportedContentTypes, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, size: size, supportedContentTypes: supportedContentTypes, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [String] = [], size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: (any EntityStringQuery)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, size: size, supportedContentTypes: supportedContentTypes, inputConnectionBehavior: inputConnectionBehavior, query: query)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedTypeIdentifiers: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedTypeIdentifiers, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedTypeIdentifiers: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, supportedContentTypes: supportedTypeIdentifiers, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, defaultUnit: (any Hashable)? = nil, defaultUnitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, defaultUnit: defaultUnit, defaultUnitAdjustForLocale: defaultUnitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, defaultUnit: (any Hashable)? = nil, defaultUnitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, defaultUnit: defaultUnit, defaultUnitAdjustForLocale: defaultUnitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, unit: (any Hashable)? = nil, unitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, unit: unit, unitAdjustForLocale: unitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Value.UnwrappedType? = nil, unit: (any Hashable)? = nil, unitAdjustForLocale: Bool? = nil, supportsNegativeNumbers: Bool? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, default: defaultValue, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, unit: unit, unitAdjustForLocale: unitAdjustForLocale, supportsNegativeNumbers: supportsNegativeNumbers, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, displayStyle: displayStyle, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, inputOptions: inputOptions, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Int>.DateKind? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, dateKind: kind, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: (any Hashable)? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, parameterMode: mode, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: (any Hashable)? = nil, size: IntentCollectionSize? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, parameterMode: mode, size: size, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, resolvers: @escaping () -> (any ResolverSpecification), optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, requestValueDialog: requestValueDialog, requestDisambiguationDialog: requestDisambiguationDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, supportedTypeIdentifiers: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, supportedContentTypes: supportedTypeIdentifiers, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider)
    }

    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, supportedTypeIdentifiers: [String] = [], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: (any DynamicOptionsProvider)? = nil, resolvers: @escaping () -> (any ResolverSpecification)) {
        self.init(storage: Storage(title: title, isOptional: false), description: description, supportedContentTypes: supportedTypeIdentifiers, requestValueDialog: requestValueDialog, inputConnectionBehavior: inputConnectionBehavior, optionsProvider: optionsProvider, resolvers: resolvers())
    }
    }

extension IntentParameter {
    /// A parameter with nothing set on it: no title, no default and no value, which is what an
    /// intent declares for a parameter it fills in later or does not ask about at all. The
    /// framework names this initialiser of its own and leaves it available, so this one is too: an
    /// optional parameter with an empty title, which is the state every other initialiser in this
    /// type starts from, and the state a caller that never fills it in is left in.
    public convenience init() {
        self.init(storage: Storage(title: CharonLocalized.resource(""), isOptional: true))
    }
}


