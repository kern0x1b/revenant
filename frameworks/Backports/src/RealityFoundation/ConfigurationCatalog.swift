import Foundation

extension Entity {
    @frozen public struct ConfigurationCatalog {
        @frozen public struct Configuration: Identifiable, Sendable {
            public typealias ID = String

            public var id: String
            public init(id: String) { self.id = id }
        }

        @frozen public struct ConfigurationSet: Identifiable, Sendable {
            public typealias ID = String

            public var id: String
            public var configurations: [String: Configuration]
            public var defaultConfiguration: Configuration

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
                    self.defaultConfiguration = configurations.values.sorted { $0.id < $1.id }[0]
                }
            }

            public init(id: String, configurations: [Configuration],
                        defaultConfigurationId: String? = nil) throws {
                try self.init(id: id, configurations: Dictionary(uniqueKeysWithValues:
                                                                    configurations.map { ($0.id, $0) }),
                              defaultConfigurationId: defaultConfigurationId)
            }
        }

        @frozen public struct ConfigurationCombination {
            public let entity: Entity
            public let configurationSpecifications: [String: String]

            public init(entity: Entity, configurationSpecifications: [String: String]) {
                self.entity = entity
                self.configurationSpecifications = configurationSpecifications
            }
        }

        public var configurationSets: [String: ConfigurationSet]

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

        public init(configurationSets: [ConfigurationSet],
                    combinations: [ConfigurationCombination]) throws {
            try self.init(configurationSets: Dictionary(uniqueKeysWithValues:
                                                          configurationSets.map { ($0.id, $0) }),
                           combinations: combinations)
        }

        public private(set) var combinations: [ConfigurationCombination]
    }
}

@MainActor
public enum ConfigurationCatalogError: Error {
    case emptySet(String)
    case defaultNotInSet(set: String, default: String)
    case noSuchSet(String, entity: Entity)
    case noSuchConfiguration(set: String, configuration: String, entity: Entity)
}
