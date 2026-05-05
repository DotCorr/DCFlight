package com.dotcorr.dcflight.bridge;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

public class DCFlightJniBindings {
    public interface EventCallback {
        void onEvent(int viewId, String eventType, String eventDataJson);
    }

    public interface ScreenDimensionsCallback {
        void onDimensionsChanged(String dimensionsJson);
    }

    private static final String TARGET_CLASS_NAME = "com.dotcorr.dcflight.bridge.DCFlightJni";
    private static final String EVENT_CALLBACK_CLASS_NAME = "com.dotcorr.dcflight.bridge.DCFlightJni$Companion$EventCallback";
    private static final String SCREEN_CALLBACK_CLASS_NAME = "com.dotcorr.dcflight.bridge.DCFlightJni$Companion$ScreenDimensionsCallback";

    private final Object delegate;

    public DCFlightJniBindings(Object context) {
        try {
            final Class<?> targetClass = Class.forName(TARGET_CLASS_NAME);
            this.delegate = targetClass.getConstructors()[0].newInstance(context);
        } catch (Exception e) {
            throw new RuntimeException("Failed to construct DCFlightJni delegate", e);
        }
    }

    public static void setEventCallback(final EventCallback callback) {
        invokeStaticCallbackSetter("setEventCallback", EVENT_CALLBACK_CLASS_NAME, callback == null ? null : proxyEventCallback(callback));
    }

    public static void setScreenDimensionsCallback(final ScreenDimensionsCallback callback) {
        invokeStaticCallbackSetter("setScreenDimensionsCallback", SCREEN_CALLBACK_CLASS_NAME, callback == null ? null : proxyScreenDimensionsCallback(callback));
    }

    public boolean initialize() {
        return invokeBoolean("initialize");
    }

    public boolean createView(int viewId, String viewType, String propsJson) {
        return invokeBoolean("createView", viewId, viewType, propsJson);
    }

    public boolean updateView(int viewId, String propsJson) {
        return invokeBoolean("updateView", viewId, propsJson);
    }

    public boolean deleteView(int viewId) {
        return invokeBoolean("deleteView", viewId);
    }

    public boolean detachView(int viewId) {
        return invokeBoolean("detachView", viewId);
    }

    public boolean attachView(int childId, int parentId, int index) {
        return invokeBoolean("attachView", childId, parentId, index);
    }

    public boolean setChildren(int viewId, String childrenIdsJson) {
        return invokeBoolean("setChildren", viewId, childrenIdsJson);
    }

    public boolean addEventListeners(int viewId, String eventTypesJson) {
        return invokeBoolean("addEventListeners", viewId, eventTypesJson);
    }

    public boolean removeEventListeners(int viewId, String eventTypesJson) {
        return invokeBoolean("removeEventListeners", viewId, eventTypesJson);
    }

    public boolean startBatchUpdate() {
        return invokeBoolean("startBatchUpdate");
    }

    public boolean commitBatchUpdate(String updatesJson) {
        return invokeBoolean("commitBatchUpdate", updatesJson);
    }

    public boolean cancelBatchUpdate() {
        return invokeBoolean("cancelBatchUpdate");
    }

    public String tunnel(String componentType, String method, String paramsJson) {
        return invokeString("tunnel", componentType, method, paramsJson);
    }

    public String getScreenDimensions() {
        return invokeString("getScreenDimensions");
    }

    public String getSessionToken() {
        return invokeString("getSessionToken");
    }

    public String createSessionToken() {
        return invokeString("createSessionToken");
    }

    public void clearSessionToken() {
        invokeVoid("clearSessionToken");
    }

    public void cleanupViews() {
        invokeVoid("cleanupViews");
    }

    public String consumePendingEvents() {
        return invokeStaticString("consumePendingEvents");
    }

    private boolean invokeBoolean(String methodName, Object... args) {
        final Object result = invokeInstance(methodName, args);
        return result instanceof Boolean && (Boolean) result;
    }

    private String invokeString(String methodName, Object... args) {
        final Object result = invokeInstance(methodName, args);
        return result == null ? null : result.toString();
    }

    private void invokeVoid(String methodName, Object... args) {
        invokeInstance(methodName, args);
    }

    private static String invokeStaticString(String methodName, Object... args) {
        try {
            final Class<?> targetClass = Class.forName(TARGET_CLASS_NAME);
            final Method method = findMethod(targetClass, methodName, args.length);
            final Object result = method.invoke(null, args);
            return result == null ? null : result.toString();
        } catch (Exception e) {
            throw new RuntimeException("Failed to invoke static method: " + methodName, e);
        }
    }

    private Object invokeInstance(String methodName, Object... args) {
        try {
            final Method method = findMethod(delegate.getClass(), methodName, args.length);
            return method.invoke(delegate, args);
        } catch (Exception e) {
            throw new RuntimeException("Failed to invoke delegate method: " + methodName, e);
        }
    }

    private static void invokeStaticCallbackSetter(String methodName, String callbackClassName, Object callbackProxy) {
        try {
            final Class<?> targetClass = Class.forName(TARGET_CLASS_NAME);
            final Class<?> callbackClass = Class.forName(callbackClassName);
            final Method method = targetClass.getMethod(methodName, callbackClass);
            method.invoke(null, callbackProxy);
        } catch (Exception e) {
            throw new RuntimeException("Failed to invoke static callback setter: " + methodName, e);
        }
    }

    private static Object proxyEventCallback(final EventCallback callback) {
        return buildProxy(EVENT_CALLBACK_CLASS_NAME, (proxy, method, args) -> {
            if ("onEvent".equals(method.getName()) && args != null && args.length == 3) {
                callback.onEvent(((Integer) args[0]).intValue(), (String) args[1], (String) args[2]);
                return null;
            }
            return defaultObjectMethod(proxy, method, args);
        });
    }

    private static Object proxyScreenDimensionsCallback(final ScreenDimensionsCallback callback) {
        return buildProxy(SCREEN_CALLBACK_CLASS_NAME, (proxy, method, args) -> {
            if ("onDimensionsChanged".equals(method.getName()) && args != null && args.length == 1) {
                callback.onDimensionsChanged((String) args[0]);
                return null;
            }
            return defaultObjectMethod(proxy, method, args);
        });
    }

    private static Object buildProxy(String className, InvocationHandler handler) {
        try {
            final Class<?> interfaceClass = Class.forName(className);
            return Proxy.newProxyInstance(interfaceClass.getClassLoader(), new Class<?>[]{interfaceClass}, handler);
        } catch (Exception e) {
            throw new RuntimeException("Failed to create proxy for " + className, e);
        }
    }

    private static Method findMethod(Class<?> clazz, String methodName, int argCount) {
        for (Method method : clazz.getMethods()) {
            if (method.getName().equals(methodName) && method.getParameterTypes().length == argCount) {
                return method;
            }
        }
        throw new IllegalStateException("Method not found: " + methodName + " with argCount=" + argCount);
    }

    private static Object defaultObjectMethod(Object proxy, Method method, Object[] args) {
        final String name = method.getName();
        if ("toString".equals(name)) {
            return proxy.getClass().getName();
        }
        if ("hashCode".equals(name)) {
            return System.identityHashCode(proxy);
        }
        if ("equals".equals(name)) {
            return proxy == args[0];
        }
        return null;
    }
}
