@_exported import PhotosUI
import Foundation
import Photos
import UIKit

public struct PHPickerFilter: Equatable, Hashable {
    let object: __PHPickerFilter

    init(_ object: __PHPickerFilter) {
        self.object = object
    }

    public static let images = PHPickerFilter(__PHPickerFilter.images)
    public static let videos = PHPickerFilter(__PHPickerFilter.videos)
    public static let livePhotos = PHPickerFilter(__PHPickerFilter.livePhotos)
    public static let depthEffectPhotos = PHPickerFilter(__PHPickerFilter.depthEffectPhotos)
    public static let bursts = PHPickerFilter(__PHPickerFilter.bursts)
    public static let panoramas = PHPickerFilter(__PHPickerFilter.panoramas)
    public static let screenshots = PHPickerFilter(__PHPickerFilter.screenshots)
    public static let screenRecordings = PHPickerFilter(__PHPickerFilter.screenRecordings)
    public static let slomoVideos = PHPickerFilter(__PHPickerFilter.slomoVideos)
    public static let timelapseVideos = PHPickerFilter(__PHPickerFilter.timelapseVideos)
    public static let cinematicVideos = PHPickerFilter(__PHPickerFilter.cinematicVideos)

    public static func playbackStyle(_ playbackStyle: PHAsset.PlaybackStyle) -> PHPickerFilter {
        return PHPickerFilter(__PHPickerFilter.playbackStyleFilter(playbackStyle))
    }

    public static func any(of subfilters: [PHPickerFilter]) -> PHPickerFilter {
        return PHPickerFilter(__PHPickerFilter.anyFilter(matchingSubfilters: subfilters.map { $0.object }))
    }

    public static func all(of subfilters: [PHPickerFilter]) -> PHPickerFilter {
        return PHPickerFilter(__PHPickerFilter.allFilter(matchingSubfilters: subfilters.map { $0.object }))
    }

    public static func not(_ filter: PHPickerFilter) -> PHPickerFilter {
        return PHPickerFilter(__PHPickerFilter.notFilter(ofSubfilter: filter.object))
    }

    public static func == (lhs: PHPickerFilter, rhs: PHPickerFilter) -> Bool {
        return lhs.object.isEqual(rhs.object)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(object.hash)
    }
}

public struct PHPickerConfiguration: Equatable, Hashable {
    @nonexhaustive
    public enum AssetRepresentationMode {
        case automatic
        case current
        case compatible
    }

    @nonexhaustive
    public enum Selection {
        case `default`
        case ordered
    }

    public var preferredAssetRepresentationMode: PHPickerConfiguration.AssetRepresentationMode = .automatic
    public var selection: PHPickerConfiguration.Selection = .default
    public var selectionLimit: Int = 1
    public var filter: PHPickerFilter?
    public var preselectedAssetIdentifiers: [String] = []
    let photoLibrary: PHPhotoLibrary?

    public init() {
        photoLibrary = nil
    }

    public init(photoLibrary: PHPhotoLibrary) {
        self.photoLibrary = photoLibrary
    }

    init(_ object: __PHPickerConfiguration) {
        photoLibrary = nil
        switch object.preferredAssetRepresentationMode {
        case .current:
            preferredAssetRepresentationMode = .current
        case .compatible:
            preferredAssetRepresentationMode = .compatible
        default:
            preferredAssetRepresentationMode = .automatic
        }
        selection = object.selection == .ordered ? .ordered : .default
        selectionLimit = object.selectionLimit
        filter = object.filter.map { PHPickerFilter($0) }
        preselectedAssetIdentifiers = object.preselectedAssetIdentifiers
    }

    var object: __PHPickerConfiguration {
        let object = photoLibrary.map { __PHPickerConfiguration(photoLibrary: $0) } ?? __PHPickerConfiguration()
        switch preferredAssetRepresentationMode {
        case .automatic:
            object.preferredAssetRepresentationMode = .automatic
        case .current:
            object.preferredAssetRepresentationMode = .current
        case .compatible:
            object.preferredAssetRepresentationMode = .compatible
        }
        object.selection = selection == .ordered ? .ordered : .default
        object.selectionLimit = selectionLimit
        object.filter = filter?.object
        object.preselectedAssetIdentifiers = preselectedAssetIdentifiers
        return object
    }

    public static func == (lhs: PHPickerConfiguration, rhs: PHPickerConfiguration) -> Bool {
        return lhs.preferredAssetRepresentationMode == rhs.preferredAssetRepresentationMode && lhs.selection == rhs.selection &&
            lhs.selectionLimit == rhs.selectionLimit && lhs.filter == rhs.filter &&
            lhs.preselectedAssetIdentifiers == rhs.preselectedAssetIdentifiers && lhs.photoLibrary === rhs.photoLibrary
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(preferredAssetRepresentationMode)
        hasher.combine(selection)
        hasher.combine(selectionLimit)
        hasher.combine(filter)
        hasher.combine(preselectedAssetIdentifiers)
    }
}

public struct PHPickerResult: Equatable, Hashable {
    public let itemProvider: NSItemProvider
    let object: __PHPickerResult

    init(_ object: __PHPickerResult) {
        self.object = object
        itemProvider = object.itemProvider
    }

    public var assetIdentifier: String? {
        return object.assetIdentifier
    }

    public static func == (lhs: PHPickerResult, rhs: PHPickerResult) -> Bool {
        return lhs.object === rhs.object
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(object))
    }
}

public protocol PHPickerViewControllerDelegate: AnyObject {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult])
}

private final class PHPickerDelegateAdapter: NSObject, __PHPickerViewControllerDelegate {
    weak var delegate: PHPickerViewControllerDelegate?

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [__PHPickerResult]) {
        delegate?.picker(picker, didFinishPicking: results.map { PHPickerResult($0) })
    }
}

private var adapterKey = 0

extension PHPickerViewController {
    public var configuration: PHPickerConfiguration {
        return PHPickerConfiguration(__configuration)
    }

    public weak var delegate: PHPickerViewControllerDelegate? {
        get {
            return (objc_getAssociatedObject(self, &adapterKey) as? PHPickerDelegateAdapter)?.delegate
        }
        set {
            let adapter = (objc_getAssociatedObject(self, &adapterKey) as? PHPickerDelegateAdapter) ?? PHPickerDelegateAdapter()
            adapter.delegate = newValue
            objc_setAssociatedObject(self, &adapterKey, adapter, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            __delegate = adapter
        }
    }

    public convenience init(configuration: PHPickerConfiguration) {
        self.init(__configuration: configuration.object)
    }
}
