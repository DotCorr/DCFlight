import Foundation
import UIKit
import MapKit
@main struct MapLoadingVerification {
    @MainActor static func main() async {
        let options=MKMapSnapshotter.Options()
        options.region=NativeMapRegion(latitude:0,longitude:0,latitudeSpan:160000000,longitudeSpan:360000000).region
        options.size=CGSize(width:512,height:512);options.scale=1;options.mapType = .standard
        let snapshotter=MKMapSnapshotter(options:options)
        let deadline=Task { @MainActor in do { try await Task.sleep(nanoseconds:35_000_000_000) } catch { return };snapshotter.cancel() }
        var report:[String:Any]=["status":"failed","productMapUIVerified":false,"sdk":"MapKit","mapType":"standard","region":"authored world bounds"]
        do {
            let snapshot=try await snapshotter.start()
            guard let data=snapshot.image.pngData(),snapshot.image.size.width==512,snapshot.image.size.height==512 else { throw NSError(domain:"MapFixture",code:1) }
            try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
            report["status"]="rendered";report["renderedBytes"]=data.count;report["width"]=512;report["height"]=512
        } catch { let ns=error as NSError;report["errorDomain"]=ns.domain;report["errorCode"]=ns.code }
        deadline.cancel()
        if let data=try? JSONSerialization.data(withJSONObject:report,options:.sortedKeys) { print(String(decoding:data,as:UTF8.self)) }
    }
}
