import SwiftUI
import CoreLocation
import MapKit
@main struct NativeDeviceVerification {
    @MainActor static func main() async throws {
        var passed=[String]()
        func check(_ name:String,_ condition:Bool) { precondition(condition,name);passed.append(name) }
        func location(_ lat:Double,_ lon:Double,_ accuracy:Double)->CLLocation { CLLocation(coordinate:CLLocationCoordinate2D(latitude:lat,longitude:lon),altitude:0,horizontalAccuracy:accuracy,verticalAccuracy:0,timestamp:Date()) }
        let coordinate=NativeCoordinate.from(location(52.1234564,4.1234566,4.2))!
        check("coordinate-microdegrees",coordinate.latitude==52123456 && coordinate.longitude==4123457)
        check("accuracy-rounds-up",coordinate.accuracy==5)
        let positive=NativeCoordinate.from(location(0.0000005,0.0000005,0))!
        let negative=NativeCoordinate.from(location(-0.0000005,-0.0000005,0))!
        check("positive-half-away",positive.latitude==1 && positive.longitude==1)
        check("negative-half-away",negative.latitude == -1 && negative.longitude == -1)
        check("invalid-latitude-rejected",NativeCoordinate.from(location(91,0,1))==nil)
        check("invalid-longitude-rejected",NativeCoordinate.from(location(0,181,1))==nil)
        check("invalid-accuracy-rejected",NativeCoordinate.from(location(0,0,-1))==nil)
        check("accuracy-overflow-rejected",NativeCoordinate.from(location(0,0,Double(Int32.max)+1))==nil)
        let started=Date()
        let old=CLLocation(coordinate:CLLocationCoordinate2D(latitude:52,longitude:4),altitude:0,horizontalAccuracy:1,verticalAccuracy:1,timestamp:started.addingTimeInterval(-1))
        let fresh=CLLocation(coordinate:CLLocationCoordinate2D(latitude:52,longitude:4),altitude:0,horizontalAccuracy:1,verticalAccuracy:1,timestamp:started)
        check("previous-read-location-rejected",NativeCoordinate.from(old,notBefore:started)==nil)
        check("fresh-read-location-accepted",NativeCoordinate.from(fresh,notBefore:started) != nil)
        let region=NativeMapRegion(latitude:52000000,longitude:4000000,latitudeSpan:2000000,longitudeSpan:3000000).region
        check("authored-map-region",region.center.latitude==52 && region.center.longitude==4 && region.span.latitudeDelta==2 && region.span.longitudeDelta==3)
        let marker=NativeMapAnnotation(NativeMapItem(id:"shared-id",latitude:52000000,longitude:4000000,title:"Shared marker",content:AnyView(Text("Shared marker").padding(8))))
        let view=NativeMapAnnotationView(annotation:marker,reuseIdentifier:"test");view.update(marker)
        check("authored-marker-label",view.accessibilityLabel=="Shared marker")
        check("authored-marker-native-host",view.host != nil && view.frame.width>50 && view.frame.height>20)
        let permission=await NativePermission.camera()
        check("simulator-camera-unavailable",permission==4)
        let camera=NativeCamera()
        let capture=await withCheckedContinuation { continuation in camera.capture(options:NativePhotoOptions(maxInputBytes:1000,maxPixels:1000,maxEdge:32,qualityPercent:85,maxOutputBytes:1000)) { value in continuation.resume(returning:value) } }
        if case .failed=capture { passed.append("inactive-capture-fails") } else { fatalError("inactive capture accepted") }
        let facing=await withCheckedContinuation { continuation in camera.face(front:true) { continuation.resume(returning:$0) } }
        check("unavailable-facing-fails",!facing)
        camera.setActive(false)
        let data=try JSONSerialization.data(withJSONObject:["passed":passed,"passedCount":passed.count,"failure":NSNull(),"hardwareCaptureTested":false],options:[.sortedKeys]);print(String(decoding:data,as:UTF8.self))
    }
}
