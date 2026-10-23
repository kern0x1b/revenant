import Foundation

public protocol NWProtocolFramerImplementation: AnyObject {
    static var label: String { get }
    static var definition: NWProtocolFramer.Definition { get }

    init(framer: NWProtocolFramer.Instance)

    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult
    func handleInput(framer: NWProtocolFramer.Instance) -> Int
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool)
    func wakeup(framer: NWProtocolFramer.Instance)
    func stop(framer: NWProtocolFramer.Instance) -> Bool
    func cleanup(framer: NWProtocolFramer.Instance)
}

protocol NWFramingChannel: AnyObject {
    func framingParseInput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool
    func framingDeliver(_ data: Data, isComplete: Bool)
    func framingWrite(_ data: Data)
    func framingWritePayload(length: Int) -> Bool
}

public final class NWProtocolFramer {
    public enum StartResult {
        case ready
        case willMarkReady
    }

    public final class Message {
        public init() {}

        public init(definition: NWProtocolFramer.Definition) {}
    }

    public struct Definition {
        public let implementation: any NWProtocolFramerImplementation.Type

        public init(implementation: any NWProtocolFramerImplementation.Type) {
            self.implementation = implementation
        }
    }

    public final class Options: @unchecked Sendable {
        public let definition: NWProtocolFramer.Definition

        public init(definition: NWProtocolFramer.Definition) {
            self.definition = definition
        }
    }

    public final class Instance {
        weak var channel: NWFramingChannel?

        init(channel: NWFramingChannel) {
            self.channel = channel
        }

        public func parseInput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {
            channel?.framingParseInput(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, parse: parse) ?? false
        }

        public func deliverInput(data: Data, message: Message, isComplete: Bool) {
            channel?.framingDeliver(data, isComplete: isComplete)
        }

        public func writeOutput(data: Data) {
            channel?.framingWrite(data)
        }

        public func writeOutputNoCopy(length: Int) throws {
            guard channel?.framingWritePayload(length: length) == true else {
                throw NWError.posix(errno: EINVAL)
            }
        }
    }
}
