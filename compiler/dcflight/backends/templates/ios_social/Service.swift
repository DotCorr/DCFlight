import SwiftUI
import Security

struct SocialUser: Codable, Identifiable { let id: String; let username: String; let displayName: String; var locationSharing: Bool? }
struct AuthReply: Decodable { let token: String; let expiresAt: Int; let user: SocialUser }
struct UsersReply: Decodable { let users: [SocialUser] }
struct FriendsReply: Decodable { let friends: [SocialUser] }
struct FriendRequest: Decodable, Identifiable { let id: String; let sender: String; let recipient: String; let status: String; let username: String; let displayName: String }
struct RequestsReply: Decodable { let requests: [FriendRequest] }
struct Conversation: Decodable, Identifiable, Hashable { let id: String; let a: String; let b: String; var username: String?; var displayName: String? }
struct ConversationsReply: Decodable { let conversations: [Conversation] }
struct ChatMessage: Decodable, Identifiable { let id: Int; let sender: String; let text: String; let mediaId: String?; let createdAt: Int }
struct MessagesReply: Decodable { let messages: [ChatMessage] }
struct MediaReply: Decodable { let id: String; let width: Int; let height: Int }
struct Story: Decodable, Identifiable { let id: String; let owner: String; let mediaId: String; let caption: String; let expiresAt: Int; let createdAt: Int; var displayName: String?; var username: String? }
struct StoriesReply: Decodable { let stories: [Story] }
struct FriendLocation: Decodable, Identifiable { let id: String; let username: String; let displayName: String; let latitudeE6: Int; let longitudeE6: Int; let updatedAt: Int }
struct LocationsReply: Decodable { let locations: [FriendLocation] }
enum ServiceValidation {
    static func message(_ detail:Any?) -> String? {
        if let text=detail as? String{return text}
        guard let issues=detail as? [[String:Any]] else{return nil}
        let labels=["username":"Username","password":"Password","display_name":"Your name","caption":"Caption","text":"Message"]
        let messages=issues.prefix(4).compactMap { issue -> String? in
            guard let location=issue["loc"] as? [String],let field=location.last,let label=labels[field],let message=issue["msg"] as? String else{return nil}
            return label+": "+String(message.prefix(240))
        }
        return messages.isEmpty ? nil : messages.joined(separator:"\n")
    }
    static func credentials(username:String,password:String,displayName:String?) -> String? {
        if !(3...24).contains(username.unicodeScalars.count) || username.range(of:"^[A-Za-z0-9_]+$",options:.regularExpression)==nil{return "Username: use 3–24 letters, numbers, or underscores."}
        if !(12...128).contains(password.unicodeScalars.count){return "Password: use 12–128 characters."}
        if let name=displayName, name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || name.unicodeScalars.count>60{return "Your name: use 1–60 characters."}
        return nil
    }
}
struct ServiceFailure: LocalizedError { let message: String; var errorDescription: String? { message } }

final class OriginRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let origin = task.originalRequest?.url, let next = request.url,
              origin.scheme == next.scheme, origin.host == next.host, origin.port == next.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}

