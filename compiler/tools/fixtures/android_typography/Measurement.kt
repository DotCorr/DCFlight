package com.dotcorr.typographyprobe
import android.app.Instrumentation
import android.app.Activity
import android.os.Bundle
import androidx.compose.material3.Typography
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.font.createFontFamilyResolver
import androidx.compose.ui.unit.*
import org.json.JSONObject
class Measurement:Instrumentation() {
 override fun onCreate(arguments:Bundle?){super.onCreate(arguments);start()}
 override fun onStart(){
  val result=Bundle()
  try {
   runOnMainSync {
    val density=Density(targetContext)
    val measurer=TextMeasurer(createFontFamilyResolver(targetContext),density,LayoutDirection.Ltr)
    val inherited=Typography().bodyLarge
    val old=measurer.measure(AnnotatedString("Somewhere\nclose."),style=inherited.copy(fontSize=40.sp),constraints=Constraints(maxWidth=1200))
    val fixed=measurer.measure(AnnotatedString("Somewhere\nclose."),style=inherited.copy(lineHeight=TextUnit.Unspecified).merge(androidx.compose.ui.text.TextStyle(fontSize=40.sp)),constraints=Constraints(maxWidth=1200))
    check(old.lineCount==2&&fixed.lineCount==2)
    val oldStep=old.getLineBaseline(1)-old.getLineBaseline(0)
    val fixedStep=fixed.getLineBaseline(1)-fixed.getLineBaseline(0)
    check(fixedStep>oldStep) { "Natural line metrics did not exceed inherited line height" }
    fun scaled(scale:Float):JSONObject {
     val configuration=android.content.res.Configuration(targetContext.resources.configuration)
     configuration.fontScale=scale
     val context=targetContext.createConfigurationContext(configuration)
     val localDensity=Density(context)
     val localMeasurer=TextMeasurer(createFontFamilyResolver(context),localDensity,LayoutDirection.Ltr)
     val measured=localMeasurer.measure(AnnotatedString("Somewhere\nclose."),style=inherited.copy(lineHeight=TextUnit.Unspecified).merge(androidx.compose.ui.text.TextStyle(fontSize=40.sp)),constraints=Constraints(maxWidth=10000))
     check(measured.lineCount==2)
     return JSONObject().put("fontScale",localDensity.fontScale).put("density",localDensity.density).put("height",measured.size.height).put("width",measured.size.width).put("firstBaseline",measured.firstBaseline).put("baselineStep",measured.getLineBaseline(1)-measured.getLineBaseline(0))
    }
    val scaleOne=scaled(1f);val scaleTwo=scaled(2f)
    for(metric in listOf("height","width","firstBaseline","baselineStep")) {
     check(scaleTwo.getDouble(metric)>scaleOne.getDouble(metric)) { "Font scaling did not increase $metric" }
    }
    val scaling=JSONObject().put("scale1",scaleOne).put("scale2",scaleTwo).put("grows",true).put("systemSettingsChanged",false)
    result.putString("measurement",JSONObject().put("density",density.density).put("fontScale",density.fontScale).put("oldHeight",old.size.height).put("fixedHeight",fixed.size.height).put("oldBaselineStep",oldStep).put("fixedBaselineStep",fixedStep).put("scaling",scaling).toString())
   }
   finish(Activity.RESULT_OK,result)
  }catch(error:Throwable){result.putString("failure",error.stackTraceToString());finish(Activity.RESULT_CANCELED,result)}
 }
}
