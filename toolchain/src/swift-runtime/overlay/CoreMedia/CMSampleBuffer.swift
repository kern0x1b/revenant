import Foundation

private func check(_ status: OSStatus) throws {
    if status != noErr {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
    }
}

extension CMSampleBuffer {
    public var isValid: Bool {
        return CMSampleBufferIsValid(self)
    }

    public var numSamples: Int {
        return CMSampleBufferGetNumSamples(self)
    }

    public var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }

    public var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }

    public var decodeTimeStamp: CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }

    public var outputDuration: CMTime {
        return CMSampleBufferGetOutputDuration(self)
    }

    public var outputPresentationTimeStamp: CMTime {
        return CMSampleBufferGetOutputPresentationTimeStamp(self)
    }

    public func setOutputPresentationTimeStamp(_ pts: CMTime) throws {
        try check(CMSampleBufferSetOutputPresentationTimeStamp(self, newValue: pts))
    }

    public var outputDecodeTimeStamp: CMTime {
        return CMSampleBufferGetOutputDecodeTimeStamp(self)
    }

    public func sampleTimingInfos() throws -> [CMSampleTimingInfo] {
        var needed = 0
        let sizing = CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &needed)
        if sizing != noErr && sizing != kCMSampleBufferError_BufferHasNoSampleTimingInfo {
            try check(sizing)
        }
        var infos = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: needed)
        if needed > 0 {
            try check(CMSampleBufferGetSampleTimingInfoArray(self, entryCount: needed, arrayToFill: &infos, entriesNeededOut: nil))
        }
        return infos
    }

    public func outputSampleTimingInfos() throws -> [CMSampleTimingInfo] {
        var needed = 0
        let sizing = CMSampleBufferGetOutputSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &needed)
        if sizing != noErr && sizing != kCMSampleBufferError_BufferHasNoSampleTimingInfo {
            try check(sizing)
        }
        var infos = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: needed)
        if needed > 0 {
            try check(CMSampleBufferGetOutputSampleTimingInfoArray(self, entryCount: needed, arrayToFill: &infos, entriesNeededOut: nil))
        }
        return infos
    }

    public func sampleTimingInfo(at sampleIndex: CMItemIndex) throws -> CMSampleTimingInfo {
        var info = CMSampleTimingInfo()
        try check(CMSampleBufferGetSampleTimingInfo(self, at: sampleIndex, timingInfoOut: &info))
        return info
    }

    public func sampleSizes() throws -> [Int] {
        var needed = 0
        let sizing = CMSampleBufferGetSampleSizeArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &needed)
        if sizing != noErr && sizing != kCMSampleBufferError_BufferHasNoSampleSizes {
            try check(sizing)
        }
        var sizes = [Int](repeating: 0, count: needed)
        if needed > 0 {
            try check(CMSampleBufferGetSampleSizeArray(self, entryCount: needed, arrayToFill: &sizes, entriesNeededOut: nil))
        }
        return sizes
    }

    public func sampleSize(at sampleIndex: Int) -> Int {
        return CMSampleBufferGetSampleSize(self, at: sampleIndex)
    }

    public var totalSampleSize: Int {
        return CMSampleBufferGetTotalSampleSize(self)
    }

    public var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
}
