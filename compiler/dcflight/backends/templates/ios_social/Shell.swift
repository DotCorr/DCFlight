import SwiftUI

struct SocialGate<Content:View>:View {
    @EnvironmentObject var session:SocialSession
    @ViewBuilder let content:()->Content
    var body:some View {
        Group {
            if session.user != nil { content() }
            else if session.token != nil {
                VStack(spacing:20) {
                    if let error=session.restoreError { FailureBanner(message:error,retry:{Task{await session.restore()}});Button("Sign out"){session.clearSession()} }
                    else { ProgressView("Opening your account…") }
                }.padding(24).task{await session.restore()}
            } else { AuthenticationScreen() }
        }.background(SocialTheme.background).tint(SocialTheme.text)
    }
}
struct AuthenticationScreen:View {
    @EnvironmentObject var session:SocialSession
    @State private var registering=true
    @State private var username=""
    @State private var password=""
    @State private var displayName=""
    @State private var busy=false
    @State private var error:String?
    @FocusState private var focus:Int?
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                HStack { Image(systemName:"camera.fill").font(.system(size:32,weight:.semibold)).foregroundStyle(SocialTheme.accent).padding(20).background(SocialTheme.text,in:RoundedRectangle(cornerRadius:24));Spacer() }.padding(.top,28)
                VStack(alignment:.leading,spacing:8) { Text(SocialConfiguration.appName).font(.system(size:48,weight:.heavy,design:.rounded)).tracking(-2);Text("Your people. Your perspective.").font(.title3).foregroundStyle(SocialTheme.muted) }
                VStack(alignment:.leading,spacing:18) {
                    Text(registering ? "Make yourself at home" : "Good to see you again").font(.title2.bold())
                    if registering { input("Your name",text:$displayName).textContentType(.name).focused($focus,equals:0);Text("1–60 characters").font(.caption).foregroundStyle(SocialTheme.muted) }
                    input("Username",text:$username).textInputAutocapitalization(.never).autocorrectionDisabled().textContentType(.username).focused($focus,equals:1)
                    Text("3–24 letters, numbers, or underscores").font(.caption).foregroundStyle(SocialTheme.muted)
                    SecureField("Password · 12–128 characters",text:$password).textContentType(registering ? .newPassword : .password).padding(16).background(SocialTheme.background,in:RoundedRectangle(cornerRadius:14)).focused($focus,equals:2)
                    if let notice=session.logoutNotice { FailureBanner(message:notice) }
                    if let error { FailureBanner(message:error) }
                    Button { focus=nil;Task{await submit()} } label: { HStack { Spacer();if busy {ProgressView()} else {Text(registering ? "Create account" : "Sign in").font(.headline);Image(systemName:"arrow.right")};Spacer() }.padding(18) }.background(SocialTheme.accent,in:RoundedRectangle(cornerRadius:16)).disabled(busy)
                    Button(registering ? "Already here? Sign in" : "New here? Create an account") { registering.toggle();error=nil }.font(.subheadline.weight(.medium)).frame(maxWidth:.infinity)
                }.padding(24).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:SocialTheme.radius))
                Text("Photos stay private to the people you choose. Location sharing starts off.").font(.footnote).foregroundStyle(SocialTheme.muted)
            }.padding(SocialTheme.padding)
        }.background(SocialTheme.background).foregroundStyle(SocialTheme.text)
    }
    func input(_ title:String,text:Binding<String>)->some View { TextField(title,text:text).padding(16).background(SocialTheme.background,in:RoundedRectangle(cornerRadius:14)) }
    func submit() async {
        if let message=ServiceValidation.credentials(username:username,password:password,displayName:registering ? displayName : nil){error=message;return}
        busy=true;defer{busy=false}
        do { try await session.authenticate(username:username,password:password,displayName:displayName,register:registering);password="" }
        catch is CancellationError {} catch { self.error=error.localizedDescription }
    }
}

