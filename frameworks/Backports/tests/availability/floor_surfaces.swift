import AVFoundation
import CallKit
import CoreMedia
import CoreVideo
import Intents
import Photos
import PhotosUI
import UIKit

final class Wrapper: NSObject, AVAudioPlayerDelegate {
    var player: AVAudioPlayer?
    init(url: URL) {
        super.init()
        self.player = try? AVAudioPlayer(contentsOf: url, fileTypeHint: "mp3")
    }
}

func photos(asset: PHAsset) {
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat
    _ = PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options, resultHandler: { image, _ in })
}

func menu(subMenu: UIMenu, filtered: [UIMenuElement]) -> UIMenu {
    return UIMenu(title: subMenu.title, subtitle: subMenu.subtitle, image: subMenu.image, identifier: subMenu.identifier, options: subMenu.options, children: filtered)
}

final class AmountField: UITextField {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        builder.remove(menu: .replace)
        builder.remove(menu: .lookup)
        builder.remove(menu: .learn)
        builder.remove(menu: .share)
        if #available(iOS 17.0, *) {
            builder.remove(menu: .autoFill)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return super.canPerformAction(action, withSender: sender)
    }
}

func traits(textField: UITextField) {
    textField.autocorrectionType = .no
    textField.autocapitalizationType = .none
    textField.spellCheckingType = .no
    textField.smartQuotesType = .no
    textField.smartDashesType = .no
    textField.smartInsertDeleteType = .no
    textField.textContentType = nil
    textField.inputAssistantItem.leadingBarButtonGroups = []
    textField.inputAssistantItem.trailingBarButtonGroups = []
    if #available(iOS 17.0, *) {
        textField.inlinePredictionType = .no
    }
    if #available(iOS 18.0, *) {
        textField.writingToolsBehavior = .none
        textField.mathExpressionCompletionType = .no
    }
}

func traitsView(textView: UITextView) {
    textView.smartQuotesType = .no
    textView.smartDashesType = .no
    textView.smartInsertDeleteType = .no
    textView.textContentType = nil
}

protocol SupportedStartCallIntent {
    @available(iOS 10.0, *)
    var contacts: [INPerson]? { get }
}

extension INStartCallIntent: SupportedStartCallIntent {}

func donate(peer: Int64, title: String, localContactId: String?) {
    let handle = INPersonHandle(value: "tg\(peer)", type: .unknown)
    let contact = INPerson(personHandle: handle, nameComponents: nil, displayName: title, image: nil, contactIdentifier: localContactId, customIdentifier: "tg\(peer)")
    let intent = INStartCallIntent(callRecordFilter: nil, callRecordToCallBack: nil, audioRoute: .unknown, destinationType: .normal, contacts: [contact], callCapability: .audioCall)
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = .outgoing
    interaction.donate { _ in }
}

func providerConfiguration() -> CXProviderConfiguration {
    let providerConfiguration = CXProviderConfiguration()
    providerConfiguration.supportsVideo = true
    providerConfiguration.maximumCallsPerCallGroup = 1
    providerConfiguration.maximumCallGroups = 1
    providerConfiguration.supportedHandleTypes = [.phoneNumber, .generic]
    if let image = UIImage(named: "Call/CallKitLogo", in: Bundle.main, compatibleWith: nil) {
        providerConfiguration.iconTemplateImageData = image.pngData()
    }
    return providerConfiguration
}

func sampleBufferFromPixelBuffer(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
    var maybeFormat: CMVideoFormatDescription?
    let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &maybeFormat)
    if status != noErr { return nil }
    guard let format = maybeFormat else { return nil }
    var timingInfo = CMSampleTimingInfo(
        duration: CMTimeMake(value: 1, timescale: 30),
        presentationTimeStamp: CMTimeMake(value: 0, timescale: 30),
        decodeTimeStamp: CMTimeMake(value: 0, timescale: 30)
    )
    var maybeSampleBuffer: CMSampleBuffer?
    let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: format, sampleTiming: &timingInfo, sampleBufferOut: &maybeSampleBuffer)
    if bufferStatus != noErr { return nil }
    guard let sampleBuffer = maybeSampleBuffer else { return nil }
    let attachments: NSArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)! as NSArray
    let dict: NSMutableDictionary = attachments[0] as! NSMutableDictionary
    dict[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true as NSNumber
    return sampleBuffer
}

func timestamps(buffer: CMSampleBuffer?, main: CMSampleBuffer) -> Double {
    let timestamp = buffer?.presentationTimeStamp.seconds ?? CACurrentMediaTime()
    let main = main.presentationTimeStamp
    return timestamp + main.seconds
}

