//
//  Publishers.MapError.swift
//
//  The second initializer of `Publishers.MapError`, the one that takes its transform
//  under a label. The unlabeled one is the fork's own, carried from OpenCombine; Apple's
//  interface declares both.
//

extension Publishers.MapError {

    public init(upstream: Upstream,
                transform: @escaping (Upstream.Failure) -> Failure)
    {
        self.upstream = upstream
        self.transform = transform
    }
}
