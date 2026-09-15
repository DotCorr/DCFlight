import SwiftUI
import AVFoundation
import PhotosUI
import ImageIO

struct PhotoDraft:Identifiable { let id=UUID();let data:Data }
enum PhotoPreparation {
    static func jpeg(_ data:Data) throws -> Data {
        guard let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              let thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:2048,kCGImageSourceShouldCacheImmediately:true] as CFDictionary)
        else{throw ServiceFailure(message:"Choose a still photo in a supported format.")}
        let normalized=UIImage(cgImage:thumbnail)
        guard let jpeg=normalized.jpegData(compressionQuality:0.85),SocialPolicy.canUpload(bytes:jpeg.count) else{throw ServiceFailure(message:"This photo is too large to upload.")}
        return jpeg
    }
}
final class CameraEngine:NSObject,ObservableObject,AVCapturePhotoCaptureDelegate {
    let session=AVCaptureSession()
    private let queue=DispatchQueue(label:"application.camera")
    private let output=AVCapturePhotoOutput()
    private var input:AVCaptureDeviceInput?
    private var front=false
    private var wantsRunning=false
    @Published var ready=false
    @Published var error:String?
    @Published var denied=false
    @Published var draft:PhotoDraft?
    @Published var capturing=false
    func start() {
        queue.async{self.wantsRunning=true}
        Task {
            let status=AVCaptureDevice.authorizationStatus(for:.video)
            var allowed=status == .authorized
            if status == .notDetermined { allowed=await AVCaptureDevice.requestAccess(for:.video) }
            guard allowed else{DispatchQueue.main.async{self.denied=true;self.error="Camera access is off. Enable it in Settings, or choose a photo from your library."};return}
            queue.async{guard self.wantsRunning else{return};do{try self.configure();self.session.startRunning();DispatchQueue.main.async{self.ready=true;self.error=nil}}catch{DispatchQueue.main.async{self.error=error.localizedDescription}}}
        }
    }
    private func configure() throws {
        guard input == nil else{return}
        guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:front ? .front : .back) else{throw ServiceFailure(message:"A camera is not available on this device. You can still choose a photo from your library.")}
        let newInput=try AVCaptureDeviceInput(device:device)
        session.beginConfiguration();defer{session.commitConfiguration()};session.sessionPreset = .photo
        guard session.canAddInput(newInput),session.canAddOutput(output) else{throw ServiceFailure(message:"The camera could not be started.")}
        session.addInput(newInput);input=newInput;session.addOutput(output)
    }
    func stop(){queue.async{self.wantsRunning=false;if self.session.isRunning{self.session.stopRunning()};DispatchQueue.main.async{self.ready=false}}}
    func flip(){queue.async{
        guard let old=self.input else{return};self.session.beginConfiguration();defer{self.session.commitConfiguration()}
        guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:self.front ? .back : .front),let replacement=try? AVCaptureDeviceInput(device:device) else{return}
        self.session.removeInput(old)
        if self.session.canAddInput(replacement){self.session.addInput(replacement);self.input=replacement;self.front.toggle()}else{self.session.addInput(old)}
    }}
    func capture(){guard ready,!capturing else{return};capturing=true;queue.async{let settings=AVCapturePhotoSettings();settings.flashMode = .off;self.output.capturePhoto(with:settings,delegate:self)}}
    func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?){
        DispatchQueue.main.async{
            self.capturing=false
            do{if let error{throw error};guard let data=photo.fileDataRepresentation() else{throw ServiceFailure(message:"The photo could not be captured.")};self.draft=PhotoDraft(data:try PhotoPreparation.jpeg(data))}
            catch{self.error=error.localizedDescription}
        }
    }
}
final class CameraPreviewSurface:UIView {
    override class var layerClass:AnyClass{AVCaptureVideoPreviewLayer.self}
    var preview:AVCaptureVideoPreviewLayer{layer as! AVCaptureVideoPreviewLayer}
    override func layoutSubviews(){super.layoutSubviews();if let connection=preview.connection,connection.isVideoRotationAngleSupported(90){connection.videoRotationAngle=90}}
}
struct CameraPreview:UIViewRepresentable {
    let session:AVCaptureSession
    func makeUIView(context:Context)->CameraPreviewSurface{let view=CameraPreviewSurface();view.preview.session=session;view.preview.videoGravity = .resizeAspectFill;return view}
    func updateUIView(_ view:CameraPreviewSurface,context:Context){}
}
struct CameraScreen:View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera=CameraEngine()
    @State private var photo:PhotosPickerItem?
    @State private var libraryError:String?
    @State private var work:Task<Void,Never>?
    var body:some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session:camera.session).ignoresSafeArea(edges:.top)
            VStack(spacing:20) {
                HStack{Text(SocialConfiguration.appName).font(.system(size:30,weight:.heavy,design:.rounded)).tracking(-1);Spacer();Button{camera.flip()}label:{Image(systemName:"arrow.triangle.2.circlepath.camera").font(.title2).padding(14).background(.black.opacity(0.35),in:Circle())}.disabled(!camera.ready).accessibilityLabel("Flip camera")}.padding(.horizontal,22).padding(.top,20)
                Spacer()
                if let error=libraryError ?? camera.error {
                    VStack(spacing:14){Image(systemName:"camera").font(.largeTitle);Text(error).font(.subheadline).multilineTextAlignment(.center);if camera.denied{Button("Open Settings"){if let url=URL(string:UIApplication.openSettingsURLString){UIApplication.shared.open(url)}}.buttonStyle(.bordered)}else{Button("Try camera again"){camera.start()}.buttonStyle(.bordered)}}.padding(24).background(.black.opacity(0.6),in:RoundedRectangle(cornerRadius:24)).padding(.horizontal,24)
                }
                Spacer()
                Text("A moment worth sharing.").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                HStack(spacing:40){
                    PhotosPicker(selection:$photo,matching:.images){Image(systemName:"photo.on.rectangle").font(.title2).frame(width:54,height:54).background(.black.opacity(0.35),in:Circle())}.accessibilityLabel("Choose a photo")
                    Button{camera.capture()}label:{ZStack{Circle().stroke(.white,lineWidth:5).frame(width:84,height:84);Circle().fill(camera.ready ? .white : .gray).frame(width:68,height:68);if camera.capturing{ProgressView().tint(.black)}}}.disabled(!camera.ready || camera.capturing).accessibilityLabel("Take photo")
                    Color.clear.frame(width:54,height:54).accessibilityHidden(true)
                }.padding(.bottom,28)
            }
        }.foregroundStyle(.white).onAppear{if scenePhase == .active{camera.start()}}.onDisappear{camera.stop();work?.cancel()}
        .onChange(of:scenePhase){_,phase in if phase == .active{camera.start()}else{camera.stop()}}
        .onChange(of:photo){_,item in work=Task{do{if let data=try await item?.loadTransferable(type:Data.self){camera.draft=PhotoDraft(data:try PhotoPreparation.jpeg(data));libraryError=nil}}catch{libraryError=error.localizedDescription}}}
        .sheet(item:$camera.draft){draft in MediaComposer(draft:draft,onComplete:{camera.draft=nil})}
    }
}
struct MediaComposer:View {
    @EnvironmentObject var session:SocialSession
    @Environment(\.dismiss) private var dismiss
    let draft:PhotoDraft
    var conversationID:String?=nil
    var onComplete:()->Void
    @State private var caption=""
    @State private var conversations:[Conversation]=[]
    @State private var selected=""
    @State private var busy=false
    @State private var error:String?
    @FocusState private var captionFocused:Bool
    @State private var uploadedID:String?
    @State private var work:Task<Void,Never>?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:20) {
                    if let image=UIImage(data:draft.data){Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius:22)).accessibilityLabel("Photo preview")}
                    TextField("Add a caption",text:$caption,axis:.vertical).focused($captionFocused).accessibilityIdentifier("photo.caption").lineLimit(1...4).padding(16).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:16))
                    if let error{FailureBanner(message:error)}
                    if conversationID != nil {action("Send photo",icon:"paperplane"){await send(story:false)}}
                    else {
                        action("Share to your story",icon:"circle.dashed"){await send(story:true)}
                        Text("Visible to friends for 24 hours").font(.caption).foregroundStyle(SocialTheme.muted)
                        Picker("Send to a conversation",selection:$selected){Text("Choose a conversation").tag("");ForEach(conversations){Text($0.displayName ?? $0.username ?? "Conversation").tag($0.id)}}.pickerStyle(.menu)
                        action("Send privately",icon:"lock"){await send(story:false)}.disabled(selected.isEmpty)
                        if conversations.isEmpty{Text("Start a conversation from Friends in the chat tab to send privately.").font(.footnote).foregroundStyle(SocialTheme.muted)}
                    }
                }.padding(SocialTheme.padding)
            }.scrollDismissesKeyboard(.interactively).background(SocialTheme.background).navigationTitle("Your photo").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){work?.cancel();dismiss()}};ToolbarItemGroup(placement:.keyboard){Spacer();Button("Done"){captionFocused=false}}}
            .task{if conversationID==nil{do{let reply:ConversationsReply=try await session.request("/v1/conversations");conversations=reply.conversations}catch{self.error=error.localizedDescription}}}
            .onDisappear{work?.cancel()}
        }
    }
    func action(_ title:String,icon:String,operation:@escaping () async ->Void)->some View{Button{work=Task{await operation()}}label:{HStack{Spacer();if busy{ProgressView()}else{Label(title,systemImage:icon).font(.headline)};Spacer()}.padding(17)}.background(SocialTheme.accent,in:RoundedRectangle(cornerRadius:16)).disabled(busy)}
    func send(story:Bool) async{
        guard SocialPolicy.canUpload(bytes:draft.data.count) else{error="This photo is too large.";return}
        if !story && !SocialPolicy.canSend(text:caption,hasPhoto:true){error="Shorten your message before sending.";return}
        if story && caption.unicodeScalars.count>240{error="Caption: use no more than 240 characters.";return}
        captionFocused=false;busy=true;defer{busy=false}
        do{
            let media:String
            if let uploadedID{media=uploadedID}else{media=try await session.upload(draft.data);uploadedID=media}
            try Task.checkCancellation()
            if story{_ = try await session.requestData("/v1/stories",method:"POST",body:["media_id":media,"caption":caption])}
            else{_ = try await session.requestData("/v1/conversations/"+(conversationID ?? selected)+"/messages",method:"POST",body:["media_id":media,"text":caption])}
            onComplete();dismiss()
        }catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
}
