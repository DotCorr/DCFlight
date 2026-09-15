"""Compile typed presentation directly into ordinary Android views and resources."""
from __future__ import annotations
from . import Artifact
from .common import expression, symbol

SPECIAL = {'scroll', 'card', 'spacer', 'icon', 'image', 'progressBar'}
CLASSES = {'scroll': 'android.widget.ScrollView', 'card': 'android.widget.LinearLayout', 'spacer': 'android.view.View', 'icon': 'android.widget.ImageView', 'image': 'android.widget.ImageView', 'progressBar': 'android.widget.ProgressBar'}
TEXT = {'text', 'button', 'counter', 'textField', 'toggle'}
# Reviewed native vector resources. No runtime icon registry is generated.
PATHS = {
 'camera': 'M4,6H8L10,3H14L16,6H20V20H4Z M12,9A4,4 0,1 0,12,17A4,4 0,1 0,12,9',
 'image': 'M3,4H21V20H3Z M5,17L10,11L14,15L17,12L20,17 M7,7A1,1 0,1 0,7,9A1,1 0,1 0,7,7',
 'chat': 'M3,3H21V17H9L3,22Z M6,7H18 M6,11H15',
 'story': 'M12,2A10,10 0,1 0,22,12 M17,3L21,7 M9,7L17,12L9,17Z',
 'map': 'M3,5L9,2L15,5L21,2V19L15,22L9,19L3,22Z M9,2V19 M15,5V22',
 'person': 'M12,3A4,4 0,1 0,12,11A4,4 0,1 0,12,3 M4,21V18C4,11 20,11 20,18V21Z',
 'settings': 'M12,3L14,3L15,6L18,5L20,8L18,11L21,12L20,16L17,16L16,20L12,21L10,18L7,19L4,16L6,13L3,11L5,7L8,7L9,3Z M12,9A3,3 0,1 0,12,15A3,3 0,1 0,12,9',
 'add': 'M12,4V20 M4,12H20', 'close': 'M5,5L19,19 M19,5L5,19',
 'back': 'M14,4L6,12L14,20 M6,12H21', 'send': 'M3,3L22,12L3,21L6,12Z M6,12H22',
 'search': 'M10,3A7,7 0,1 0,10,17A7,7 0,1 0,10,3 M15,15L22,22',
 'heart': 'M12,21L3,12C-2,4 7,-1 12,6C17,-1 26,4 21,12Z',
 'check': 'M3,12L9,18L21,5', 'more': 'M4,11H6V13H4Z M11,11H13V13H11Z M18,11H20V13H18Z',
 'location': 'M12,22L5,12C0,0 24,0 19,12Z M12,6A3,3 0,1 0,12,12A3,3 0,1 0,12,6',
 'refresh': 'M20,9C18,0 4,0 3,11C2,21 18,25 21,15 M16,9H21V4',
 'flash': 'M13,2L4,14H11L10,22L21,9H14Z',
 'swap': 'M3,7H20L16,3 M21,17H4L8,21',
 'share': 'M8,12L17,6 M8,12L17,18 M5,9A3,3 0,1 0,5,15A3,3 0,1 0,5,9 M19,3A3,3 0,1 0,19,9A3,3 0,1 0,19,3 M19,15A3,3 0,1 0,19,21A3,3 0,1 0,19,15',
 'download': 'M12,2V16 M6,10L12,16L18,10 M3,17V22H21V17',
 'lock': 'M5,10H19V22H5Z M8,10V6C8,0 16,0 16,6V10',
 'bell': 'M4,18H20L18,15V9C18,1 6,1 6,9V15Z M9,21H15',
 'video': 'M2,5H16V19H2Z M16,10L23,6V18L16,14',
 'trash': 'M5,7H19L18,22H6Z M3,4H21 M9,4V1H15V4 M9,10V18 M15,10V18',
 'logout': 'M10,3H3V21H10 M9,12H22 M17,7L22,12L17,17',
 'inbox': 'M3,5H21V19H3Z M3,12H8L10,15H14L16,12H21',
 'home': 'M4,11L12,4L20,11 M6,9V20H10V14H14V20H18V9',
 'mail': 'M3,5H21V19H3Z M3,6L12,13L21,6',
 'calendar': 'M4,6H20V21H4Z M4,10H20 M8,3V8 M16,3V8 M8,13H10 M8,17H14',
 'star': 'M12,3L14.8,8.9L21,9.8L16.5,14.2L17.6,20.5L12,17.5L6.4,20.5L7.5,14.2L3,9.8L9.2,8.9Z',
 'flag': 'M6,21V4 M6,4H19L16,8.5L19,13H6',
 'clock': 'M12,2A10,10 0,1 0,22,12A10,10 0,1 0,2,12 M12,6V12L16,14',
 'folder': 'M3,6H10L12,8H21V20H3Z',
}
for alias, target in {'photos':'image', 'user':'person', 'flip':'swap'}.items(): PATHS[alias] = PATHS[target]


