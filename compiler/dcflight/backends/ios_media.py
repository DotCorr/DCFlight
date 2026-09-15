"""Compiler-owned narrow UIKit/ImageIO adapters; no product screens or copy."""
from . import Artifact, HEADER

SWIFT = r'''import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

struct NativePreparedMedia: Equatable {
    let data: Data
    let width: Int32
    let height: Int32
    var byteLength: Int32 { Int32(data.count) }
    var mimeType: String { "image/jpeg" }
}
struct NativePhotoOptions {
    let maxInputBytes: Int
    let maxPixels: Int
    let maxEdge: Int
    let qualityPercent: Int
    let maxOutputBytes: Int
}
enum NativePhotoFailure: Error { case inputLimit, pixelLimit, unsupported, outputLimit, unavailable }
enum NativePhotoPreparation {
    static func thumbnail(_ data: Data, options: NativePhotoOptions) throws -> CGImage {
        guard !data.isEmpty, data.count <= options.maxInputBytes else { throw NativePhotoFailure.inputLimit }
        guard let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              CGImageSourceGetCount(source)==1,
              let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let width=props[kCGImagePropertyPixelWidth] as? NSNumber,let height=props[kCGImagePropertyPixelHeight] as? NSNumber,
              width.int64Value>0,height.int64Value>0,
              width.int64Value <= Int64(options.maxPixels),height.int64Value <= Int64(options.maxPixels),
              width.int64Value <= Int64(options.maxPixels)/height.int64Value else { throw NativePhotoFailure.pixelLimit }
        guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:options.maxEdge,kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else { throw NativePhotoFailure.unsupported }
        return image
    }
    static func prepare(_ data: Data, options: NativePhotoOptions) throws -> NativePreparedMedia {
        let thumbnail=try thumbnail(data,options:options)
        guard let canvas=CGContext(data:nil,width:thumbnail.width,height:thumbnail.height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else { throw NativePhotoFailure.unsupported }
        canvas.setFillColor(CGColor(gray:1,alpha:1));canvas.fill(CGRect(x:0,y:0,width:thumbnail.width,height:thumbnail.height))
        canvas.draw(thumbnail,in:CGRect(x:0,y:0,width:thumbnail.width,height:thumbnail.height))
        guard let image=canvas.makeImage() else { throw NativePhotoFailure.unsupported }
        let encoded=NSMutableData()
        guard let destination=CGImageDestinationCreateWithData(encoded,UTType.jpeg.identifier as CFString,1,nil) else { throw NativePhotoFailure.unsupported }
        CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality:Double(options.qualityPercent)/100] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw NativePhotoFailure.unsupported }
        guard encoded.length <= options.maxOutputBytes,encoded.length <= Int(Int32.max) else { throw NativePhotoFailure.outputLimit }
        return NativePreparedMedia(data:encoded as Data,width:Int32(image.width),height:Int32(image.height))
    }
    static func read(_ url: URL, maximum: Int) throws -> Data {
        let handle=try FileHandle(forReadingFrom:url);defer { try? handle.close() }
        let bytes=try handle.read(upToCount:maximum+1) ?? Data()
        guard bytes.count <= maximum else { throw NativePhotoFailure.inputLimit };return bytes
    }
}
enum NativePhotoResult { case selected(NativePreparedMedia), cancelled, failed }
struct NativePhotoRequest: Identifiable {
    let id=UUID()
    let options: NativePhotoOptions
    let completion: (NativePhotoResult) -> Void
}
final class NativePhotoPresentationController: UIViewController {
    var ready: (() -> Void)?
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated);ready?() }
}
struct NativePhotoPresenter: UIViewControllerRepresentable {
    let request: NativePhotoRequest?
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> NativePhotoPresentationController { NativePhotoPresentationController() }
    func updateUIViewController(_ view: NativePhotoPresentationController, context: Context) {
        let coordinator=context.coordinator
        guard let request else { coordinator.cancel();return }
        guard coordinator.identity != request.id else { return }
        coordinator.cancel();coordinator.identity=request.id;coordinator.request=request
        view.ready = { [weak view,weak coordinator] in
            guard let view,let coordinator,coordinator.identity==request.id,!coordinator.presented,view.view.window != nil else { return }
            var parent=view.view.window?.rootViewController ?? view
            while let presented=parent.presentedViewController { parent=presented }
            var config=PHPickerConfiguration(photoLibrary:.shared());config.filter = .images;config.selectionLimit=1
            let picker=PHPickerViewController(configuration:config);picker.delegate=coordinator
            coordinator.presented=true;coordinator.picker=picker;parent.present(picker,animated:true)
        }
        DispatchQueue.main.async { [weak view] in view?.ready?() }
    }
    static func dismantleUIViewController(_ view: NativePhotoPresentationController, coordinator: Coordinator) { coordinator.cancel() }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var identity: UUID?
        var request: NativePhotoRequest?
        weak var picker: PHPickerViewController?
        var progress: Progress?
        var presented=false
        func cancel() { presented=false;identity=nil;request=nil;progress?.cancel();progress=nil;picker?.dismiss(animated:false);picker=nil }
        func finish(_ result: NativePhotoResult, identity: UUID) {
            guard self.identity==identity,let request else { return }
            self.identity=nil;self.request=nil;progress=nil;request.completion(result)
        }
        func picker(_ picker: PHPickerViewController,didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated:true);self.picker=nil
            guard let identity,let request else { return }
            guard let item=results.first else { finish(.cancelled,identity:identity);return }
            progress=item.itemProvider.loadFileRepresentation(forTypeIdentifier:UTType.image.identifier) { [weak self] url,error in
                do {
                    guard let url,error == nil else { throw NativePhotoFailure.unavailable }
                    let data=try NativePhotoPreparation.read(url,maximum:request.options.maxInputBytes)
                    DispatchQueue.global(qos:.userInitiated).async {
                        let result: NativePhotoResult
                        do { result = .selected(try NativePhotoPreparation.prepare(data,options:request.options)) } catch { result = .failed }
                        DispatchQueue.main.async { self?.finish(result,identity:identity) }
                    }
                } catch { DispatchQueue.main.async { self?.finish(.failed,identity:identity) } }
            }
        }
    }
}
'''


