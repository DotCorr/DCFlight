import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

enum CheckFailure: Error { case failed(String) }
@main struct VerifySharedFlow {
    static var lastCheck = "starting"
    @MainActor static func main() async {
        let transport = NativeHTTPTransport()
        var cleanupToken = ""
        var friendCleanupToken = ""
        let password = "temporary integration password"
        do {
            try NativeSecureStore.delete("session")
            let model = AppModel()
            model.startSharedTimers()
            var route = ""
            let navigate: (String) -> Void = { route = $0 }
            model.startInitialFlow(navigate)
            try await wait { model.s_ready }
            try check(model.s_token.isEmpty, "initial empty secure session")
            model.s_username = "ab"; model.s_password = "short"
            model.f_login(navigate)
            try check(model.s_message == "Use 3–24 letters, numbers or underscores for your username.", "shared native username decision")
            model.s_username = "__USERNAME__"; model.s_password = password; model.s_displayName = "Integration User"
            model.f_register(navigate)
            try await wait { route == "showHome" || model.s_ready }
            try check(route == "showHome" && !model.s_token.isEmpty, "registration navigates after secure save")
            cleanupToken = model.s_token
            try check(model.s_password.isEmpty, "password cleared after authentication")
            model.s_displayName = "Updated Profile"
            model.f_saveProfile(navigate)
            try await wait { model.s_ready }
            try check(model.s_message == "Profile saved.", "profile request shared success")
            let restored = AppModel(); var restoredRoute = ""
            restored.startInitialFlow { restoredRoute = $0 }
            try await wait { restored.s_ready }
            try check(restoredRoute == "showHome" && restored.s_displayName == "Updated Profile", "secure session restore and real server profile")
            restored.f_logout { restoredRoute = $0 }
            try await wait { restored.s_revocationToken.isEmpty }
            try check(restoredRoute == "showLogin" && restored.s_token.isEmpty && restored.s_message == "Signed out.", "logout and revocation")
            try check(try NativeSecureStore.read("session").isEmpty, "secure token deleted")
            route = ""; model.s_token = ""; model.s_password = "wrong integration password"
            model.f_login(navigate)
            try await wait { model.s_ready }
            try check(model.s_status == 401 && model.s_message == "Username or password was not accepted.", "shared credential failure")
            model.s_password = password; model.f_login(navigate)
            try await wait { model.s_ready }
            try check(route == "showHome" && !model.s_token.isEmpty, "login after logout")
            cleanupToken = model.s_token
            let friendModel = AppModel()
            let friendName = "__USERNAME__b"
            friendModel.s_username=friendName; friendModel.s_password=password; friendModel.s_displayName="Friend Tester"
            friendModel.f_register { _ in }
            try await wait { friendModel.s_ready }
            try check(!friendModel.s_token.isEmpty, "second native model registration")
            friendCleanupToken=friendModel.s_token
            model.s_query=friendName; model.f_searchPeople(navigate)
            try await wait { model.s_ready }
            try check(model.c_searchResults.count==1, "typed shared user search")
            model.s_selectedUser=model.c_searchResults[0].f_id; model.f_requestFriend(navigate)
            try await wait { model.s_ready }
            try check(model.s_message.hasPrefix("Friend request sent"), "request persisted success")
            friendModel.f_refreshRequests { _ in }; try await wait { friendModel.s_ready }
            try check(friendModel.c_requests.count==1, "incoming typed request")
            friendModel.s_selectedRequest=friendModel.c_requests[0].f_id; friendModel.f_acceptFriend { _ in }
            try await wait { friendModel.s_ready }
            try check(friendModel.c_requests.isEmpty, "accepted request refresh")
            model.f_refreshFriends(navigate); try await wait { model.s_ready }
            try check(model.c_friends.count==1, "accepted friend list")
            model.s_selectedUser=model.c_friends[0].f_id; model.f_startChat(navigate)
            try await wait { model.s_ready }
            try check(route=="showConversation" && !model.s_conversationId.isEmpty, "shared conversation creation/open")
            model.s_draft="";model.f_sendMessage(navigate)
            try check(model.s_message=="Write a message between 1 and 2,000 characters.", "shared DC Dart message decision")
            model.s_draft="Hello from shared Dart";model.f_sendMessage(navigate)
            try await wait { model.s_ready }
            try check(model.c_messages.count==1 && model.s_draft.isEmpty, "send persisted and appended message")
            friendModel.f_refreshChats { _ in };try await wait { friendModel.s_ready }
            try check(friendModel.c_conversations.count==1, "conversation list native projection")
            friendModel.s_conversationId=friendModel.c_conversations[0].f_id;friendModel.f_openConversation { _ in }
            try await wait { friendModel.s_ready }
            try check(friendModel.c_messages.first?.f_text=="Hello from shared Dart", "other native model reads message")
            friendModel.s_draft="A real reply";friendModel.f_sendMessage { _ in };try await wait { friendModel.s_ready }
            model.f_loadMessages(navigate);try await wait { model.s_ready }
            try check(model.c_messages.count==2 && model.c_messages.last?.f_text=="A real reply", "incremental cursor preserves previous message")
            model.f_loadMessages(navigate);try await wait { model.s_ready }
            try check(model.c_messages.count==2, "empty incremental page does not duplicate or erase")
            let canvas=UIGraphicsImageRenderer(size:CGSize(width:80,height:60))
            let raw=canvas.jpegData(withCompressionQuality:1) { ctx in UIColor.orange.setFill();ctx.fill(CGRect(x:0,y:0,width:80,height:60)) }
            let prepared=try NativePhotoPreparation.prepare(raw,options:NativePhotoOptions(maxInputBytes:33554432,maxPixels:20000000,maxEdge:2048,qualityPercent:85,maxOutputBytes:8388608))
            model.m_photo=prepared;model.s_photoIntent=0;model.s_photoCaption="A real photo"
            model.f_uploadPhoto(navigate);try await wait { model.s_ready }
            try check(model.m_photo==nil && model.c_messages.count==3 && model.c_messages.last?.f_has_media==true,"binary upload and authored photo message flow")
            let mediaID=model.s_uploadedMediaId
            friendModel.f_loadMessages { _ in };try await wait { friendModel.s_ready }
            try check(friendModel.c_messages.last?.f_media_id==mediaID,"recipient receives media reference")
            let (photoBytes,photoStatus)=try await transport.send(url:URL(string:"__BASE__/v1/media/"+mediaID)!,method:"GET",body:[:],bearer:friendModel.s_token,maxBytes:8388608)
            try check(photoStatus==200 && UIImage(data:photoBytes) != nil,"authorized native photo download and decode")
            let (_,deniedStatus)=try await transport.send(url:URL(string:"__BASE__/v1/media/"+mediaID)!,method:"GET",body:[:],bearer:"invalid-session",maxBytes:8388608)
            try check(deniedStatus==401,"invalid session cannot download media")
            model.m_photo=prepared;model.s_photoIntent=1;model.s_photoCaption="A shared story"
            model.f_uploadPhoto(navigate);try await wait { model.s_ready }
            try check(model.c_stories.count==1 && model.m_photo==nil,"raw upload then shared story publication")
            friendModel.f_refreshStories { _ in };try await wait { friendModel.s_ready }
            try check(friendModel.c_stories.count==1 && friendModel.c_stories[0].f_is_owner==false,"friend story collection ownership")
            friendModel.s_selectedStory=friendModel.c_stories[0].f_id;friendModel.f_openStory { _ in }
            try check(friendModel.s_storyVisible && friendModel.s_storyCaption=="A shared story","atomic selected story metadata")
            model.s_selectedStory=model.c_stories[0].f_id;model.f_openStory(navigate)
            try check(model.s_storyVisible && model.s_storyOwned,"owner story view")
            model.s_storyExpires=Int32(Date().timeIntervalSince1970)-1
            try await wait { !model.s_storyVisible }
            try check(model.s_storyMediaId.isEmpty && model.s_message=="This story has expired.","automatic timer invokes shared native expiry and clears private source")
            model.f_deleteStory(navigate);try await wait { model.s_ready }
            try check(model.c_stories.isEmpty,"authored owner story deletion refresh")
            model.s_cameraReady=false;model.f_captureStory(navigate)
            try check(model.m_photo==nil && model.s_message=="Start the camera and wait until the preview is ready.","shared camera readiness prevents unavailable capture")
            model.s_locationConsent=false;model.s_accuracy=5;model.f_locationMeasured(navigate)
            try check(model.s_message=="Location sharing is off. No new location was shared.","shared consent blocks location publication")
            model.s_locationConsent=true;model.s_accuracy=3000;model.f_locationMeasured(navigate)
            try check(model.s_message=="This location is not accurate enough. Try again before sharing.","shared accuracy rule blocks publication")
            // Inject a deterministic sample into ordinary authored state; this tests
            // publication policy and HTTP, not OS permission or GPS hardware.
            model.s_latitude=52370000;model.s_longitude=4890000;model.s_accuracy=5
            model.f_locationMeasured(navigate);try await wait { model.s_ready }
            try check(model.s_message.hasPrefix("Your last location is shared"),"shared measured-location publication")
            friendModel.f_refreshMap { _ in };try await wait { friendModel.s_ready }
            try check(friendModel.c_locations.count==1 && friendModel.c_locations[0].f_latitude_e6==52370000,"friends-only native map collection projection")
            friendModel.s_mapExpires=Int32(Date().timeIntervalSince1970)-1;friendModel.f_mapTick { _ in }
            try check(friendModel.c_locations.isEmpty && friendModel.s_mapExpires==0,"shared earliest-expiry rule removes cached map coordinates")
            model.f_stopSharing(navigate);try await wait { model.s_ready }
            try check(!model.s_locationConsent && model.s_latitude==0 && model.s_message.hasPrefix("Location sharing stopped"),"explicit consent withdrawal and server revocation")
            friendModel.f_refreshMap { _ in };try await wait { friendModel.s_ready }
            try check(friendModel.c_locations.isEmpty,"revoked coordinates removed from friend map response")
            friendModel.f_logout { _ in };try await wait { friendModel.s_revocationToken.isEmpty }
            try check(friendModel.c_messages.isEmpty && friendModel.c_conversations.isEmpty && friendModel.s_conversationId.isEmpty, "logout clears private collection state")
            // Login once solely to delete this fixture account after logout revoked its token.
            friendModel.s_username=friendName;friendModel.s_password=password;friendModel.f_login { _ in };try await wait { friendModel.s_ready }
            friendCleanupToken=friendModel.s_token
            let (_, friendDeleted)=try await transport.send(url:URL(string:"__BASE__/v1/me")!,method:"DELETE",body:["password":password],bearer:friendCleanupToken)
            try check(friendDeleted==204, "second fixture account deleted")
            friendCleanupToken=""
            model.s_token = "invalid-session"; model.f_saveProfile(navigate)
            try await wait { model.s_ready }
            try check(route == "showLogin" && model.s_token.isEmpty, "expired session returns to login")
            try check(model.c_messages.isEmpty && model.c_friends.isEmpty && model.s_draft.isEmpty, "expired session clears private lists")
            try check(try NativeSecureStore.read("session").isEmpty, "expired session cleared securely")
            let (_, deletionStatus) = try await transport.send(url: URL(string: "__BASE__/v1/me")!, method: "DELETE", body: ["password":password], bearer: cleanupToken)
            try check(deletionStatus == 204, "test account deleted by service")
            cleanupToken = ""
            try NativeSecureStore.delete("session")
            try report(["passed":true,"transport":"real loopback HTTP","generatedModelExecuted":true,"sharedDCDartExecuted":true,"registration":true,"login":true,"profile":true,"logout":true,"sessionRestore":true,"invalidCredentials":true,"expiredSession":true,"testAccountsDeleted":true,"friends":true,"textChat":true,"incrementalMessages":true,"privateCollectionCleanup":true,"photoUpload":true,"privatePhotoDownload":true,"photoMessaging":true,"storyPublishViewDelete":true,"automaticSharedStoryExpiry":true,"systemPickerUIExercised":false,"cameraHardwareExercised":false,"locationHardwareExercised":false,"sharedLocationPublishRevoke":true])
        } catch {
            if !friendCleanupToken.isEmpty { _ = try? await transport.send(url:URL(string:"__BASE__/v1/me")!,method:"DELETE",body:["password":password],bearer:friendCleanupToken) }
            if !cleanupToken.isEmpty { _ = try? await transport.send(url: URL(string:"__BASE__/v1/me")!,method:"DELETE",body:["password":password],bearer:cleanupToken) }
            try? NativeSecureStore.delete("session")
            try? report(["passed":false,"error":String(describing:error),"lastCheck":lastCheck])
            exit(1)
        }
    }
    @MainActor static func wait(_ done: () -> Bool) async throws {
        for _ in 0..<400 { if done() { return }; try await Task.sleep(nanoseconds:50_000_000) }
        throw CheckFailure.failed("operation completion timeout")
    }
    static func check(_ condition:Bool,_ label:String) throws { if !condition { throw CheckFailure.failed(label) }; lastCheck=label }
    static func report(_ value:[String:Any]) throws { let data=try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]);try data.write(to:URL(fileURLWithPath:"__REPORT__")) }
}
