//
//  RunLoop+Scheduler.swift
//  
//
//  Created by Sergej Jaskiewicz on 13.12.2019.
//

import Foundation

extension RunLoop: Combine.Scheduler {

    /// The scheduler time type used by the run loop.
    public struct SchedulerTimeType: Strideable, Codable, Hashable {

        /// The date represented by this type.
        public var date: Date

        /// Initializes a run loop scheduler time with the given date.
        ///
        /// - Parameter date: The date to represent.
        public init(_ date: Date) {
            self.date = date
        }

        /// Returns the distance to another run loop scheduler time.
        ///
        /// - Parameter other: Another run loop time.
        /// - Returns: The time interval between this time and the provided time.
        public func distance(to other: SchedulerTimeType) -> Stride {
            let absoluteSelf = date.timeIntervalSinceReferenceDate
            let absoluteOther = other.date.timeIntervalSinceReferenceDate
            return Stride(absoluteSelf.distance(to: absoluteOther))
        }

        /// Returns a run loop scheduler time calculated by advancing this instance’s
        /// time by the given interval.
        ///
        /// - Parameter value: A time interval to advance.
        /// - Returns: A run loop time advanced by the given interval from this
        ///   instance’s time.
        public func advanced(by value: Stride) -> SchedulerTimeType {
            return SchedulerTimeType(date + value.magnitude)
        }

        /// The interval by which run loop times advance.
        public struct Stride: SchedulerTimeIntervalConvertible,
                              Comparable,
                              SignedNumeric,
                              ExpressibleByFloatLiteral,
                              Codable {

            public typealias FloatLiteralType = TimeInterval

            public typealias IntegerLiteralType = TimeInterval

            /// A type that can represent the absolute value of any possible value
            /// of the conforming type.
            public typealias Magnitude = TimeInterval

            /// The value of this time interval in seconds.
            public var magnitude: TimeInterval

            /// The value of this time interval in seconds.
            public var timeInterval: TimeInterval { return magnitude }

            public init(integerLiteral value: TimeInterval) {
                self.magnitude = value
            }

            public init(floatLiteral value: TimeInterval) {
                self.magnitude = value
            }

            public init(_ timeInterval: TimeInterval) {
                self.magnitude = timeInterval
            }

            public init?<Source: BinaryInteger>(exactly source: Source) {
                guard let value = TimeInterval(exactly: source) else { return nil }
                magnitude = value
            }

            public static func < (lhs: Stride, rhs: Stride) -> Bool {
                return lhs.magnitude < rhs.magnitude
            }

            public static func * (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(lhs.magnitude * rhs.magnitude)
            }

            public static func + (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(lhs.magnitude + rhs.magnitude)
            }

            public static func - (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(lhs.magnitude - rhs.magnitude)
            }

            public static func *= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude *= rhs.magnitude
            }

            public static func += (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude += rhs.magnitude
            }

            public static func -= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude -= rhs.magnitude
            }

            public static func seconds(_ value: Int) -> Stride {
                return Stride(TimeInterval(value))
            }

            public static func seconds(_ value: Double) -> Stride {
                return Stride(TimeInterval(value))
            }

            public static func milliseconds(_ value: Int) -> Stride {
                return Stride(TimeInterval(value) / 1_000)
            }

            public static func microseconds(_ value: Int) -> Stride {
                return Stride(TimeInterval(value) / 1_000_000)
            }

            public static func nanoseconds(_ value: Int) -> Stride {
                return Stride(TimeInterval(value) / 1_000_000_000)
            }
        }
    }

    /// Options that affect the operation of the run loop scheduler.
    public struct SchedulerOptions {
    }

    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        performBlockPortably(action)
    }

    public func schedule(after date: SchedulerTimeType,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) {
        let timer = Timer(fire: date.date,
                          interval: 0,
                          repeats: false,
                          block: { _ in action() })
        timer.tolerance = tolerance.timeInterval
        add(timer, forMode: .default)
    }

    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) -> Cancellable {
        let timer = Timer(fire: date.date,
                          interval: interval.timeInterval,
                          repeats: true,
                          block: { _ in action() })
        timer.tolerance = tolerance.timeInterval
        add(timer, forMode: .default)
        return AnyCancellable { timer.invalidate() }
    }

    public var now: SchedulerTimeType {
        return .init(Date())
    }

    public var minimumTolerance: SchedulerTimeType.Stride {
        return .init(0)
    }
}
