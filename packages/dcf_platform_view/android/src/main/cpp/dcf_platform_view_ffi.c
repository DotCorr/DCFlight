/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

#include <jni.h>
#include <stdint.h>

static JavaVM* g_vm = NULL;

JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* reserved) {
  (void)reserved;
  g_vm = vm;
  return JNI_VERSION_1_6;
}

void dcplatformview_set_surface_frame(double x, double y, double width, double height) {
  if (!g_vm) return;
  JNIEnv* env = NULL;
  (*g_vm)->GetEnv(g_vm, (void**)&env, JNI_VERSION_1_6);
  if (!env) {
    if ((*g_vm)->AttachCurrentThread(g_vm, &env, NULL) != JNI_OK) return;
  }
  jclass cls = (*env)->FindClass(env, "com/dotcorr/dcf_platform_view/DCFSurfaceViewFactory");
  if (!cls) return;
  jmethodID mid = (*env)->GetStaticMethodID(env, cls, "updateSurfaceFrameNative", "(DDDD)V");
  if (!mid) {
    (*env)->DeleteLocalRef(env, cls);
    return;
  }
  (*env)->CallStaticVoidMethod(env, cls, mid, (jdouble)x, (jdouble)y, (jdouble)width, (jdouble)height);
  (*env)->DeleteLocalRef(env, cls);
}
