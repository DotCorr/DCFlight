package com.dotcorr.mapchecks
import android.app.Instrumentation
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.ui.unit.dp
import com.dotcorr.snapshared.NativeMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
class MapChecks:Instrumentation(){
 var count=0
 fun check(value:Boolean){count++;if(!value)throw AssertionError("check $count")}
 fun waitFor(test:()->Boolean){val deadline=System.currentTimeMillis()+60000;while(System.currentTimeMillis()<deadline){var value=false;runOnMainSync{value=test()};if(value)return;Thread.sleep(100)};throw AssertionError("Native map timed out")}
 fun find(view:android.view.View):MapView? {if(view is MapView)return view;if(view is android.view.ViewGroup)for(i in 0 until view.childCount){val found=find(view.getChildAt(i));if(found!=null)return found};return null}
 override fun onCreate(args:Bundle?){super.onCreate(args);start()}
 override fun onStart(){val result=org.json.JSONObject();var passed=false;var activity:ComponentActivity?=null
 try{
 val intent=targetContext.packageManager.getLaunchIntentForPackage(targetContext.packageName)!!.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
 activity=startActivitySync(intent) as ComponentActivity
 var label by mutableStateOf("A");var latitude by mutableStateOf(52000000)
 val host=activity
 runOnMainSync {host.setContent {NativeMap(listOf(latitude),listOf(label),{"one"},{it},{5000000},{label},52000000,5000000,10000000,10000000,"https://tiles.openfreemap.org/styles/liberty","OpenFreeMap · OpenMapTiles · OpenStreetMap",Modifier.fillMaxSize(),{}, {Text(label,Modifier.padding(8.dp))},{Text("Authored test loading")},{Text("Authored test failure")})}}
 var map:MapLibreMap?=null
 waitFor{val view=find(host.window.decorView);if(view!=null){view.getMapAsync{map=it};true}else false}
 waitFor{map?.style?.isFullyLoaded==true};check(true)
 waitFor{map?.markers?.size==1};check(true)
 var width=0
 runOnMainSync{val bitmap=map!!.markers[0].icon!!.bitmap;width=bitmap.width;check(width>0&&bitmap.height>0);val pixels=IntArray(bitmap.width*bitmap.height);bitmap.getPixels(pixels,0,bitmap.width,0,0,bitmap.width,bitmap.height);check(pixels.any{android.graphics.Color.alpha(it)>0});label="An authored annotation update"}
 waitFor{map?.markers?.firstOrNull()?.icon?.bitmap?.width?.let{it>width}==true};check(true)
 runOnMainSync{latitude=90000000};waitFor{map?.markers?.isEmpty()==true};check(true)
 runOnMainSync{latitude=51000000};waitFor{map?.markers?.size==1};check(true)
 passed=true
 }catch(error:Throwable){result.put("failure",android.util.Log.getStackTraceString(error))}finally{activity?.let{runOnMainSync{it.finish()}}}
 result.put("passed",passed).put("checks",count).put("sdk",android.os.Build.VERSION.SDK_INT);val bundle=Bundle();bundle.putString("resultJson",result.toString());finish(if(passed)-1 else 0,bundle)
 }
}
