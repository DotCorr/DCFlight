"""Native camera, permission, location and MapKit mechanics for shared declarations."""
from . import Artifact,HEADER

SWIFT=r'''import SwiftUI
import AVFoundation
import CoreLocation
import MapKit

// CLLocationManager delivers to its creating run loop; both managers are created on MainActor.
@MainActor final class NativeLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager=CLLocationManager()
    private var permission: CheckedContinuation<Int32,Never>?
    private var sample: CheckedContinuation<NativeCoordinate?,Never>?
    private var timeout: Task<Void,Never>?
    private var samplingManager: CLLocationManager?
    private var sampleStarted: Date?
    override init() { super.init();manager.delegate=self }
    func permissionStatus() -> Int32 {
        guard CLLocationManager.locationServicesEnabled() else { return 4 }
        switch manager.authorizationStatus { case .authorizedAlways,.authorizedWhenInUse:return 1;case .restricted:return 3;case .denied:return 2;default:return 0 }
    }
    func authorize() async -> Int32 {
        let status=permissionStatus();if status != 0 { return status }
        return await withCheckedContinuation { continuation in permission?.resume(returning:4);permission=continuation;manager.requestWhenInUseAuthorization() }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) { let status=permissionStatus();if status != 0 { permission?.resume(returning:status);permission=nil } }
    func cancel() { timeout?.cancel();timeout=nil;samplingManager?.delegate=nil;samplingManager?.stopUpdatingLocation();samplingManager=nil;sampleStarted=nil;sample?.resume(returning:nil);sample=nil;permission?.resume(returning:4);permission=nil }
    func read(timeoutMs:Int) async -> NativeCoordinate? {
        cancel();guard permissionStatus()==1 else { return nil }
        return await withCheckedContinuation { continuation in
            sample=continuation;sampleStarted=Date();let sampler=CLLocationManager();samplingManager=sampler;sampler.delegate=self;sampler.requestLocation()
            timeout=Task { @MainActor [weak self] in do { try await Task.sleep(nanoseconds:UInt64(timeoutMs)*1_000_000) } catch { return };self?.cancel() }
        }
    }
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard manager === samplingManager,let started=sampleStarted else { return }
        guard let location=locations.last,let coordinate=NativeCoordinate.from(location,notBefore:started) else { cancel();return }
        timeout?.cancel();timeout=nil;samplingManager?.delegate=nil;samplingManager=nil;sampleStarted=nil;let callback=sample;sample=nil;callback?.resume(returning:coordinate)
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) { guard manager === samplingManager else { return };cancel() }
}
struct NativeCoordinate {
    let latitude:Int32;let longitude:Int32;let accuracy:Int32
    static func from(_ location:CLLocation,notBefore:Date?=nil)->NativeCoordinate? {
        if let notBefore,location.timestamp < notBefore { return nil }
        guard location.horizontalAccuracy>=0,location.coordinate.latitude.isFinite,location.coordinate.longitude.isFinite,
              (-90...90).contains(location.coordinate.latitude),(-180...180).contains(location.coordinate.longitude),
              let lat=Int32(exactly:(location.coordinate.latitude*1_000_000).rounded()),
              let lon=Int32(exactly:(location.coordinate.longitude*1_000_000).rounded()),
              let accuracy=Int32(exactly:location.horizontalAccuracy.rounded(.up)) else { return nil }
        return NativeCoordinate(latitude:lat,longitude:lon,accuracy:accuracy)
    }
}
enum NativePermission {
    static func camera() async -> Int32 {
        guard AVCaptureDevice.default(for:.video) != nil else { return 4 }
        switch AVCaptureDevice.authorizationStatus(for:.video) {
        case .authorized:return 1
        case .denied:return 2
        case .restricted:return 3
        case .notDetermined:return await AVCaptureDevice.requestAccess(for:.video) ? 1 : 2
        @unknown default:return 4
        }
    }
}
final class NativeCamera: NSObject,ObservableObject,AVCapturePhotoCaptureDelegate {
    let session=AVCaptureSession()
    @Published private(set) var ready=false
    @Published private(set) var failed=false
    private let queue=DispatchQueue(label:"native.camera.session")
    private let output=AVCapturePhotoOutput()
    private var input:AVCaptureDeviceInput?
    private var facing:AVCaptureDevice.Position = .back
    private var active=false
    private var completion:((NativePhotoResult)->Void)?
    private var options:NativePhotoOptions?
    private var captureID:Int64?
    private var captureAngle:CGFloat=90
    func rotation(_ angle:CGFloat) { queue.async { self.captureAngle=angle } }
    private func status(_ ready:Bool,_ failed:Bool) { DispatchQueue.main.async { self.ready=ready;self.failed=failed } }
    func setActive(_ value:Bool) { queue.async {
        self.active=value
        if !value { if self.session.isRunning { self.session.stopRunning() };let callback=self.completion;self.completion=nil;self.options=nil;self.captureID=nil;DispatchQueue.main.async { callback?(.cancelled) };self.status(false,false);return }
        guard AVCaptureDevice.authorizationStatus(for:.video) == .authorized else { self.status(false,true);return }
        do { try self.configure();self.session.startRunning();self.status(true,false) } catch { self.status(false,true) }
    } }
    private func configure() throws {
        if input != nil { return }
        guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:facing) else { throw NativePhotoFailure.unavailable }
        let input=try AVCaptureDeviceInput(device:device)
        session.beginConfiguration();defer { session.commitConfiguration() };session.sessionPreset = .photo
        guard session.canAddInput(input),session.canAddOutput(output) else { throw NativePhotoFailure.unavailable }
        session.addInput(input);session.addOutput(output);self.input=input
    }
    func face(front:Bool,completion:@escaping(Bool)->Void) { queue.async {
        let position:AVCaptureDevice.Position=front ? .front : .back
        guard self.completion == nil else { DispatchQueue.main.async { completion(false) };return }
        guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:position),let replacement=try? AVCaptureDeviceInput(device:device) else { DispatchQueue.main.async { completion(false) };return }
        if self.input==nil { self.facing=position;DispatchQueue.main.async { completion(true) };return }
        self.session.beginConfiguration();defer { self.session.commitConfiguration() }
        let previous=self.input;if let previous { self.session.removeInput(previous) }
        if self.session.canAddInput(replacement) { self.session.addInput(replacement);self.input=replacement;self.facing=position;DispatchQueue.main.async { completion(true) } }
        else { if let previous { self.session.addInput(previous) };DispatchQueue.main.async { completion(false) } }
    } }
    func capture(options:NativePhotoOptions,completion:@escaping(NativePhotoResult)->Void) { queue.async {
        guard self.active,self.session.isRunning,self.completion==nil else { DispatchQueue.main.async { completion(.failed) };return }
        self.options=options;self.completion=completion
        let settings=AVCapturePhotoSettings();settings.flashMode = .off;self.captureID=settings.uniqueID
        if let connection=self.output.connection(with:.video),connection.isVideoRotationAngleSupported(self.captureAngle) { connection.videoRotationAngle=self.captureAngle }
        self.output.capturePhoto(with:settings,delegate:self)
    } }
    func cancelCapture() { queue.async { let callback=self.completion;self.completion=nil;self.options=nil;self.captureID=nil;DispatchQueue.main.async { callback?(.cancelled) } } }
    func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?) {
        queue.async {
            guard self.captureID==photo.resolvedSettings.uniqueID,let callback=self.completion,let options=self.options else { return }
            self.completion=nil;self.options=nil
            let result:NativePhotoResult
            do { guard error==nil,let data=photo.fileDataRepresentation() else { throw NativePhotoFailure.unavailable };result = .selected(try NativePhotoPreparation.prepare(data,options:options)) } catch { result = .failed }
            DispatchQueue.main.async { callback(result) }
        }
    }
}
final class NativePreviewUIView:UIView {
    weak var camera:NativeCamera?
    override class var layerClass:AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview:AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        let angle:CGFloat
        switch window?.windowScene?.interfaceOrientation { case .landscapeLeft:angle=0;case .landscapeRight:angle=180;case .portraitUpsideDown:angle=270;default:angle=90 }
        camera?.rotation(angle)
        if let connection=preview.connection,connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle=angle }
    }
}
struct NativePreviewSurface:UIViewRepresentable {
    let camera:NativeCamera;let fill:Bool
    func makeUIView(context:Context)->NativePreviewUIView { let view=NativePreviewUIView();view.camera=camera;view.preview.session=camera.session;view.preview.videoGravity=fill ? .resizeAspectFill : .resizeAspect;return view }
    func updateUIView(_ view:NativePreviewUIView,context:Context) { view.preview.videoGravity=fill ? .resizeAspectFill : .resizeAspect;view.setNeedsLayout() }
}
struct NativeCameraPreview<Loading:View,Failure:View>:View {
    @ObservedObject var camera:NativeCamera
    let active:Bool;@Binding var ready:Bool;let fill:Bool;let label:String
    @ViewBuilder let loading:()->Loading
    @ViewBuilder let failure:()->Failure
    @Environment(\.scenePhase) private var phase
    @State private var visible=false
    var body:some View {
        Group { if camera.ready { NativePreviewSurface(camera:camera,fill:fill).accessibilityLabel(label) } else if camera.failed { failure() } else { loading() } }
        .onAppear { visible=true;camera.setActive(active && phase == .active) }
        .onDisappear { visible=false;camera.setActive(false);ready=false }
        .onChange(of:active) { _,value in camera.setActive(value && visible && phase == .active) }
        .onChange(of:phase) { _,value in camera.setActive(active && visible && value == .active) }
        .onReceive(camera.$ready) { ready=$0 }
    }
}
'''