def color(value):
    """Canonical color strings are RGB or RGBA, Android literals are ARGB."""
    raw = value[1:]
    return '0x' + (raw[6:8] + raw[:6] if len(raw) == 8 else 'FF' + raw)


def style_value(node, key, default=None):
    value = getattr(getattr(node, 'style', None), key, None)
    return default if value is None else value


def dimension(node, key, fallback):
    value = style_value(node, key)
    return f'dp({value})' if value is not None else fallback


class Presentation:
    def __init__(self, app):
        self.app = app
        self.images = [n for n in app.nodes() if n.capability == 'image']
        self.animated = [n for n in app.nodes() if getattr(n, 'motion', None) is not None]
        self.visible = [n for n in app.nodes() if getattr(n, 'visible_when', None) is not None or getattr(n, 'motion', None) is not None]

    def class_name(self, node, mapping): return CLASSES.get(node.capability, mapping['className'])

    def construct(self, node, name, mapping):
        kind = self.class_name(node, mapping)
        args = 'activity, null, android.R.attr.progressBarStyleHorizontal' if node.capability == 'progressBar' else 'activity'
        expression = f'new {kind}({args})'
        maximum = style_value(node, 'max_width')
        if maximum is not None:
            expression += ' { @Override protected void onMeasure(int width, int height) { super.onMeasure(capWidth(width, dp(' + str(maximum) + ')), height); } }'
        return name + ' = ' + expression + ';'

    def setup(self, node, name):
        out = []
        cap, style = node.capability, getattr(node, 'style', None)
        if cap == 'card': out.append(name + '.setOrientation(android.widget.LinearLayout.VERTICAL);')
        if cap == 'scroll': out.append(name + '.setFillViewport(false);')
        if cap in ('icon', 'image'):
            out += [name + '.setScaleType(android.widget.ImageView.ScaleType.FIT_CENTER);', name + '.setAdjustViewBounds(true);']
        if cap == 'progressBar': out += [name + '.setIndeterminate(false);', name + '.setMax(100);']
        if cap in ('spacer', 'divider'):
            out.append(name + '.setImportantForAccessibility(android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO);')
        if style is None: return out
        padding = style_value(node, 'padding', 0)
        out += [name + '.setMinimumWidth(0);', name + '.setMinimumHeight(0);', f'{name}.setPadding(dp({padding}), dp({padding}), dp({padding}), dp({padding}));']
        if cap in TEXT:
            out += [name + '.setMinWidth(0);', name + '.setMinHeight(0);', name + '.setIncludeFontPadding(false);']
            if cap == 'button': out.append(name + '.setAllCaps(false);')
            size = style_value(node, 'font_size')
            if size is not None: out.append(f'{name}.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, {size});')
            weight = style_value(node, 'font_weight')
            if weight is not None:
                weights = {'regular':400, 'medium':500, 'semibold':600, 'bold':700}
                fallback = 'android.graphics.Typeface.BOLD' if weight == 'bold' else 'android.graphics.Typeface.NORMAL'
                out.append(f'if (android.os.Build.VERSION.SDK_INT >= 28) {name}.setTypeface(android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, {weights[weight]}, false)); else {name}.setTypeface(android.graphics.Typeface.create("sans-serif", {fallback}));')
        foreground = style_value(node, 'color')
        if foreground is not None:
            if cap in TEXT: out.append(f'{name}.setTextColor({color(foreground)});')
            elif cap in ('icon','image'): out.append(f'{name}.setColorFilter({color(foreground)}, android.graphics.PorterDuff.Mode.SRC_IN);')
            elif cap == 'progressBar': out.append(f'{name}.setProgressTintList(android.content.res.ColorStateList.valueOf({color(foreground)}));')
        align = style_value(node, 'align')
        if align is not None:
            if cap in ('row','column','card'):
                gravities = {'start':'TOP', 'center':'CENTER_VERTICAL', 'end':'BOTTOM'} if cap == 'row' else {'start':'START', 'center':'CENTER_HORIZONTAL', 'end':'END'}
                out.append(f'{name}.setGravity(android.view.Gravity.{gravities[align]});')
            if cap in TEXT:
                text_align = {'start':'VIEW_START', 'center':'CENTER', 'end':'VIEW_END'}[align]
                out.append(f'{name}.setTextAlignment(android.view.View.TEXT_ALIGNMENT_{text_align});')
        background, border = style_value(node, 'background'), style_value(node, 'border_color')
        radius, border_width = style_value(node, 'radius'), style_value(node, 'border_width', 0)
        if background is not None or border is not None or radius is not None or cap == 'button':
            drawable = 'background_' + node.id
            out.append(f'android.graphics.drawable.GradientDrawable {drawable} = new android.graphics.drawable.GradientDrawable();')
            out.append(f'{drawable}.setColor({color(background) if background else "android.graphics.Color.TRANSPARENT"});')
            if radius is not None: out += [f'{drawable}.setCornerRadius(dp({radius}));', name + '.setClipToOutline(true);']
            if border is not None: out.append(f'{drawable}.setStroke(dp({border_width}), {color(border)});')
            if node.action or cap == 'button':
                out.append(f'{name}.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x22000000), {drawable}, null));')
            else: out.append(f'{name}.setBackground({drawable});')
        if style_value(node, 'opacity') is not None: out.append(f'{name}.setAlpha({style_value(node, "opacity")} / 100f);')
        return out

    def updates(self, node, name):
        props, cap, out = node.props(), node.capability, []
        if cap == 'icon':
            value = expression(props['name'], 'android')
            out.append(f'{name}.setImageResource(R.drawable.app_icon_{props["name"].value});')
            out.append(f'{name}.setContentDescription({value});')
        elif cap == 'image': out.append(f'load_{node.id}({expression(props["source"], "android")});')
        elif cap == 'progressBar': out.append(f'{name}.setProgress({expression(props["value"], "android")});')
        if node.enabled_when is not None:
            out.append(f'{name}.setEnabled({expression(node.enabled_when, "android")});')
        condition = getattr(node, 'visible_when', None)
        if node in self.visible:
            out.append(f'visible_{node.id}({expression(condition, "android") if condition is not None else "true"});')
        return out

    def parent(self, parent, child, index):
        width = dimension(child, 'width', 'android.view.ViewGroup.LayoutParams.MATCH_PARENT' if style_value(child, 'fill', False) or child.capability == 'divider' else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT')
        height = dimension(child, 'height', 'dp(1)' if child.capability == 'divider' else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT')
        if child.capability == 'icon':
            width = dimension(child, 'width', 'dp(24)'); height = dimension(child, 'height', 'dp(24)')
        container = 'android.widget.FrameLayout' if parent.capability == 'scroll' else 'android.widget.LinearLayout'
        weight = ''
        if parent.capability == 'row' and style_value(child, 'width') is None and (style_value(child, 'fill', False) or child.capability == 'spacer'):
            width, weight = '0', ', 1f'
        elif parent.capability in ('column','card') and child.capability == 'spacer' and style_value(child, 'height') is None:
            height, weight = '0', ', 1f'
        variable = 'layout_' + child.id
        out = [f'{container}.LayoutParams {variable} = new {container}.LayoutParams({width}, {height}{weight});']
        gap = style_value(parent, 'gap', 0)
        if index and gap:
            out.append(f'{variable}.setMarginStart(dp({gap}));' if parent.capability == 'row' else f'{variable}.topMargin = dp({gap});')
        out.append(f'{symbol(parent.id)}.addView({symbol(child.id)}, {variable});')
        return out

    def root_layout(self):
        node = self.app.root
        if getattr(node, 'style', None) is None: return []
        width = dimension(node, 'width', 'android.view.ViewGroup.LayoutParams.MATCH_PARENT' if style_value(node, 'fill', False) else 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT')
        height = dimension(node, 'height', 'android.view.ViewGroup.LayoutParams.WRAP_CONTENT')
        return [f'root.setLayoutParams(new android.widget.FrameLayout.LayoutParams({width}, {height}));']

    def declarations(self):
        fields = ['    private final android.app.Activity activity;', '    private final float density;', '    private boolean disposed;']
        if self.images:
            fields += ['    private final java.util.concurrent.ExecutorService imageWorkers = java.util.concurrent.Executors.newFixedThreadPool(2);', '    private final android.os.Handler imageMain = new android.os.Handler(android.os.Looper.getMainLooper());']
        for node in self.images:
            fields += [f'    private String source_{node.id};', f'    private Object token_{node.id};', f'    private java.util.concurrent.Future<?> request_{node.id};']
        for node in self.visible:
            fields += [f'    private boolean shown_{node.id};', f'    private boolean initial_{node.id} = true;']
        return '\n'.join(fields)

    def methods(self):
        methods = ['''    private int dp(int value) { return Math.round(value * density); }
    private static int capWidth(int measure, int maximum) {
        int mode = android.view.View.MeasureSpec.getMode(measure);
        int size = android.view.View.MeasureSpec.getSize(measure);
        return android.view.View.MeasureSpec.makeMeasureSpec(mode == android.view.View.MeasureSpec.UNSPECIFIED ? maximum : Math.min(size, maximum), mode == android.view.View.MeasureSpec.UNSPECIFIED ? android.view.View.MeasureSpec.AT_MOST : mode);
    }
    public void dispose() {
        if (disposed) return;
        disposed = true;
''' + ('        imageWorkers.shutdownNow();\n        imageMain.removeCallbacksAndMessages(null);\n' if self.images else '') + '\n'.join(f'        {symbol(n.id)}.animate().cancel();' for n in self.visible) + '\n    }']
        for node in self.visible:
            motion, name = getattr(node, 'motion', None), symbol(node.id)
            opacity = style_value(node, 'opacity', 100)
            duration = getattr(motion, 'duration_ms', 0) if motion else 0
            kind = getattr(motion, 'kind', 'fade') if motion else 'fade'
            start = f'{name}.setTranslationY(dp(16));' if kind == 'slide' else f'{name}.setScaleX(0.95f); {name}.setScaleY(0.95f);' if kind == 'scale' else ''
            methods.append(f'''    private void visible_{node.id}(boolean show) {{
        if (!initial_{node.id} && shown_{node.id} == show) return;
        initial_{node.id} = false; shown_{node.id} = show;
        {name}.animate().cancel();
        if (!android.animation.ValueAnimator.areAnimatorsEnabled() || {duration} == 0) {{
            {name}.setVisibility(show ? android.view.View.VISIBLE : android.view.View.GONE);
            {name}.setAlpha({opacity} / 100f); {name}.setTranslationY(0); {name}.setScaleX(1); {name}.setScaleY(1); return;
        }}
        if (show) {{
            {name}.setVisibility(android.view.View.VISIBLE); {name}.setAlpha(0); {start}
            {name}.animate().alpha({opacity} / 100f).translationY(0).scaleX(1).scaleY(1).setDuration({duration}).start();
        }} else {{
            {name}.animate().alpha(0).setDuration({duration}).withEndAction(() -> {{ if (!shown_{node.id}) {name}.setVisibility(android.view.View.GONE); }}).start();
        }}
    }}''')
        if self.images:
            methods.append(IMAGE_READER)
            for node in self.images:
                name, identity = symbol(node.id), node.id
                methods.append(IMAGE_METHOD.replace('__ID__', identity).replace('__VIEW__', name))
        return '\n'.join(methods)

    def resources(self):
        if not any(n.capability == 'icon' for n in self.app.nodes()): return {}
        return {'android/app/src/main/res/drawable/app_icon_' + name + '.xml': Artifact('<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:pathData="' + path + '" android:fillColor="#00000000" android:strokeColor="#FF111111" android:strokeWidth="1.8" android:strokeLineCap="round" android:strokeLineJoin="round"/></vector>\n') for name, path in PATHS.items()}


IMAGE_READER = '''    private static android.graphics.Bitmap readImage(String source) throws java.io.IOException {
        java.net.URL address = new java.net.URL(source);
        for (int redirects = 0; redirects < 5; redirects++) {
            if (!"https".equals(address.getProtocol())) throw new java.io.IOException("Only HTTPS images are supported");
            javax.net.ssl.HttpsURLConnection connection = (javax.net.ssl.HttpsURLConnection) address.openConnection();
            connection.setConnectTimeout(10000); connection.setReadTimeout(10000); connection.setInstanceFollowRedirects(false);
            try {
                int status = connection.getResponseCode();
                if (status >= 300 && status < 400) {
                    String location = connection.getHeaderField("Location");
                    if (location == null) throw new java.io.IOException("Image redirect missing location");
                    address = new java.net.URL(address, location); continue;
                }
                if (status != 200) throw new java.io.IOException("Image HTTP status " + status);
                try (java.io.InputStream input = connection.getInputStream(); java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream()) {
                    byte[] buffer = new byte[8192]; int count;
                    while ((count = input.read(buffer)) != -1) {
                        if (Thread.currentThread().isInterrupted()) throw new java.io.InterruptedIOException();
                        if (output.size() + count > 8 * 1024 * 1024) throw new java.io.IOException("Image exceeds download limit");
                        output.write(buffer, 0, count);
                    }
                    byte[] data = output.toByteArray(); android.graphics.BitmapFactory.Options options = new android.graphics.BitmapFactory.Options();
                    options.inJustDecodeBounds = true; android.graphics.BitmapFactory.decodeByteArray(data, 0, data.length, options);
                    if (options.outWidth <= 0 || options.outHeight <= 0) throw new java.io.IOException("Unsupported image");
                    options.inSampleSize = 1;
                    while (options.outWidth / options.inSampleSize > 2048 || options.outHeight / options.inSampleSize > 2048) options.inSampleSize *= 2;
                    options.inJustDecodeBounds = false;
                    android.graphics.Bitmap bitmap = android.graphics.BitmapFactory.decodeByteArray(data, 0, data.length, options);
                    if (bitmap == null) throw new java.io.IOException("Image decode failed");
                    return bitmap;
                }
            } finally { connection.disconnect(); }
        }
        throw new java.io.IOException("Too many image redirects");
    }
'''

IMAGE_METHOD = '''    private void load___ID__(String source) {
        if (disposed || java.util.Objects.equals(source___ID__, source)) return;
        source___ID__ = source; Object token = new Object(); token___ID__ = token;
        if (request___ID__ != null) request___ID__.cancel(true);
        __VIEW__.setImageResource(android.R.drawable.ic_menu_gallery);
        __VIEW__.setContentDescription("Loading image");
        if (source != null && source.startsWith("asset:")) {
            int resource = activity.getResources().getIdentifier(source.substring(6), "drawable", activity.getPackageName());
            __VIEW__.setImageResource(resource != 0 ? resource : android.R.drawable.ic_menu_report_image);
            __VIEW__.setContentDescription(resource != 0 ? "Image" : "Image unavailable"); return;
        }
        request___ID__ = imageWorkers.submit(() -> {
            try {
                android.graphics.Bitmap bitmap = readImage(source);
                imageMain.post(() -> { if (!disposed && token___ID__ == token) { __VIEW__.setImageBitmap(bitmap); __VIEW__.setContentDescription("Image"); } });
            } catch (Exception error) {
                imageMain.post(() -> { if (!disposed && token___ID__ == token) { __VIEW__.setImageResource(android.R.drawable.ic_menu_report_image); __VIEW__.setContentDescription("Image unavailable"); } });
            }
        });
    }
'''
