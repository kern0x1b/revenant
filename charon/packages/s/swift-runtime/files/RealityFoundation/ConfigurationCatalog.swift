// MARK: - Configuration catalogs
//
// What an entity is configured from: named sets of configurations, and a combination of an entity
// with the specifications that pick one of each.
//
// Read from the SDK's own interface, `iPhoneOS26.2.sdk/.../RealityFoundation.swiftmodule/
// arm64e-apple-ios.swiftinterface:10480-10526`, inside `extension RealityFoundation.Entity`: the
// catalog, its `Configuration`, `ConfigurationSet` and `ConfigurationCombination`, their two
// `==`, and the two throwing initializers.
//
// The catalog is data with one question in it, and the question is why the interface's
// initializers throw. Nothing in the interface says, so the contract here is a reading and it is
// written down as one: a configuration set names a default configuration, and naming one the set
// does not hold is the error. A set that names none takes its first configuration, which is the
// only remaining choice and needs no error. If Apple's reason for throwing is different, this is
// where to look first.

import Foundation

extension Entity {
    /// A named set of configurations, and which of them an entity starts in.
    @frozen public struct ConfigurationCatalog {
        /// One configuration, named.
        @frozen public struct Configuration: Identifiable, Sendable {
            public typealias ID = String

            public var id: String
            public init(id: String) { self.id = id }
        }

        /// A set of configurations with a default among them.
        @frozen public struct ConfigurationSet: Identifiable, Sendable {
            public typealias ID = String

            public var id: String
            public var configurations: [String: Configuration]
            /// The configuration an entity is in unless something says otherwise.
            public var defaultConfiguration: Configuration

            /// A set from a dictionary of configurations, naming the default.
            ///
            /// Throws when the named default is not among the configurations: that is the error the
            /// interface's throwing initializer admits of, and a set that cannot answer "which one
            /// by default" would silently start an entity in an arbitrary configuration.
            public init(id: String, configurations: [String: Configuration],
                        defaultConfigurationId: String? = nil) throws {
                guard !configurations.isEmpty else { throw ConfigurationCatalogError.emptySet(id) }
                self.id = id
                self.configurations = configurations
                if let defaultConfigurationId {
                    guard let chosen = configurations[defaultConfigurationId] else {
                        throw ConfigurationCatalogError.defaultNotInSet(set: id, default: defaultConfigurationId)
                    }
                    self.defaultConfiguration = chosen
                } else {
                    // Dictionary order is not a promise, so the first *by name* is the default: the
                    // choice is then the same on every run and in every process, which a hash
                    // order would not be.
                    self.defaultConfiguration = configurations.values.sorted { $0.id < $1.id }[0]
                }
            }

            /// A set from a list of configurations, naming the default.
            public init(id: String, configurations: [Configuration],
                        defaultConfigurationId: String? = nil) throws {
                try self.init(id: id, configurations: Dictionary(uniqueKeysWithValues:
                                                                    configurations.map { ($0.id, $0) }),
                              defaultConfigurationId: defaultConfigurationId)
            }
        }

        /// An entity and the specifications that choose a configuration of each of its sets.
        @frozen public struct ConfigurationCombination {
            public let entity: Entity
            public let configurationSpecifications: [String: String]

            public init(entity: Entity, configurationSpecifications: [String: String]) {
                self.entity = entity
                self.configurationSpecifications = configurationSpecifications
            }
        }

        public var configurationSets: [String: ConfigurationSet]

        /// A catalog from a dictionary of sets, naming the combinations.
        ///
        /// Throws for the same reason a set does: a combination that names a set this catalog does
        /// not hold cannot be resolved, and a combination whose specifications name a configuration
        /// that set does not hold cannot be either.
        public init(configurationSets: [String: ConfigurationSet],
                    combinations: [ConfigurationCombination]) throws {
            for combination in combinations {
                for (setId, specification) in combination.configurationSpecifications {
                    guard let set = configurationSets[setId] else {
                        throw ConfigurationCatalogError.noSuchSet(setId, entity: combination.entity)
                    }
                    guard set.configurations[specification] != nil else {
                        throw ConfigurationCatalogError.noSuchConfiguration(set: setId, configuration: specification, entity: combination.entity)
                    }
                }
            }
            self.configurationSets = configurationSets
            self.combinations = combinations
        }

        /// A catalog from a list of sets, naming the combinations.
        public init(configurationSets: [ConfigurationSet],
                    combinations: [ConfigurationCombination]) throws {
            try self.init(configurationSets: Dictionary(uniqueKeysWithValues:
                                                          configurationSets.map { ($0.id, $0) }),
                           combinations: combinations)
        }

        /// The combinations the catalog was made with, in the order it was given.
        public private(set) var combinations: [ConfigurationCombination]
    }
}

/// Why a catalog could not be made. The three cases are the three ways a name in it can fail to
/// resolve, and each names the set and the configuration involved.
@MainActor
public enum ConfigurationCatalogError: Error {
    /// A set with no configurations in it, which has no default to have.
    case emptySet(String)
    /// A set naming a default it does not hold.
    case defaultNotInSet(set: String, default: String)
    /// A combination naming a set the catalog does not hold.
    case noSuchSet(String, entity: Entity)
    /// A combination naming a configuration its set does not hold.
    case noSuchConfiguration(set: String, configuration: String, entity: Entity)
}
