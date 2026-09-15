"""Native MapLibre views and compiled native annotation content."""
from . import Artifact,HEADER

def artifacts(app):
 if not getattr(app,'map_config',None):return {}
 return {'android/app/src/main/java/'+app.id.replace('.','/')+'/NativeMap.kt':Artifact(HEADER+NATIVE.replace('__PACKAGE__',app.id))}

NATIVE=r'''package __PACKAGE__
import androidx.compose.runtime.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.*
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.annotations.IconFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.camera.CameraUpdateFactory

@Composable fun <T> NativeMap(rows:List<T>,annotationKeys:List<Any>,keyOf:(T)->String,latitude:(T)->Int,longitude:(T)->Int,title:(T)->String,centerLatitude:Int,centerLongitude:Int,latitudeSpan:Int,longitudeSpan:Int,styleUrl:String,attribution:String,modifier:Modifier,onSelect:(T)->Unit,annotation:@Composable (T)->Unit,loading:@Composable ()->Unit,failure:@Composable ()->Unit){
    val context=LocalContext.current
    val lifecycle=androidx.lifecycle.compose.LocalLifecycleOwner.current.lifecycle
    val composition=rememberCompositionContext()
    val density=LocalDensity.current
    val select by rememberUpdatedState(onSelect)
    val drawAnnotation by rememberUpdatedState(annotation)
    var ready by remember{mutableStateOf(false)}
    var failed by remember{mutableStateOf(false)}
    var annotationFailed by remember{mutableStateOf(false)}
    var map by remember{mutableStateOf<MapLibreMap?>(null)}
    val selectedRows=remember{mutableMapOf<Long,T>()}
    val view=remember(context,styleUrl){org.maplibre.android.MapLibre.getInstance(context);MapView(context).also{it.onCreate(null)}}
    DisposableEffect(view,lifecycle){
        val live=java.util.concurrent.atomic.AtomicBoolean(true)
        var started=false;var resumed=false
        fun update(){val state=lifecycle.currentState;if(state.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED)&&!started){view.onStart();started=true};if(state.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)&&!resumed){view.onResume();resumed=true};if(!state.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)&&resumed){view.onPause();resumed=false};if(!state.isAtLeast(androidx.lifecycle.Lifecycle.State.STARTED)&&started){view.onStop();started=false}}
        val observer=androidx.lifecycle.LifecycleEventObserver{_,_->update()};lifecycle.addObserver(observer);update()
        val callbacks=object:android.content.ComponentCallbacks2{override fun onConfigurationChanged(config:android.content.res.Configuration){};override fun onLowMemory(){view.onLowMemory()};override fun onTrimMemory(level:Int){if(level>=android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW)view.onLowMemory()}}
        context.applicationContext.registerComponentCallbacks(callbacks)
        view.addOnDidFailLoadingMapListener{if(live.get()){failed=true;ready=false}}
        view.getMapAsync{native->if(!live.get())return@getMapAsync;map=native;native.uiSettings.isAttributionEnabled=true;native.setOnMarkerClickListener{marker->selectedRows[marker.id]?.let{select(it)};true};native.setStyle(styleUrl){if(!live.get())return@setStyle;ready=true;failed=false;val bounds=LatLngBounds.Builder().include(LatLng((centerLatitude+latitudeSpan/2.0)/1e6,(centerLongitude+longitudeSpan/2.0)/1e6)).include(LatLng((centerLatitude-latitudeSpan/2.0)/1e6,(centerLongitude-longitudeSpan/2.0)/1e6)).build();view.post{if(live.get()&&view.width>0&&view.height>0)native.moveCamera(CameraUpdateFactory.newLatLngBounds(bounds,0))}}}
        onDispose{live.set(false);lifecycle.removeObserver(observer);context.applicationContext.unregisterComponentCallbacks(callbacks);selectedRows.clear();map?.clear();if(resumed)view.onPause();if(started)view.onStop();view.onDestroy();map=null}
    }
    LaunchedEffect(rows,ready,map,annotationKeys,density.density,density.fontScale){
        val native=map
        if(ready&&native!=null){native.clear();selectedRows.clear();annotationFailed=false
            try{
                val keys=mutableSetOf<String>()
                for(row in rows){val lat=latitude(row);val lon=longitude(row);if(lat !in -85051128..85051128||lon !in -180000000..180000000||!keys.add(keyOf(row)))throw IllegalArgumentException("map_coordinate_or_key")
                    // This is an ordinary compiled Compose view rendered using native View APIs.
                    val content=ComposeView(context);content.setParentCompositionContext(composition);content.setContent{drawAnnotation(row)}
                    var bitmap:Bitmap?=null
                    try{view.addView(content,android.widget.FrameLayout.LayoutParams(-2,-2));content.alpha=0f;content.measure(View.MeasureSpec.makeMeasureSpec(1024,View.MeasureSpec.AT_MOST),View.MeasureSpec.makeMeasureSpec(1024,View.MeasureSpec.AT_MOST));content.layout(0,0,content.measuredWidth,content.measuredHeight);if(content.width<1||content.height<1)throw IllegalArgumentException("map_annotation_size");bitmap=Bitmap.createBitmap(content.width,content.height,Bitmap.Config.ARGB_8888);content.draw(Canvas(bitmap));val icon=IconFactory.getInstance(context).fromBitmap(bitmap);val marker=native.addMarker(MarkerOptions().position(LatLng(lat/1e6,lon/1e6)).title(title(row)).icon(icon));selectedRows[marker.id]=row}
                    finally{content.disposeComposition();view.removeView(content)}
                }
            }catch(error:Exception){native.clear();selectedRows.clear();annotationFailed=true}
        }
    }
    Column(modifier){Box(Modifier.weight(1f)){androidx.compose.ui.viewinterop.AndroidView(factory={view},modifier=Modifier.fillMaxSize());if(annotationFailed)failure()else if(!ready){if(failed)failure()else loading()}};Text(attribution)}
}
'''