enum SessionKeychain {
    static var service: String { (Bundle.main.bundleIdentifier ?? "app") + ".session." + SocialConfiguration.baseURL }
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&item) == errSecSuccess, let data=item as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    static func clear() { SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token"] as CFDictionary) }
    static func save(_ token: String) throws {
        clear()
        let status=SecItemAdd([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"token",kSecValueData as String:Data(token.utf8),kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary,nil)
        guard status == errSecSuccess else { throw ServiceFailure(message:"Secure storage is unavailable. Please unlock your device and try again.") }
    }
}

@MainActor final class SocialSession: ObservableObject {
    @Published private(set) var user: SocialUser?
    @Published private(set) var token: String? = SessionKeychain.read()
    @Published var restoreError: String?
    @Published var conversationRoute: String?
    @Published var logoutNotice: String?
    private let policy=OriginRedirectPolicy()
    private lazy var transport: URLSession = {
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=25; config.timeoutIntervalForResource=60
        config.httpCookieStorage=nil; config.urlCache=nil
        return URLSession(configuration:config,delegate:policy,delegateQueue:nil)
    }()
    private let decoder: JSONDecoder = { let d=JSONDecoder();d.keyDecodingStrategy = .convertFromSnakeCase;return d }()
    func requestData(_ path: String, method: String="GET", body: [String:Any]?=nil, bytes: Data?=nil, authenticated: Bool=true) async throws -> Data {
        guard let url=URL(string:SocialConfiguration.baseURL + path), let base=URL(string:SocialConfiguration.baseURL), url.host==base.host, url.scheme==base.scheme else { throw ServiceFailure(message:"Invalid service address") }
        let requestToken=token
        var request=URLRequest(url:url);request.httpMethod=method
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        if authenticated { guard let token else { throw ServiceFailure(message:"Please sign in") };request.setValue("Bearer " + token,forHTTPHeaderField:"Authorization") }
        if let body { request.httpBody=try JSONSerialization.data(withJSONObject:body);request.setValue("application/json",forHTTPHeaderField:"Content-Type") }
        if let bytes { request.httpBody=bytes;request.setValue("image/jpeg",forHTTPHeaderField:"Content-Type") }
        let (data,response)=try await transport.data(for:request)
        try Task.checkCancellation()
        if authenticated && requestToken != token { throw CancellationError() }
        guard let http=response as? HTTPURLResponse else { throw ServiceFailure(message:"No response from the service") }
        if http.statusCode==401 && authenticated { clearSession() }
        guard (200..<300).contains(http.statusCode) else {
            let detail=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            let message=ServiceValidation.message(detail?["detail"]) ?? (http.statusCode==422 ? "Please check your details and try again." : "Request failed (\(http.statusCode)). Please try again.")
            throw ServiceFailure(message:message)
        }
        return data
    }
    func request<T: Decodable>(_ path: String, method: String="GET", body: [String:Any]?=nil, as type: T.Type=T.self) async throws -> T {
        try decoder.decode(T.self,from:await requestData(path,method:method,body:body))
    }
    func authenticate(username:String,password:String,displayName:String?,register:Bool) async throws {
        var body: [String:Any]=["username":username,"password":password]
        if register { body["display_name"]=displayName ?? username }
        let data=try await requestData(register ? "/v1/auth/register" : "/v1/auth/login",method:"POST",body:body,authenticated:false)
        let reply=try decoder.decode(AuthReply.self,from:data)
        try SessionKeychain.save(reply.token)
        token=reply.token;user=reply.user;restoreError=nil;logoutNotice=nil
    }
    func restore() async {
        guard token != nil, user == nil else { return }
        do { user=try await request("/v1/me");restoreError=nil }
        catch is CancellationError { }
        catch { restoreError=error.localizedDescription }
    }
    func refreshUser() async throws { user=try await request("/v1/me") }
    func clearSession() { SessionKeychain.clear();token=nil;user=nil;restoreError=nil;conversationRoute=nil }
    func logout() async {
        let previous=token
        clearSession()
        guard let previous,let url=URL(string:SocialConfiguration.baseURL+"/v1/auth/logout") else{return}
        var request=URLRequest(url:url);request.httpMethod="POST"
        request.setValue("Bearer "+previous,forHTTPHeaderField:"Authorization")
        do {
            let (_,response)=try await transport.data(for:request)
            guard let status=(response as? HTTPURLResponse)?.statusCode,(200..<300).contains(status) || status==401 else{throw ServiceFailure(message:"Session revocation failed")}
        } catch {
            if token==nil{logoutNotice="Signed out on this device. The service could not confirm session revocation; the previous token may remain valid until it expires."}
        }
    }
    func upload(_ data:Data) async throws -> String { let reply=try decoder.decode(MediaReply.self,from:await requestData("/v1/media",method:"POST",bytes:data));return reply.id }
}

struct FailureBanner: View {
    let message: String; var retry: (() -> Void)? = nil
    var body: some View {
        HStack(alignment:.top,spacing:10) {
            Image(systemName:"exclamationmark.circle")
            Text(message).font(.subheadline)
            Spacer(minLength:0)
            if let retry { Button("Retry",action:retry).font(.subheadline.bold()) }
        }.foregroundStyle(SocialTheme.danger).padding(14).background(SocialTheme.danger.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
    }
}
struct PersonAvatar: View {
    let name:String;var size:CGFloat=48
    var body:some View { Text(String(name.prefix(1)).uppercased()).font(.system(size:size*0.4,weight:.bold)).foregroundStyle(SocialTheme.text).frame(width:size,height:size).background(SocialTheme.accent,in:Circle()).accessibilityHidden(true) }
}
struct AuthenticatedMedia: View {
    @EnvironmentObject var session:SocialSession
    let id:String
    @State private var image:UIImage?
    @State private var error:String?
    @State private var attempt=0
    var body:some View {
        Group {
            if let image { Image(uiImage:image).resizable().scaledToFit() }
            else if let error { VStack(spacing:8) { Image(systemName:"photo.badge.exclamationmark");Text(error).font(.caption);Button("Retry"){attempt+=1} }.padding(16) }
            else { ProgressView().frame(maxWidth:.infinity,minHeight:160) }
        }.task(id:id+String(attempt)) {
            do { let data=try await session.requestData("/v1/media/"+id);try Task.checkCancellation();guard let decoded=UIImage(data:data) else { throw ServiceFailure(message:"Image unavailable") };image=decoded;error=nil }
            catch is CancellationError {} catch { self.error=error.localizedDescription }
        }
    }
}