struct FriendsScreen:View {
    @EnvironmentObject var session:SocialSession
    @State private var friends:[SocialUser]=[]
    @State private var requests:[FriendRequest]=[]
    @State private var results:[SocialUser]=[]
    @State private var query=""
    @State private var error:String?
    @State private var notice:String?
    @State private var loading=false
    var onConversation:((String)->Void)?
    var body:some View {
        List {
            if let error { FailureBanner(message:error,retry:{Task{await load()}}).listRowSeparator(.hidden) }
            if let notice { Text(notice).foregroundStyle(SocialTheme.muted).font(.footnote) }
            Section("Find your people") {
                HStack { TextField("Search username",text:$query).textInputAutocapitalization(.never).autocorrectionDisabled().onSubmit{Task{await search()}};Button("Search"){Task{await search()}} }
                ForEach(results) { person in HStack(spacing:12) { PersonAvatar(name:person.displayName,size:40);VStack(alignment:.leading){Text(person.displayName).font(.headline);Text("@"+person.username).font(.caption).foregroundStyle(SocialTheme.muted)};Spacer();Button("Add"){Task{await add(person)}} } }
            }
            Section("Requests") {
                ForEach(requests) { request in HStack { VStack(alignment:.leading){Text(request.displayName).font(.headline);Text(request.sender==session.user?.id ? "Request sent" : "Wants to be friends").font(.caption).foregroundStyle(SocialTheme.muted)};Spacer();if request.recipient==session.user?.id {Button("Accept"){Task{await accept(request)}}} } }
                if requests.isEmpty {Text("No pending requests").foregroundStyle(SocialTheme.muted)}
            }
            Section("Friends") {
                ForEach(friends) { person in
                    Button {Task{await open(person)}} label:{HStack(spacing:12){PersonAvatar(name:person.displayName,size:44);VStack(alignment:.leading){Text(person.displayName).font(.headline);Text("@"+person.username).font(.caption).foregroundStyle(SocialTheme.muted)};Spacer();Image(systemName:"bubble.left")}}
                    .swipeActions{Button("Remove",role:.destructive){Task{await remove(person)}}}
                }
                if friends.isEmpty {Text("Find a friend to start a conversation.").foregroundStyle(SocialTheme.muted)}
            }
        }.scrollContentBackground(.hidden).background(SocialTheme.background).navigationTitle("Friends").overlay{if loading{ProgressView()}}.task{await load()}.refreshable{await load()}
    }
    func load() async {loading=true;defer{loading=false};do{async let f:FriendsReply=session.request("/v1/friends");async let r:RequestsReply=session.request("/v1/friend-requests");friends=try await f.friends;requests=try await r.requests;error=nil}catch is CancellationError{}catch{self.error=error.localizedDescription}}
    func search() async {do{guard let q=query.addingPercentEncoding(withAllowedCharacters:.alphanumerics) else{return};let reply:UsersReply=try await session.request("/v1/users?q="+q);results=reply.users;error=nil}catch{self.error=error.localizedDescription}}
    func add(_ user:SocialUser) async {do{_ = try await session.requestData("/v1/friend-requests",method:"POST",body:["user_id":user.id]);notice="Request sent to "+user.displayName;await load()}catch{self.error=error.localizedDescription}}
    func accept(_ request:FriendRequest) async {do{_ = try await session.requestData("/v1/friend-requests/"+request.id+"/accept",method:"POST");await load()}catch{self.error=error.localizedDescription}}
    func remove(_ user:SocialUser) async {do{_ = try await session.requestData("/v1/friends/"+user.id,method:"DELETE");await load()}catch{self.error=error.localizedDescription}}
    func open(_ user:SocialUser) async {do{let c:Conversation=try await session.request("/v1/conversations",method:"POST",body:["user_id":user.id]);onConversation?(c.id);session.conversationRoute=c.id}catch{self.error=error.localizedDescription}}
}

struct AccountScreen:View {
    @EnvironmentObject var session:SocialSession
    @State private var name=""
    @State private var error:String?
    @State private var busy=false
    @State private var deletePresented=false
    @State private var password=""
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    HStack(spacing:18){PersonAvatar(name:session.user?.displayName ?? "",size:76);VStack(alignment:.leading,spacing:4){Text(session.user?.displayName ?? "").font(.title2.bold());Text("@"+(session.user?.username ?? "")).foregroundStyle(SocialTheme.muted)}}
                    VStack(alignment:.leading,spacing:14){Text("Your profile").font(.headline);TextField("Display name",text:$name).textContentType(.name).textFieldStyle(.roundedBorder);Button("Save changes"){Task{await save()}}.disabled(busy)}.padding(20).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:SocialTheme.radius))
                    NavigationLink {FriendsScreen()} label:{Label("Manage friends",systemImage:"person.2").font(.headline).frame(maxWidth:.infinity,alignment:.leading).padding(20).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:SocialTheme.radius))}
                    VStack(alignment:.leading,spacing:8){Text("Your privacy").font(.headline);Text("Photos are only shared with your chosen conversations or friends through stories. Location is opt-in and expires when it is no longer refreshed.").font(.subheadline).foregroundStyle(SocialTheme.muted)}
                    if let error {FailureBanner(message:error)}
                    Button("Sign out",role:.destructive){Task{await session.logout()}}.buttonStyle(.bordered).disabled(busy)
                    Button("Delete account…",role:.destructive){deletePresented=true}.font(.footnote)
                }.padding(SocialTheme.padding)
            }.background(SocialTheme.background).navigationTitle("Account").task{name=session.user?.displayName ?? ""}
            .sheet(isPresented:$deletePresented){NavigationStack{Form{Section("Permanently delete your account"){Text("This removes your account, photos, stories, messages and location. This cannot be undone.");SecureField("Confirm your password",text:$password);Button("Delete permanently",role:.destructive){Task{await delete()}}.disabled(password.isEmpty || busy);if let error{Text(error).foregroundStyle(SocialTheme.danger)}}}.navigationTitle("Delete account").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){password="";deletePresented=false}}}}}
        }
    }
    func save() async {busy=true;defer{busy=false};do{let _:SocialUser=try await session.request("/v1/me",method:"PATCH",body:["display_name":name]);try await session.refreshUser();error=nil}catch{self.error=error.localizedDescription}}
    func delete() async {busy=true;defer{busy=false};do{_ = try await session.requestData("/v1/me",method:"DELETE",body:["password":password]);password="";session.clearSession()}catch{self.error=error.localizedDescription}}
}
