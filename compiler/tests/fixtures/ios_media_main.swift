import UIKit
import ImageIO
import UniformTypeIdentifiers

@main struct MediaVerification {
    static func main() throws {
        var passed=[String]()
        func check(_ name:String,_ condition:Bool) { precondition(condition,name);passed.append(name) }
        func rejects(_ name:String,_ operation:() throws -> Void) { do { try operation();fatalError(name) } catch { passed.append(name) } }
        let image=UIGraphicsImageRenderer(size:CGSize(width:400,height:200)).image { context in UIColor.red.setFill();context.fill(CGRect(x:0,y:0,width:400,height:200)) }
        let tagged=NSMutableData();let destination=CGImageDestinationCreateWithData(tagged,UTType.jpeg.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(destination,image.cgImage!,[kCGImagePropertyOrientation:6,kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:52.0,kCGImagePropertyGPSLongitude:4.0],kCGImagePropertyExifDictionary:[kCGImagePropertyExifUserComment:"private-metadata"]] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        let options=NativePhotoOptions(maxInputBytes:1_000_000,maxPixels:1_000_000,maxEdge:100,qualityPercent:85,maxOutputBytes:1_000_000)
        let prepared=try NativePhotoPreparation.prepare(tagged as Data,options:options)
        check("orientation-applied",prepared.width==50 && prepared.height==100)
        check("bounded-output",prepared.byteLength>0 && prepared.byteLength<=1_000_000)
        check("jpeg-mime",prepared.mimeType=="image/jpeg")
        let transparent=UIGraphicsImageRenderer(size:CGSize(width:10,height:10)).image { _ in }
        let white=try NativePhotoPreparation.prepare(transparent.pngData()!,options:options)
        let whiteImage=UIImage(data:white.data)!.cgImage!
        let canvas=CGContext(data:nil,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        canvas.draw(whiteImage,in:CGRect(x:0,y:0,width:1,height:1));let pixel=canvas.data!.assumingMemoryBound(to:UInt8.self)
        check("transparent-white-matte",pixel[0]>240 && pixel[1]>240 && pixel[2]>240)
        let normalized=CGImageSourceCreateWithData(prepared.data as CFData,nil)!
        let metadata=CGImageSourceCopyPropertiesAtIndex(normalized,0,nil)! as NSDictionary
        check("gps-stripped",metadata[kCGImagePropertyGPSDictionary]==nil)
        let exif=metadata[kCGImagePropertyExifDictionary] as? NSDictionary
        check("private-exif-stripped",exif?[kCGImagePropertyExifUserComment]==nil)
        rejects("malformed-rejected") { _ = try NativePhotoPreparation.prepare(Data("not an image".utf8),options:options) }
        rejects("input-limit") { _ = try NativePhotoPreparation.prepare(tagged as Data,options:NativePhotoOptions(maxInputBytes:1,maxPixels:1_000_000,maxEdge:100,qualityPercent:85,maxOutputBytes:1_000_000)) }
        rejects("pixel-limit-before-decode") { _ = try NativePhotoPreparation.prepare(tagged as Data,options:NativePhotoOptions(maxInputBytes:1_000_000,maxPixels:50,maxEdge:100,qualityPercent:85,maxOutputBytes:1_000_000)) }
        rejects("output-limit") { _ = try NativePhotoPreparation.prepare(tagged as Data,options:NativePhotoOptions(maxInputBytes:1_000_000,maxPixels:1_000_000,maxEdge:100,qualityPercent:85,maxOutputBytes:1)) }
        let animated=NSMutableData();let gif=CGImageDestinationCreateWithData(animated,UTType.gif.identifier as CFString,2,nil)!
        CGImageDestinationAddImage(gif,image.cgImage!,nil);CGImageDestinationAddImage(gif,image.cgImage!,nil);precondition(CGImageDestinationFinalize(gif))
        rejects("multiple-frames-rejected") { _ = try NativePhotoPreparation.prepare(animated as Data,options:options) }
        let file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try Data(repeating:1,count:11).write(to:file);defer { try? FileManager.default.removeItem(at:file) }
        rejects("bounded-provider-read") { _ = try NativePhotoPreparation.read(file,maximum:10) }
        let data=try JSONSerialization.data(withJSONObject:["passed":passed,"passedCount":passed.count,"failure":NSNull()],options:[.sortedKeys]);print(String(decoding:data,as:UTF8.self))
    }
}