def emit(files):files['ios/App/Generated/NativeDevice.swift']=Artifact(HEADER+SWIFT+MAP)

MAP=r'''
struct NativeMapRegion:Equatable {
    let latitude:Int32;let longitude:Int32;let latitudeSpan:Int32;let longitudeSpan:Int32
    var region:MKCoordinateRegion { MKCoordinateRegion(center:CLLocationCoordinate2D(latitude:Double(latitude)/1_000_000,longitude:Double(longitude)/1_000_000),span:MKCoordinateSpan(latitudeDelta:Double(latitudeSpan)/1_000_000,longitudeDelta:Double(longitudeSpan)/1_000_000)) }
}
struct NativeMapItem { let id:String;let latitude:Int32;let longitude:Int32;let title:String;let content:AnyView }
final class NativeMapAnnotation:NSObject,MKAnnotation {
    var item:NativeMapItem
    var coordinate:CLLocationCoordinate2D { CLLocationCoordinate2D(latitude:Double(item.latitude)/1_000_000,longitude:Double(item.longitude)/1_000_000) }
    var title:String? { item.title }
    init(_ item:NativeMapItem) { self.item=item }
}
final class NativeMapAnnotationView:MKAnnotationView {
    var host:UIHostingController<AnyView>?
    func update(_ annotation:NativeMapAnnotation) {
        self.annotation=annotation
        if let host { host.rootView=annotation.item.content }
        else { let host=UIHostingController(rootView:annotation.item.content);host.sizingOptions = .intrinsicContentSize;host.view.backgroundColor = .clear;addSubview(host.view);self.host=host }
        guard let view=host?.view else { return };view.invalidateIntrinsicContentSize();let size=view.intrinsicContentSize
        view.frame=CGRect(origin:.zero,size:CGSize(width:max(1,size.width),height:max(1,size.height)));frame=view.frame
        accessibilityLabel=annotation.item.title
    }
}
struct NativeMapSurface:UIViewRepresentable {
    let items:[NativeMapItem];let region:NativeMapRegion;@Binding var phase:Int
    func makeCoordinator()->Coordinator { Coordinator() }
    func makeUIView(context:Context)->MKMapView { let map=MKMapView();map.delegate=context.coordinator;map.showsUserLocation=false;return map }
    func updateUIView(_ map:MKMapView,context:Context) {
        let coordinator=context.coordinator;coordinator.updatePhase={ value in DispatchQueue.main.async { phase=value } }
        if coordinator.region != region { map.setRegion(region.region,animated:false);coordinator.region=region }
        // Records and annotation view closures are native typed values; no UI graph is interpreted.
        let existing=map.annotations.compactMap { $0 as? NativeMapAnnotation }
        let byID=Dictionary(uniqueKeysWithValues:existing.map { ($0.item.id,$0) })
        let ids=Set(items.map { $0.id });map.removeAnnotations(existing.filter { !ids.contains($0.item.id) })
        for item in items {
            if let annotation=byID[item.id],annotation.item.latitude==item.latitude,annotation.item.longitude==item.longitude {
                annotation.item=item;(map.view(for:annotation) as? NativeMapAnnotationView)?.update(annotation)
            } else {
                if let previous=byID[item.id] { map.removeAnnotation(previous) };map.addAnnotation(NativeMapAnnotation(item))
            }
        }
    }
    static func dismantleUIView(_ map:MKMapView,coordinator:Coordinator) { map.delegate=nil;coordinator.updatePhase=nil;map.removeAnnotations(map.annotations) }
    final class Coordinator:NSObject,MKMapViewDelegate {
        var region:NativeMapRegion?;var updatePhase:((Int)->Void)?
        func mapViewWillStartLoadingMap(_ mapView:MKMapView) { updatePhase?(0) }
        func mapViewDidFinishLoadingMap(_ mapView:MKMapView) { updatePhase?(1) }
        func mapViewDidFailLoadingMap(_ mapView:MKMapView,withError error:Error) { updatePhase?(2) }
        func mapView(_ mapView:MKMapView,viewFor annotation:MKAnnotation)->MKAnnotationView? {
            guard let annotation=annotation as? NativeMapAnnotation else { return nil }
            let view=(mapView.dequeueReusableAnnotationView(withIdentifier:"native.annotation") as? NativeMapAnnotationView) ?? NativeMapAnnotationView(annotation:annotation,reuseIdentifier:"native.annotation")
            view.update(annotation);return view
        }
    }
}
struct NativeAuthoredMap<Loading:View,Failure:View>:View {
    let items:[NativeMapItem];let region:NativeMapRegion
    @ViewBuilder let loading:()->Loading
    @ViewBuilder let failure:()->Failure
    @State private var phase=0
    private var valid:Bool { items.allSatisfy { (-85_051_128...85_051_128).contains($0.latitude) && (-180_000_000...180_000_000).contains($0.longitude) } }
    var body:some View { if valid { ZStack { NativeMapSurface(items:items,region:region,phase:$phase);if phase==0 { loading() };if phase==2 { failure() } } } else { failure() } }
}
'''
