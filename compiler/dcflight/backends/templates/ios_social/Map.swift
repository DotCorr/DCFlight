import SwiftUI
import MapKit
import CoreLocation

@MainActor final class LocationEngine:NSObject,ObservableObject,CLLocationManagerDelegate {
    private let manager=CLLocationManager()
    @Published var error:String?
    @Published var denied=false
    @Published var waiting=false
    var onLocation:((CLLocation)->Void)?
    var active=false
    override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters}
    var authorized:Bool{manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways}
    func request(){
        active=true;waiting=true
        switch manager.authorizationStatus {
        case .notDetermined:manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse,.authorizedAlways:manager.requestLocation()
        default:denied=true;waiting=false;error="Location access is off. You can enable it in Settings."
        }
    }
    func stop(){active=false;waiting=false;manager.stopUpdatingLocation()}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){guard active else{return};if authorized{denied=false;manager.requestLocation()}else if manager.authorizationStatus != .notDetermined{denied=true;waiting=false;error="Location permission was not granted."}}
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){waiting=false;guard active,let location=locations.last,abs(location.timestamp.timeIntervalSinceNow)<60 else{return};error=nil;onLocation?(location)}
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){waiting=false;self.error=error.localizedDescription}
}
struct FriendMapScreen:View {
    @EnvironmentObject var session:SocialSession
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var location=LocationEngine()
    @State private var friends:[FriendLocation]=[]
    @State private var position:MapCameraPosition = .automatic
    @State private var sharing=false
    @State private var busy=false
    @State private var error:String?
    @State private var work:Task<Void,Never>?
    var body:some View {
        NavigationStack {
            ZStack(alignment:.bottom) {
                Map(position:$position){
                    ForEach(friends){friend in Annotation(friend.displayName,coordinate:CLLocationCoordinate2D(latitude:Double(friend.latitudeE6)/1_000_000,longitude:Double(friend.longitudeE6)/1_000_000)){PersonAvatar(name:friend.displayName,size:42).overlay(Circle().stroke(.white,lineWidth:3))}}
                }.mapControls{MapCompass();MapScaleView()}
                VStack(alignment:.leading,spacing:12){
                    HStack{VStack(alignment:.leading,spacing:4){Text("Your people, nearby").font(.headline);Text(friends.isEmpty ? "No friends are sharing a fresh location." : "\(friends.count) friends sharing now").font(.caption).foregroundStyle(SocialTheme.muted)};Spacer();Button{Task{await load()}}label:{Image(systemName:"arrow.clockwise").padding(10)}}
                    Toggle("Share my location",isOn:Binding(get:{sharing},set:{value in work=Task{await setSharing(value)}})).disabled(busy || location.waiting)
                    Text("Off by default. Updates only while this map is open. Shared locations expire after one hour without an update.").font(.caption).foregroundStyle(SocialTheme.muted)
                    if let message=error ?? location.error{FailureBanner(message:message)}
                    if location.denied{Button("Open Settings"){if let url=URL(string:UIApplication.openSettingsURLString){UIApplication.shared.open(url)}}}
                    if busy || location.waiting{ProgressView("Updating location…")}
                }.padding(20).background(SocialTheme.surface,in:RoundedRectangle(cornerRadius:SocialTheme.radius)).padding(16)
            }.navigationTitle("Map").navigationBarTitleDisplayMode(.inline)
            .task(id:scenePhase){guard scenePhase == .active else{location.stop();return};location.onLocation={coordinate in work=Task{await publish(coordinate)}};sharing=session.user?.locationSharing ?? false;await load();if sharing{location.request()};while !Task.isCancelled{do{try await Task.sleep(for:.seconds(30))}catch{return};await load();if sharing{location.request()}}}
            .onChange(of:location.denied){_,denied in if denied && sharing{work=Task{await setSharing(false)}}}
            .onDisappear{location.stop();work?.cancel()}
        }
    }
    func load() async{do{let reply:LocationsReply=try await session.request("/v1/map");friends=reply.locations;error=nil}catch is CancellationError{}catch{self.error=error.localizedDescription}}
    func setSharing(_ value:Bool) async{
        if value{sharing=true;location.request();return}
        sharing=false;location.stop();busy=true;defer{busy=false}
        do{_ = try await session.requestData("/v1/location",method:"PUT",body:["enabled":false]);try await session.refreshUser();error=nil}
        catch{self.error="Could not clear the last shared location from the service. It expires within one hour. "+error.localizedDescription}
    }
    func publish(_ coordinate:CLLocation) async{
        guard SocialPolicy.shouldPublish(consent:sharing,permission:location.authorized),location.active else{return}
        busy=true;defer{busy=false}
        do{_ = try await session.requestData("/v1/location",method:"PUT",body:["enabled":true,"latitude_e6":Int((coordinate.coordinate.latitude*1_000_000).rounded()),"longitude_e6":Int((coordinate.coordinate.longitude*1_000_000).rounded())]);try await session.refreshUser();error=nil;position = .region(MKCoordinateRegion(center:coordinate.coordinate,span:MKCoordinateSpan(latitudeDelta:0.03,longitudeDelta:0.03)))}catch is CancellationError{}catch{self.error=error.localizedDescription}
    }
}
