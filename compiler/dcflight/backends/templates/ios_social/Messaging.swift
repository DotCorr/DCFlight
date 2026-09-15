import SwiftUI
import PhotosUI

struct InboxScreen:View {
    @EnvironmentObject var session:SocialSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var conversations:[Conversation]=[]
    @State private var path:[String]=[]
    @State private var showFriends=false
    @State private var error:String?
    @State private var loaded=false
    var body:some View {
        NavigationStack(path:$path) {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    HStack{Text("Keep the conversation going.").font(.title3.weight(.medium));Spacer();Button{showFriends=true}label:{Image(systemName:"square.and.pencil").font(.title2)}.accessibilityLabel("New chat").accessibilityIdentifier("chats.create")}
                    if let error {FailureBanner(message:error,retry:{Task{await load()}})}
                    if !loaded {ProgressView().frame(maxWidth:.infinity).padding(40)}
                    if loaded && conversations.isEmpty {ContentUnavailableView("Start with a friend",systemImage:"bubble.left.and.bubble.right",description:Text("Add a friend and share your first message or photo."));Button("Find friends"){showFriends=true}.buttonStyle(.borderedProminent).frame(maxWidth:.infinity)}
                    ForEach(conversations) { conversation in
                        NavigationLink(value:conversation.id) {
                            HStack(spacing:14){PersonAvatar(name:conversation.displayName ?? conversation.username ?? "Friend");VStack(alignment:.leading,spacing:5){Text(conversation.displayName ?? conversation.username ?? "Conversation").font(.headline);Text("Tap to catch up").font(.subheadline).foregroundStyle(SocialTheme.muted)};Spacer();Image(systemName:"chevron.right").font(.caption.bold()).foregroundStyle(SocialTheme.muted)}.padding(18).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:SocialTheme.radius))
                        }.buttonStyle(.plain)
                    }
                }.padding(SocialTheme.padding)
            }.background(SocialTheme.background).navigationTitle("Chats").navigationDestination(for:String.self){ConversationScreen(id:$0)}
            .sheet(isPresented:$showFriends){NavigationStack{FriendsScreen(onConversation:{id in showFriends=false;path.append(id)}).toolbar{ToolbarItem(placement:.cancellationAction){Button("Done"){showFriends=false}}}}}
            .task(id:scenePhase){guard scenePhase == .active else{return};await load();while !Task.isCancelled{do{try await Task.sleep(for:.seconds(5))}catch{return};await load()}}
            .refreshable{await load()}
            .onAppear{if let route=session.conversationRoute{path=[route];session.conversationRoute=nil}}
            .onChange(of:session.conversationRoute){_,route in if let route {path=[route];session.conversationRoute=nil}}
        }
    }
    func load() async {do{let reply:ConversationsReply=try await session.request("/v1/conversations");conversations=reply.conversations;error=nil;loaded=true}catch is CancellationError{}catch{self.error=error.localizedDescription;loaded=true}}
}

