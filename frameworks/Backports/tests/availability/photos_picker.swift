import Photos
import PhotosUI
import UIKit

final class PhotosPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {}
}

enum PhotosPickerUse {
    static func configuration() -> PHPickerConfiguration {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = PHPickerFilter.any(of: [.images, .livePhotos])
        return configuration
    }

    static func canLoadLivePhoto(_ provider: NSItemProvider) -> Bool {
        provider.canLoadObject(ofClass: PHLivePhoto.self)
    }

    static func livePhotoSize(_ livePhoto: PHLivePhoto) -> CGSize {
        livePhoto.size
    }

    static func isPairedVideo(_ resource: PHAssetResource) -> Bool {
        resource.type == .pairedVideo
    }

    static func requestFullSize(_ urls: [URL]) {
        let assets = PHAsset.fetchAssets(withALAssetURLs: urls, options: nil)
        guard let asset = assets.firstObject else {
            return
        }
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        asset.requestContentEditingInput(with: options) { input, _ in
            _ = input?.fullSizeImageURL
        }
    }
}
