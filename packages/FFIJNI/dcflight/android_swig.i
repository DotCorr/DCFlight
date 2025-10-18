%module android_swig

%{
#include <jni.h>
%}

%include "various.i"

// Basic Android classes
class android_view_View {
public:
    android_view_View();
    ~android_view_View();
    void setBackgroundColor(int color);
    void setVisibility(int visibility);
    void requestLayout();
    void invalidate();
};

class android_view_ViewGroup {
public:
    android_view_ViewGroup();
    ~android_view_ViewGroup();
    void addView(android_view_View child);
    void removeView(android_view_View child);
    void removeAllViews();
};

class android_widget_TextView {
public:
    android_widget_TextView();
    ~android_widget_TextView();
    void setText(const char* text);
    const char* getText();
    void setTextColor(int color);
    void setTextSize(float size);
};

class android_widget_Button {
public:
    android_widget_Button();
    ~android_widget_Button();
    void setText(const char* text);
    const char* getText();
};

class android_widget_ImageView {
public:
    android_widget_ImageView();
    ~android_widget_ImageView();
    void setImageResource(int resId);
};

class android_app_Activity {
public:
    android_app_Activity();
    ~android_app_Activity();
    void setContentView(android_view_View view);
    void finish();
};

class android_content_Context {
public:
    android_content_Context();
    ~android_content_Context();
    const char* getPackageName();
};

class android_graphics_Canvas {
public:
    android_graphics_Canvas();
    ~android_graphics_Canvas();
    void drawRect(float left, float top, float right, float bottom, android_graphics_Paint paint);
    void drawText(const char* text, float x, float y, android_graphics_Paint paint);
};

class android_graphics_Paint {
public:
    android_graphics_Paint();
    ~android_graphics_Paint();
    void setColor(int color);
    void setTextSize(float size);
    void setStyle(int style);
};

class android_webkit_WebView {
public:
    android_webkit_WebView();
    ~android_webkit_WebView();
    void loadUrl(const char* url);
};