struct ConversationScreen:View {
    @EnvironmentObject var session:SocialSession
    @Environment(\.scenePhase) private var scenePhase
    let id:String
    @State private var messages:[ChatMessage]=[]
    @State private var text=""
    @State private var busy=false
    @State private var error:String?
    @State private var photo:PhotosPickerItem?
    @State private var draft:PhotoDraft?
    @State private var work:Task<Void,Never>?
    var body:some View {
        VStack(spacing:0) {
            if let error {FailureBanner(message:error,retry:{Task{await load()}}).padding(12)}
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing:12) {
                        ForEach(messages) { message in
                            HStack(alignment:.bottom) {
                                if message.sender==session.user?.id {Spacer(minLength:40)}
                                VStack(alignment:.leading,spacing:8) {
                                    if let media=message.mediaId {AuthenticatedMedia(id:media).frame(maxWidth:250).clipShape(RoundedRectangle(cornerRadius:16))}
                                    if !message.text.isEmpty {Text(message.text).textSelection(.enabled)}
                                    Text(Date(timeIntervalSince1970:Double(message.createdAt)),style:.time).font(.caption2).foregroundStyle(SocialTheme.muted)
                                }.padding(14).background(message.sender==session.user?.id ? SocialTheme.accent : SocialTheme.surface,in:RoundedRectangle(cornerRadius:20)).id(message.id)
                                if message.sender != session.user?.id {Spacer(minLength:40)}
                            }
                        }
                    }.padding(16)
                }.onChange(of:messages.last?.id){_,last in if let last{proxy.scrollTo(last,anchor:.bottom)}}
            }
            HStack(alignment:.bottom,spacing:12) {
                PhotosPicker(selection:$photo,matching:.images){Image(systemName:"photo").font(.title2).frame(width:40,height:44)}.accessibilityLabel("Attach photo")
                TextField("Message",text:$text,axis:.vertical).lineLimit(1...5).padding(12).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:18))
                Button {work=Task{await send()}} label:{if busy{ProgressView()}else{Image(systemName:"arrow.up").font(.headline).frame(width:42,height:42).background(SocialTheme.accent,in:Circle())}}.disabled(busy || !SocialPolicy.canSend(text:text,hasPhoto:false)).accessibilityLabel("Send message")
            }.padding(12)
        }.background(SocialTheme.background).navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline)
        .task(id:scenePhase){guard scenePhase == .active else{return};await load();while !Task.isCancelled{do{try await Task.sleep(for:.seconds(3))}catch{return};await load()}}
        .onChange(of:photo){_,item in work=Task{do{if let data=try await item?.loadTransferable(type:Data.self){draft=PhotoDraft(data:try PhotoPreparation.jpeg(data))}}catch{self.error=error.localizedDescription}}}
        .sheet(item:$draft){draft in MediaComposer(draft:draft,conversationID:id,onComplete:{self.draft=nil;Task{await load()}})}
        .onDisappear{work?.cancel()}
    }
    func load() async {
        do {
            var after=messages.last?.id ?? 0
            while !Task.isCancelled {
                let reply:MessagesReply=try await session.request("/v1/conversations/"+id+"/messages?after="+String(after))
                messages.append(contentsOf:reply.messages.filter{incoming in !messages.contains(where:{$0.id==incoming.id})})
                guard reply.messages.count==100,let last=reply.messages.last,last.id>after else{break};after=last.id
            }
            error=nil
        }catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
    func send() async {
        guard SocialPolicy.canSend(text:text,hasPhoto:false) else{return}
        busy=true;defer{busy=false}
        do{let _:ChatMessage=try await session.request("/v1/conversations/"+id+"/messages",method:"POST",body:["text":text]);text="";await load()}catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
}

struct StoriesScreen:View {
    @EnvironmentObject var session:SocialSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var stories:[Story]=[]
    @State private var error:String?
    @State private var loaded=false
    @State private var selected:Story?
    @State private var storyPhoto:PhotosPickerItem?
    @State private var storyDraft:PhotoDraft?
    @State private var photoWork:Task<Void,Never>?
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text("Little moments. Here for a day.").font(.title3).foregroundStyle(SocialTheme.muted)
                    if let error{FailureBanner(message:error,retry:{Task{await load()}})}
                    if !loaded{ProgressView().frame(maxWidth:.infinity).padding(40)}
                    TimelineView(.periodic(from:.now,by:30)){context in
                        let active=stories.filter{SocialPolicy.remaining(story:$0,now:context.date)>0}
                        if loaded && active.isEmpty {ContentUnavailableView {Label("A new story starts with you",systemImage:"camera")} description: {Text("Share a photo with your friends for 24 hours.")} actions: {PhotosPicker(selection:$storyPhoto,matching:.images){Label("Create story",systemImage:"plus")}.buttonStyle(.borderedProminent)}}
                        LazyVGrid(columns:[GridItem(.flexible(),spacing:14),GridItem(.flexible(),spacing:14)],spacing:18){
                            ForEach(active){story in Button{selected=story}label:{VStack(alignment:.leading,spacing:10){AuthenticatedMedia(id:story.mediaId).frame(height:210).frame(maxWidth:.infinity).background(SocialTheme.surface).clipShape(RoundedRectangle(cornerRadius:20));HStack(spacing:8){PersonAvatar(name:story.displayName ?? "You",size:30);Text(story.displayName ?? "Your story").font(.subheadline.bold()).lineLimit(1)};Text("\(max(1,SocialPolicy.remaining(story:story,now:context.date)/3600))h left").font(.caption).foregroundStyle(SocialTheme.muted)}}.buttonStyle(.plain)}
                        }
                    }
                }.padding(SocialTheme.padding)
            }.background(SocialTheme.background).navigationTitle("Stories").refreshable{await load()}
            .toolbar{ToolbarItem(placement:.primaryAction){PhotosPicker(selection:$storyPhoto,matching:.images){Label("Create story",systemImage:"plus")}.accessibilityIdentifier("stories.create")}}
            .onChange(of:storyPhoto){_,item in photoWork=Task{do{if let data=try await item?.loadTransferable(type:Data.self){storyDraft=PhotoDraft(data:try PhotoPreparation.jpeg(data))}}catch{self.error=error.localizedDescription}}}
            .sheet(item:$storyDraft){draft in MediaComposer(draft:draft,onComplete:{storyDraft=nil;Task{await load()}})}
            .onDisappear{photoWork?.cancel()}
            .task(id:scenePhase){guard scenePhase == .active else{return};await load();while !Task.isCancelled{do{try await Task.sleep(for:.seconds(30))}catch{return};await load()}}
            .sheet(item:$selected){story in NavigationStack{TimelineView(.periodic(from:.now,by:1)){context in VStack(spacing:18){if SocialPolicy.remaining(story:story,now:context.date)>0 {AuthenticatedMedia(id:story.mediaId);Text(story.caption).font(.title3)} else {ContentUnavailableView("Story expired",systemImage:"clock",description:Text("This moment is no longer available."))};Spacer()}}.padding(20).navigationTitle(story.displayName ?? "Story").toolbar{ToolbarItem(placement:.cancellationAction){Button("Done"){selected=nil}};if story.owner==session.user?.id{ToolbarItem(placement:.primaryAction){Button("Delete",role:.destructive){Task{await remove(story)}}}}}}}
        }
    }
    func load() async{do{let reply:StoriesReply=try await session.request("/v1/stories");stories=reply.stories;loaded=true;error=nil}catch is CancellationError{}catch{self.error=error.localizedDescription;loaded=true}}
    func remove(_ story:Story) async{do{_ = try await session.requestData("/v1/stories/"+story.id,method:"DELETE");selected=nil;await load()}catch{self.error=error.localizedDescription}}
}