func picker(presenter: UIViewController) {
    if #available(iOS 14.0, *), PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {
        final class PickerDelegate: NSObject, PHPickerViewControllerDelegate {
            var completion: ((Any?) -> Void)?
            private func resolveResult(_ result: PHPickerResult) {
                if let assetIdentifier = result.assetIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        self.completion?(asset)
                        return
                    }
                }
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                        if let uiImage = image as? UIImage {
                            self?.completion?(uiImage)
                        }
                    }
                }
            }
            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                picker.dismiss(animated: true)
                if let result = results.first {
                    self.resolveResult(result)
                }
            }
        }
        let holder = PickerDelegate()
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = holder
        presenter.present(picker, animated: true, completion: nil)
    }
}

func images(asset: PHAsset, localIdentifier: String, thumbnail: Bool, hd: Bool, isVideo: Bool) {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
    var id: PHImageRequestID?
    if fetchResult.count != 0 {
        let asset = fetchResult.object(at: 0)
        let option = PHImageRequestOptions()
        option.deliveryMode = .highQualityFormat
        option.isNetworkAccessAllowed = true
        option.isSynchronous = false
        if thumbnail {
            option.resizeMode = .fast
        }
        var targetSize = PHImageManagerMaximumSize
        if min(asset.pixelWidth, asset.pixelHeight) > 3800 {
            targetSize = CGSize(width: 1.0, height: 1.0)
        }
        let a = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: option, resultHandler: { (image, info) -> Void in
            if let info = info, let degraded = info[PHImageResultIsDegradedKey], (degraded as AnyObject).boolValue! {
            }
        })
        let b = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: option, resultHandler: { _, _ in })
        let c = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .default, options: option, resultHandler: { _, _ in })
        id = a
        PHImageManager.default().cancelImageRequest(b)
        PHImageManager.default().cancelImageRequest(c)
    }
    let options = PHImageRequestOptions()
    let deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat
    options.deliveryMode = deliveryMode
    let requestId = PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFit, options: options, resultHandler: { image, info in
        if let image {
            if let info {
                if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled { return }
                if let degradedValue = info[PHImageResultIsDegradedKey] as? Bool, degradedValue { return }
            }
            if isVideo {
                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil, resultHandler: { asset, _, _ in
                    if let asset { _ = asset.duration }
                })
            }
        }
    })
    PHImageManager.default().cancelImageRequest(requestId)
    let videoOptions = PHVideoRequestOptions()
    videoOptions.isNetworkAccessAllowed = true
    videoOptions.deliveryMode = .highQualityFormat
    PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions, resultHandler: { avAsset, _, _ in
        guard let avAsset else { return }
        _ = avAsset
    })
    _ = id
}

func albums(collection: PHAssetCollection, smart: PHFetchResult<PHAssetCollection>) {
    smart.enumerateObjects { collection, index, _ in
        var supportedAlbums: [PHAssetCollectionSubtype] = [
            .smartAlbumBursts,
            .smartAlbumPanoramas,
            .smartAlbumScreenshots,
            .smartAlbumSelfPortraits,
            .smartAlbumSlomoVideos,
            .smartAlbumTimelapses,
            .smartAlbumVideos,
            .smartAlbumAllHidden
        ]
        if #available(iOS 11, *) {
            supportedAlbums.append(.smartAlbumAnimated)
            supportedAlbums.append(.smartAlbumDepthEffect)
            supportedAlbums.append(.smartAlbumLivePhotos)
        }
        if supportedAlbums.contains(collection.assetCollectionSubtype) {
            let result = PHAsset.fetchAssets(in: collection, options: nil)
            _ = result.count
        }
    }
}

func assetMembers(asset: PHAsset) {
    _ = asset.mediaSubtypes.contains(.videoHighFrameRate)
    _ = asset.mediaSubtypes.contains(.videoTimelapse)
    _ = asset.mediaSubtypes.contains(.photoLive)
    _ = asset.localIdentifier
    _ = asset.creationDate
    _ = asset.location
    _ = asset.duration
    _ = asset.isFavorite
    _ = asset.isHidden
    let resources = PHAssetResource.assetResources(for: asset)
    for resource in resources {
        _ = resource.originalFilename
        _ = resource.uniformTypeIdentifier
        _ = resource.type
        _ = resource.value(forKey: "fileSize") as? Int64
    }
    let creationOptions = PHAssetResourceCreationOptions()
    creationOptions.originalFilename = "x"
    creationOptions.shouldMoveFile = true
}

func saving(jpegWithID: Data, outputVideoURL: URL, imageData: Data, tempVideoPath: String) {
    PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, data: jpegWithID, options: nil)
        request.addResource(with: .pairedVideo, fileURL: outputVideoURL, options: nil)
    }, completionHandler: { _, error in })
    PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: tempVideoPath))
    }, completionHandler: { _, error in })
}

func authorization() {
    PHPhotoLibrary.requestAuthorization({ status in
        switch status {
        case .restricted, .denied, .notDetermined:
            break
        default:
            break
        }
    })
    _ = PHPhotoLibrary.authorizationStatus() == .authorized
}

func fetchOptions() {
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.fetchLimit = 10
    options.includeAssetSourceTypes = [.typeUserLibrary]
    _ = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: options)
    _ = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
    _ = PHAsset.fetchAssets(with: options)
    _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "x")
}