def emit(files):
    files['ios/App/Generated/NativeMedia.swift']=Artifact(HEADER+SWIFT+REMOTE)

REMOTE = r'''
struct NativeLocalImage<Loading: View, Failure: View>: View {
    let media: NativePreparedMedia?
    let fill: Bool
    let label: String
    @ViewBuilder let loading: () -> Loading
    @ViewBuilder let failure: () -> Failure
    var body: some View {
        if let media {
            if let image=UIImage(data:media.data) { Image(uiImage:image).resizable().aspectRatio(contentMode:fill ? .fill : .fit).accessibilityLabel(label) }
            else { failure() }
        } else { loading() }
    }
}
struct NativeRemoteImage<Loading: View, Failure: View>: View {
    let address: String
    let bearer: String
    let maxBytes: Int
    let maxPixels: Int
    let maxEdge: Int
    let fill: Bool
    let label: String
    @ViewBuilder let loading: () -> Loading
    @ViewBuilder let failure: () -> Failure
    private struct Identity: Equatable { let address: String;let bearer: String;let maxBytes: Int;let maxPixels: Int;let maxEdge: Int }
    private struct Loaded { let identity: Identity;let image: UIImage }
    private var identity: Identity { Identity(address:address,bearer:bearer,maxBytes:maxBytes,maxPixels:maxPixels,maxEdge:maxEdge) }
    @State private var loaded: Loaded?
    @State private var failed: Identity?
    var body: some View {
        Group {
            if let loaded,loaded.identity==identity { Image(uiImage:loaded.image).resizable().aspectRatio(contentMode:fill ? .fill : .fit).accessibilityLabel(label) }
            else if failed==identity { failure() }
            else { loading() }
        }
        .task(id:identity) {
            loaded=nil;failed=nil
            let expected=identity
            let transport=NativeHTTPTransport();defer { transport.close() }
            do {
                guard !bearer.isEmpty,let url=URL(string:address) else { throw NativeEffectFailure.invalidAddress }
                let (data,status)=try await transport.send(url:url,method:"GET",body:[:],bearer:bearer,maxBytes:maxBytes)
                guard (200..<300).contains(status) else { throw NativeEffectFailure.invalidResponse }
                let image=try await Task.detached { () throws -> UIImage in
                    let image=try NativePhotoPreparation.thumbnail(data,options:NativePhotoOptions(maxInputBytes:maxBytes,maxPixels:maxPixels,maxEdge:maxEdge,qualityPercent:100,maxOutputBytes:maxBytes))
                    return UIImage(cgImage:image)
                }.value
                try Task.checkCancellation();guard expected==identity else { return };loaded=Loaded(identity:expected,image:image)
            } catch is CancellationError { }
              catch { guard !Task.isCancelled,expected==identity else { return };failed=expected }
        }
        .onDisappear { loaded=nil;failed=nil }
    }
}
'''
