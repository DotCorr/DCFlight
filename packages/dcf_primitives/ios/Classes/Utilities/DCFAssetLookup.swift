import Foundation
import Flutter

enum DCFAssetLookup {
    static func key(forAsset asset: String, fromPackage package: String? = nil) -> String {
        if let package {
            return FlutterDartProject.lookupKey(forAsset: asset, fromPackage: package)
        }

        return FlutterDartProject.lookupKey(forAsset: asset)
    }

    static func path(forAsset asset: String, fromPackage package: String? = nil) -> String? {
        let assetKey = key(forAsset: asset, fromPackage: package)
        return Bundle.main.path(forResource: assetKey, ofType: nil)
    }
}