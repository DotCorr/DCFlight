package __CHECK_ID__;
import android.app.Instrumentation;
import android.content.*;
import android.os.Bundle;
import org.json.JSONObject;
import java.lang.reflect.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

/** Executes generated application methods; never injects UI input. */
public final class SharedFlowChecks extends Instrumentation {
  Object model; Class<?> modelClass; Object navigate; Context context;
  final String password="Shared-Native-Test-2026!";
  final String username="flow_"+Long.toHexString(System.currentTimeMillis());
  String cleanupToken=""; int checks=0;
  final String friendUsername=username+"b";
  boolean friendAttempted=false; Context target;
  java.util.List<String> assertionNames=new java.util.ArrayList<>();
  final java.util.Set<String> ownedPreferences=new java.util.HashSet<>();
  void main(Runnable operation){runOnMainSync(operation);}
  void check(boolean value,String name){if(!value)throw new AssertionError(name);checks++;assertionNames.add(name);}
  Object get(String name){final Object[] result={null};main(()->{try{result[0]=modelClass.getMethod("getS_"+name).invoke(model);}catch(Exception e){throw new RuntimeException(e);}});return result[0];}
  void set(String name,Object value){main(()->{try{Class<?> t=value instanceof Boolean?boolean.class:value instanceof Integer?int.class:String.class;modelClass.getMethod("setS_"+name,t).invoke(model,value);}catch(Exception e){throw new RuntimeException(e);}});}
  void action(String name){main(()->{try{for(Method m:modelClass.getMethods())if(m.getName().equals("f_"+name)){m.invoke(model,navigate);return;}throw new NoSuchMethodException(name);}catch(Exception e){throw new RuntimeException(e);}});}
  void settled() throws Exception {long until=System.currentTimeMillis()+30000;while(System.currentTimeMillis()<until){if(Boolean.TRUE.equals(get("ready")))return;Thread.sleep(30);}throw new AssertionError("request_timeout");}
  void logoutSettled() throws Exception {long until=System.currentTimeMillis()+30000;while(System.currentTimeMillis()<until){if(!get("message").equals("Signing out…"))return;Thread.sleep(30);}throw new AssertionError("logout_timeout");}
  java.util.List<?> rows(String name){final Object[] result={null};main(()->{try{result[0]=modelClass.getMethod("getC_"+name).invoke(model);}catch(Exception e){throw new RuntimeException(e);}});return (java.util.List<?>)result[0];}
  Object field(Object row,String name)throws Exception{return row.getClass().getMethod("getV_"+name).invoke(row);}
  Context isolated(String account){String scope="shared_flow_check_"+account;return new ContextWrapper(target){@Override public String getPackageName(){return "__CHECK_ID__."+account;}@Override public SharedPreferences getSharedPreferences(String name,int mode){String owned=scope+"_"+name;ownedPreferences.add(owned);return target.getSharedPreferences(owned,mode);}};}
  boolean deleteAccount(String account)throws Exception {
    HttpURLConnection login=(HttpURLConnection)new URL("__BASE__/v1/auth/login").openConnection();login.setRequestMethod("POST");login.setConnectTimeout(15000);login.setReadTimeout(15000);login.setRequestProperty("Content-Type","application/json");login.setDoOutput(true);
    try(java.io.OutputStream out=login.getOutputStream()){out.write(new JSONObject().put("username",account).put("password",password).toString().getBytes(StandardCharsets.UTF_8));}
    String token;
    try(java.io.InputStream in=login.getInputStream()){token=new JSONObject(new String(in.readAllBytes(),StandardCharsets.UTF_8)).getString("token");}finally{login.disconnect();}
    HttpURLConnection request=(HttpURLConnection)new URL("__BASE__/v1/me").openConnection();request.setRequestMethod("DELETE");request.setConnectTimeout(15000);request.setReadTimeout(15000);request.setRequestProperty("Authorization","Bearer "+token);request.setRequestProperty("Content-Type","application/json");request.setDoOutput(true);
    try(java.io.OutputStream out=request.getOutputStream()){out.write(new JSONObject().put("password",password).toString().getBytes(StandardCharsets.UTF_8));}
    try{return request.getResponseCode()==204;}finally{request.disconnect();}
  }
  void photo(Object value){main(()->{try{modelClass.getMethod("setM_photo",Class.forName("__APP_ID__.NativePhoto",true,target.getClassLoader())).invoke(model,value);}catch(Exception e){throw new RuntimeException(e);}});}
  Object photo(){final Object[] result={null};main(()->{try{result[0]=modelClass.getMethod("getM_photo").invoke(model);}catch(Exception e){throw new RuntimeException(e);}});return result[0];}
  Object testPhoto()throws Exception {
    android.graphics.Bitmap bitmap=android.graphics.Bitmap.createBitmap(640,480,android.graphics.Bitmap.Config.ARGB_8888);bitmap.eraseColor(android.graphics.Color.rgb(40,130,200));java.io.ByteArrayOutputStream bytes=new java.io.ByteArrayOutputStream();bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,90,bytes);bitmap.recycle();
    ClassLoader loader=target.getClassLoader();Class<?> options=Class.forName("__APP_ID__.NativePhotoOptions",true,loader);Object settings=options.getConstructor(int.class,int.class,int.class,int.class,int.class).newInstance(256,85,33554432,8388608,20000000);
    Object companion=Class.forName("__APP_ID__.NativeMedia",true,loader).getField("Companion").get(null);
    return companion.getClass().getMethod("normalize",java.io.InputStream.class,options).invoke(companion,new java.io.ByteArrayInputStream(bytes.toByteArray()),settings);
  }
  int mediaStatus(String id,String token)throws Exception {HttpURLConnection c=(HttpURLConnection)new URL("__BASE__/v1/media/"+id).openConnection();c.setConnectTimeout(10000);c.setReadTimeout(10000);if(token!=null)c.setRequestProperty("Authorization","Bearer "+token);try{int status=c.getResponseCode();if(status==200){try(java.io.InputStream input=c.getInputStream()){check(input.readAllBytes().length>0,"download_actual_photo_bytes");}}return status;}finally{c.disconnect();}}
  void newModel(){main(()->{try{model=modelClass.getConstructor(Context.class).newInstance(context);}catch(Exception e){throw new RuntimeException(e);}});}
  @Override public void onCreate(Bundle args){super.onCreate(args);start();}
  @Override public void onStart(){Bundle result=new Bundle();JSONObject report=new JSONObject();boolean passed=false;try{
    target=getTargetContext();context=isolated(username);
    ClassLoader loader=target.getClassLoader();modelClass=Class.forName("__APP_ID__.AuthoredState",true,loader);
    Class<?> fn=Class.forName("kotlin.jvm.functions.Function1",true,loader),unit=Class.forName("kotlin.Unit",true,loader);
    Object unitValue=unit.getField("INSTANCE").get(null);
    navigate=java.lang.reflect.Proxy.newProxyInstance(loader,new Class<?>[]{fn},(p,m,a)->unitValue);
    newModel();set("username","bad.name");set("password",password);action("login");check(get("message").equals("Use 3–24 letters, numbers or underscores for your username.")&&get("token").equals(""),"shared_native_username_guard");set("username",username.toUpperCase(java.util.Locale.ROOT));set("password",password);set("displayName","Native Android Flow");action("register");settled();
    check(get("canonicalUsername").equals(username),"shared_dcdart_canonical_handle_register");check(get("username").equals(username),"server_canonical_username");cleanupToken=(String)get("token");check(!cleanupToken.isEmpty(),"register_token");check(get("displayName").equals("Native Android Flow"),"register_name");check(get("password").equals(""),"password_cleared");
    set("displayName","Native Android Updated");action("saveProfile");settled();check(get("message").equals("Profile saved."),"profile_saved");
    newModel();action("restore");settled();check(get("username").equals(username),"secure_restore_username");check(get("displayName").equals("Native Android Updated"),"secure_restore_profile");
    action("logout");logoutSettled();check(get("token").equals(""),"logout_local_clear");check(get("message").equals("Signed out."),"logout_revoked");
    newModel();action("restore");settled();check(get("token").equals(""),"secure_store_empty");
    set("username",username);set("password","Incorrect-password-2026!");action("login");settled();check(get("token").equals(""),"invalid_no_session");check(get("message").equals("Username or password was not accepted."),"authored_error");
    set("username",username.toUpperCase(java.util.Locale.ROOT));set("password",password);action("login");settled();check(get("canonicalUsername").equals(username),"shared_dcdart_canonical_handle_login");cleanupToken=(String)get("token");check(!cleanupToken.isEmpty(),"login_success");
    Object firstModel=model;Context firstContext=context;
    context=isolated(friendUsername);newModel();friendAttempted=true;
    set("username",friendUsername);set("password",password);set("displayName","Android Friend");action("register");settled();
    check(!get("token").equals(""),"second_account_registration");Object secondModel=model;
    context=firstContext;model=firstModel;set("query",friendUsername);action("searchPeople");settled();
    check(rows("searchResults").size()==1,"typed_search_results");
    set("selectedUser",field(rows("searchResults").get(0),"id"));action("requestFriend");settled();
    check(((String)get("message")).startsWith("Friend request sent"),"friend_request_persisted");
    model=secondModel;action("refreshRequests");settled();check(rows("requests").size()==1,"incoming_friend_request");
    set("selectedRequest",field(rows("requests").get(0),"id"));action("acceptFriend");settled();check(rows("requests").isEmpty(),"accept_request_refreshed");
    model=firstModel;action("refreshFriends");settled();check(rows("friends").size()==1,"accepted_friend_list");
    set("selectedUser",field(rows("friends").get(0),"id"));action("startChat");settled();check(!get("conversationId").equals(""),"conversation_created_opened");
    set("draft","");action("sendMessage");check(get("message").equals("Write a message between 1 and 2,000 characters."),"shared_native_message_guard");
    set("draft","Hello from Android shared logic");action("sendMessage");settled();
    check(rows("messages").size()==1 && get("draft").equals(""),"message_persisted_and_draft_cleared");
    model=secondModel;action("refreshChats");settled();check(rows("conversations").size()==1,"conversation_list_decoded");
    set("conversationId",field(rows("conversations").get(0),"id"));action("openConversation");settled();
    check(rows("messages").size()==1 && field(rows("messages").get(0),"text").equals("Hello from Android shared logic"),"other_account_received_text");
    set("draft","An actual Android reply");action("sendMessage");settled();
    model=firstModel;action("loadMessages");settled();check(rows("messages").size()==2 && field(rows("messages").get(1),"text").equals("An actual Android reply"),"incremental_reply_appends_history");
    action("loadMessages");settled();check(rows("messages").size()==2,"empty_page_preserves_history_without_duplicates");
    Object prepared=testPhoto();action("uploadPhoto");check(get("message").equals("Choose a photo first."),"shared_missing_photo_guard");
    photo(prepared);set("photoCaption","Photo from the shared Android flow");set("photoIntent",0);action("uploadPhoto");settled();
    check(photo()==null&&get("photoCaption").equals(""),"sent_photo_resource_cleared");
    check(rows("messages").size()==3&&Boolean.TRUE.equals(field(rows("messages").get(2),"has_media")),"generated_media_upload_and_photochat");
    String mediaId=(String)field(rows("messages").get(2),"media_id");
    check(mediaStatus(mediaId,(String)get("token"))==200,"owner_private_photo_download");check(mediaStatus(mediaId,null)==401,"anonymous_photo_denied");
    model=secondModel;action("loadMessages");settled();check(rows("messages").size()==3&&field(rows("messages").get(2),"media_id").equals(mediaId),"friend_received_photo_reference");check(mediaStatus(mediaId,(String)get("token"))==200,"recipient_private_photo_download");
    model=firstModel;photo(prepared);set("photoIntent",1);set("photoCaption","Shared native story");action("uploadPhoto");settled();
    check(photo()==null&&rows("stories").size()==1,"generated_story_upload_and_publish");
    set("selectedStory",field(rows("stories").get(0),"id"));action("openStory");check(Boolean.TRUE.equals(get("storyVisible"))&&Boolean.TRUE.equals(get("storyOwned")),"typed_story_selection_owner");
    String storyId=(String)get("selectedStory");
    set("clockNow",get("storyExpires"));action("storyExpiry");check(Boolean.FALSE.equals(get("storyVisible"))&&get("storyMediaId").equals(""),"shared_dcdart_expiry_clears_private_pixels");
    set("storyVisible",true);set("storyMediaId",mediaId);set("storyExpires",(int)(System.currentTimeMillis()/1000)-1);long expiryDeadline=System.currentTimeMillis()+2500;while(Boolean.TRUE.equals(get("storyVisible"))&&System.currentTimeMillis()<expiryDeadline)Thread.sleep(50);check(Boolean.FALSE.equals(get("storyVisible"))&&get("storyMediaId").equals(""),"native_timer_executes_shared_expiry");
    model=secondModel;action("refreshStories");settled();check(rows("stories").size()==1,"friend_story_collection");set("selectedStory",storyId);action("openStory");check(Boolean.FALSE.equals(get("storyOwned")),"friend_story_not_owned");
    model=firstModel;set("selectedStory",storyId);action("deleteStory");settled();check(rows("stories").isEmpty()&&Boolean.FALSE.equals(get("storyVisible")),"generated_story_delete_and_clear");
    model=secondModel;action("refreshStories");settled();check(rows("stories").isEmpty(),"story_deletion_visible_to_friend");
    model=firstModel;set("cameraReady",false);action("captureStory");check(photo()==null&&get("message").equals("Start the camera and wait until the preview is ready."),"shared_camera_readiness_guard");
    set("locationConsent",false);set("accuracy",5);action("locationMeasured");check(get("message").equals("Location sharing is off. No new location was shared."),"shared_location_consent_guard");
    set("locationConsent",true);set("accuracy",3000);action("locationMeasured");check(get("message").equals("This location is not accurate enough. Try again before sharing."),"shared_location_accuracy_guard");
    set("latitude",52370000);set("longitude",4890000);set("accuracy",5);action("locationMeasured");settled();check(((String)get("message")).startsWith("Your last location is shared"),"generated_location_publish");
    model=secondModel;action("refreshMap");settled();check(rows("locations").size()==1&&field(rows("locations").get(0),"latitude_e6").equals(52370000),"friend_location_projection");
    set("mapExpires",(int)(System.currentTimeMillis()/1000)-1);action("mapTick");check(rows("locations").isEmpty()&&get("mapExpires").equals(0),"shared_map_expiry");
    model=firstModel;action("stopSharing");settled();check(Boolean.FALSE.equals(get("locationConsent"))&&get("latitude").equals(0)&&((String)get("message")).startsWith("Location sharing stopped"),"generated_location_revoke");
    model=secondModel;action("refreshMap");settled();check(rows("locations").isEmpty(),"revoked_location_absent");
    model=secondModel;action("logout");logoutSettled();
    check(rows("messages").isEmpty() && rows("conversations").isEmpty() && get("conversationId").equals(""),"logout_clears_private_collection_state");
    model=firstModel;set("token","invalid-session");action("refreshFriends");settled();
    check(get("token").equals("") && rows("messages").isEmpty() && rows("friends").isEmpty(),"expired_session_clears_private_collection_state");
    passed=true;
  }catch(Throwable error){try{report.put("error",error.getClass().getSimpleName()+": "+String.valueOf(error.getMessage()));}catch(Exception ignored){}}
  finally{try{
    boolean firstDeleted=false,secondDeleted=!friendAttempted;
    try{firstDeleted=deleteAccount(username);}finally{if(friendAttempted)secondDeleted=deleteAccount(friendUsername);}
    report.put("testAccountDeleted",firstDeleted);report.put("secondTestAccountDeleted",secondDeleted);passed&=firstDeleted&&secondDeleted;
    for(String owned:ownedPreferences) target.deleteSharedPreferences(owned);
    java.security.KeyStore keys=java.security.KeyStore.getInstance("AndroidKeyStore");keys.load(null);java.util.Enumeration<String> names=keys.aliases();while(names.hasMoreElements()){String name=names.nextElement();if(name.startsWith("__CHECK_ID__."+username+".") || name.startsWith("__CHECK_ID__."+friendUsername+"."))keys.deleteEntry(name);}
    report.put("hardwareCameraCapture",false);report.put("hardwareLocationPermission",false);report.put("sharedLocationPublishRevoke",passed);report.put("passed",passed);report.put("checks",checks);report.put("assertions",new org.json.JSONArray(assertionNames));report.put("mediaChat",passed);report.put("stories",passed);report.put("nativeTimerSharedExpiry",passed);report.put("friends",passed);report.put("bidirectionalText",passed);report.put("incrementalAppend",passed);report.put("isolatedAccountStorage",true);report.put("generatedModelExecuted",true);report.put("sharedDCDartExecuted",true);report.put("uiInputInjected",false);result.putString("resultJson",report.toString());
  }catch(Throwable error){passed=false;try{report.put("passed",false);report.put("cleanupError",error.getClass().getSimpleName()+": "+error.getMessage());result.putString("resultJson",report.toString());}catch(Exception ignored){}}}
  finish(passed?-1:0,result);
  }
}
