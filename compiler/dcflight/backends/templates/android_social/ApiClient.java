package __PACKAGE__;

import org.json.JSONObject;
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;

/** Ordinary application HTTP client, with bounded responses and no credential-bearing redirects. */
final class ApiClient {
    interface Callback { void done(JSONObject result, byte[] bytes, String error, int status); }
    private final java.util.concurrent.ExecutorService workers = java.util.concurrent.Executors.newFixedThreadPool(3);
    private final android.os.Handler main = new android.os.Handler(android.os.Looper.getMainLooper());
    private final java.util.Set<HttpURLConnection> active = java.util.Collections.synchronizedSet(new java.util.HashSet<>());
    private volatile boolean closed;
    private final java.util.concurrent.atomic.AtomicInteger generation = new java.util.concurrent.atomic.AtomicInteger();
    volatile String token = "";
    void request(String method, String path, JSONObject json, byte[] upload, boolean binary, Callback callback) {
        if (closed) return;
        final int expected = generation.get(); final String credential = token;
        workers.execute(() -> {
            if (closed || expected != generation.get()) return;
            HttpURLConnection connection = null; JSONObject result = null; byte[] bytes = null; String error = null; int status = 0;
            try {
                connection = (HttpURLConnection) new URL(__BASE__ + "/v1" + path).openConnection(); active.add(connection);
                connection.setConnectTimeout(10000); connection.setReadTimeout(15000); connection.setInstanceFollowRedirects(false); connection.setRequestMethod(method);
                if (!credential.isEmpty()) connection.setRequestProperty("Authorization", "Bearer " + credential);
                if (json != null || upload != null) {
                    byte[] body = upload != null ? upload : json.toString().getBytes(StandardCharsets.UTF_8);
                    connection.setRequestProperty("Content-Type", upload != null ? "image/jpeg" : "application/json");
                    connection.setDoOutput(true); connection.setFixedLengthStreamingMode(body.length);
                    try (java.io.OutputStream out = connection.getOutputStream()) { out.write(body); }
                }
                status = connection.getResponseCode();
                try (InputStream input = status >= 400 ? connection.getErrorStream() : connection.getInputStream(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                    if (input != null) { byte[] chunk = new byte[8192]; int count; while ((count = input.read(chunk)) != -1) { if (output.size() + count > 8388608) throw new java.io.IOException("Response exceeds 8 MiB"); output.write(chunk, 0, count); } }
                    bytes = output.toByteArray();
                }
                if (!binary || status >= 300) result = bytes.length == 0 ? new JSONObject() : new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                if (status < 200 || status >= 300) error = result != null ? result.optString("detail", "Request failed (" + status + ")") : "Request failed (" + status + ")";
            } catch (Exception failure) { error = "Connection failed. Check your connection and retry. " + failure.getMessage(); }
            finally { if (connection != null) { active.remove(connection); connection.disconnect(); } }
            final JSONObject value = result; final byte[] data = bytes; final String message = error; final int code = status;
            if (!closed && expected == generation.get()) main.post(() -> { if (!closed && expected == generation.get()) callback.done(value, data, message, code); });
        });
    }
    void cancel() { generation.incrementAndGet(); synchronized (active) { for (HttpURLConnection connection : active) connection.disconnect(); active.clear(); } }
    void close() { closed = true; cancel(); workers.shutdownNow(); main.removeCallbacksAndMessages(null); }
}
