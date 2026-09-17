import SwiftUI
import ImageIO
import UniformTypeIdentifiers

struct IntegrationFailure:Error {let message:String}
@MainActor final class NativeIntegration {
    var passed:[String]=[]
    var cleanup:[SocialSession]=[]
    let password="Native-test-only-9346"
    func check(_ condition:Bool,_ name:String) throws {
        guard condition else{throw IntegrationFailure(message:name)}
        passed.append(name)
    }
    func execute() async {
        var failure:String?
        do{try await verify()}catch{failure=(error as? IntegrationFailure)?.message ?? error.localizedDescription}
        var cleanupFailures=0
        for session in cleanup {
            do{_ = try await session.requestData("/v1/me",method:"DELETE",body:["password":password])}catch{cleanupFailures+=1}
        }
        SessionKeychain.clear()
        let report:[String:Any]=["passed":passed,"passedCount":passed.count,"failure":failure as Any? ?? NSNull(),"cleanupFailures":cleanupFailures,"nativeHost":true,"uiAutomation":false,"bundleID":Bundle.main.bundleIdentifier ?? "","platform":"iOS Simulator"]
        let location=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("integration-report.json")
        do{try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:location,options:.atomic)}catch{print("Native test report write failed")}
    }
    func verify() async throws {
        SessionKeychain.clear()
        let suffix=UUID().uuidString.replacingOccurrences(of:"-",with:"").prefix(12).lowercased()
        let a=SocialSession(),b=SocialSession(),stranger=SocialSession()
        try await a.authenticate(username:"ia_"+suffix,password:password,displayName:"Native A",register:true);cleanup.append(a)
        try check(a.user?.displayName=="Native A","native registration and snake_case user decoding")
        let token=a.token!
        try check(SessionKeychain.read()==token,"signed native Keychain save and read")
        let restored=SocialSession();await restored.restore()
        try check(restored.user?.id==a.user?.id,"native session restoration through URLSession")
        try await b.authenticate(username:"ib_"+suffix,password:password,displayName:"Native B",register:true);cleanup.append(b)
        try await stranger.authenticate(username:"ic_"+suffix,password:password,displayName:"Native C",register:true);cleanup.append(stranger)
        let search:UsersReply=try await a.request("/v1/users?q=ib_"+suffix)
        try check(search.users.contains(where:{$0.id==b.user?.id}),"user search native decoder")
        _ = try await a.requestData("/v1/friend-requests",method:"POST",body:["user_id":b.user!.id])
        let incoming:RequestsReply=try await b.request("/v1/friend-requests")
        guard let request=incoming.requests.first(where:{$0.sender==a.user?.id}) else{throw IntegrationFailure(message:"friend request absent")}
        _ = try await b.requestData("/v1/friend-requests/"+request.id+"/accept",method:"POST")
        let friends:FriendsReply=try await a.request("/v1/friends")
        try check(friends.friends.contains(where:{$0.id==b.user?.id}),"friend request and acceptance with independent native sessions")
        let conversation:Conversation=try await a.request("/v1/conversations",method:"POST",body:["user_id":b.user!.id])
        let sent:ChatMessage=try await a.request("/v1/conversations/"+conversation.id+"/messages",method:"POST",body:["text":"Native hello 👋"])
        let messages:MessagesReply=try await b.request("/v1/conversations/"+conversation.id+"/messages?after=0")
        try check(messages.messages.contains(where:{$0.id==sent.id && $0.text=="Native hello 👋"}),"native text message send and recipient polling")
        let after:MessagesReply=try await b.request("/v1/conversations/"+conversation.id+"/messages?after="+String(sent.id))
        try check(after.messages.isEmpty,"incremental message cursor")
        try check(SocialPolicy.canSend(text:"  👋  ",hasPhoto:false),"shared Unicode message policy")
        try check(!SocialPolicy.canSend(text:"  \n",hasPhoto:false) && SocialPolicy.canSend(text:"",hasPhoto:true),"shared empty and photo-only message boundaries")
        try check(SocialPolicy.canSend(text:String(repeating:"x",count:2000),hasPhoto:false) && !SocialPolicy.canSend(text:String(repeating:"x",count:2001),hasPhoto:false),"shared message length boundary")
        try check(!SocialPolicy.canUpload(bytes:0) && SocialPolicy.canUpload(bytes:1) && SocialPolicy.canUpload(bytes:8_388_608) && !SocialPolicy.canUpload(bytes:8_388_609),"shared upload byte boundaries")
        try check(SocialPolicy.shouldPublish(consent:true,permission:true) && !SocialPolicy.shouldPublish(consent:false,permission:true) && !SocialPolicy.shouldPublish(consent:true,permission:false),"shared location consent policy")
        let normalized=try photo()
        let media=try await a.upload(normalized)
        let own=try await a.requestData("/v1/media/"+media)
        try check(UIImage(data:own) != nil,"raw authenticated photo upload and download")
        var privateDenied=false
        do{_ = try await stranger.requestData("/v1/media/"+media)}catch is ServiceFailure{privateDenied=true}
        try check(privateDenied,"private media denies unrelated native session")
        let photoMessage:ChatMessage=try await a.request("/v1/conversations/"+conversation.id+"/messages",method:"POST",body:["text":"Photo","media_id":media])
        let received:MessagesReply=try await b.request("/v1/conversations/"+conversation.id+"/messages?after="+String(sent.id))
        try check(received.messages.contains(where:{$0.id==photoMessage.id && $0.mediaId==media}),"native photo message decoding")
        let shared=try await b.requestData("/v1/media/"+media)
        try check(UIImage(data:shared) != nil,"conversation participant authenticated photo access")
        let story:Story=try await a.request("/v1/stories",method:"POST",body:["media_id":media,"caption":"Native moment"])
        let feed:StoriesReply=try await b.request("/v1/stories")
        try check(feed.stories.contains(where:{$0.id==story.id}),"friend story feed native decoding")
        try check(SocialPolicy.remaining(story:story,now:Date(timeIntervalSince1970:Double(story.createdAt)))==86400 && SocialPolicy.remaining(story:story,now:Date(timeIntervalSince1970:Double(story.createdAt+86400)))==0,"shared story expiry boundaries")
        _ = try await a.requestData("/v1/stories/"+story.id,method:"DELETE")
        let removed:StoriesReply=try await b.request("/v1/stories")
        try check(!removed.stories.contains(where:{$0.id==story.id}),"story deletion")
        let detail:[[String:Any]]=[["loc":["body","password"],"msg":"Too short","input":"DO-NOT-ECHO"]]
        try check(ServiceValidation.message(detail)=="Password: Too short","native validation redacts request inputs")
        var validation=false
        do{_ = try await a.requestData("/v1/auth/login",method:"POST",body:["username":"a.b","password":password],authenticated:false)}catch{validation=error.localizedDescription.contains("Username:") && !error.localizedDescription.contains(password)}
        try check(validation,"real backend validation becomes readable native field error")
        try await a.authenticate(username:"ia_"+suffix,password:password,displayName:nil,register:false)
        try check(a.user != nil,"native login")
    }
    func photo() throws -> Data {
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:4096,height:1024),format:format).image{context in UIColor.systemBlue.setFill();context.fill(CGRect(x:0,y:0,width:4096,height:1024))}
        let original=NSMutableData()
        guard let destination=CGImageDestinationCreateWithData(original,UTType.jpeg.identifier as CFString,1,nil),let pixels=image.cgImage else{throw IntegrationFailure(message:"photo fixture failed")}
        CGImageDestinationAddImage(destination,pixels,[kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:52.0,kCGImagePropertyGPSLatitudeRef:"N",kCGImagePropertyGPSLongitude:4.0,kCGImagePropertyGPSLongitudeRef:"E"],kCGImagePropertyExifDictionary:[kCGImagePropertyExifUserComment:"private fixture"]] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else{throw IntegrationFailure(message:"photo fixture encoding failed")}
        let normalized=try PhotoPreparation.jpeg(original as Data)
        guard let source=CGImageSourceCreateWithData(normalized as CFData,nil),let metadata=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any] else{throw IntegrationFailure(message:"photo normalization failed")}
        try check((metadata[kCGImagePropertyPixelWidth] as? Int)==2048 && (metadata[kCGImagePropertyPixelHeight] as? Int)==512,"actual ImageIO photo downsampling")
        try check(metadata[kCGImagePropertyGPSDictionary]==nil && (metadata[kCGImagePropertyExifDictionary] as? [CFString:Any])?[kCGImagePropertyExifUserComment]==nil,"actual photo GPS and EXIF stripping")
        return normalized
    }
}
@main struct IntegrationApp:App {
    @State private var started=false
    var body:some Scene{WindowGroup{Text("Native integration verification").task{guard !started else{return};started=true;await NativeIntegration().execute()}}}
}
