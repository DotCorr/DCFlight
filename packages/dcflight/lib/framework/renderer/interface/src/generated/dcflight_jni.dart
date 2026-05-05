// Handwritten JNI bindings for DCFlightJniBindings.
//
// JNI generation is currently blocked by jnigen config/tooling issues in this
// workspace, so this file provides the minimal binding surface used by
// DCFlightJniWrapper.

import 'package:jni/jni.dart' as jni;

class DCFlightJni extends jni.JObject {
  DCFlightJni.fromReference(super.reference) : super.fromReference();

  static final jni.JClass _class =
      jni.JClass.forName(r'com/dotcorr/dcflight/bridge/DCFlightJniBindings');
  static final jni.JConstructorId _constructor =
      _class.constructorId(r'(Ljava/lang/Object;)V');

  static final jni.JStaticMethodId _setEventCallback = _class.staticMethodId(
    r'setEventCallback',
    r'(Lcom/dotcorr/dcflight/bridge/DCFlightJniBindings$EventCallback;)V',
  );
  static final jni.JStaticMethodId _setScreenDimensionsCallback =
      _class.staticMethodId(
    r'setScreenDimensionsCallback',
    r'(Lcom/dotcorr/dcflight/bridge/DCFlightJniBindings$ScreenDimensionsCallback;)V',
  );

  static final jni.JInstanceMethodId _initialize =
      _class.instanceMethodId(r'initialize', r'()Z');
  static final jni.JInstanceMethodId _createView =
      _class.instanceMethodId(r'createView', r'(ILjava/lang/String;Ljava/lang/String;)Z');
  static final jni.JInstanceMethodId _updateView =
      _class.instanceMethodId(r'updateView', r'(ILjava/lang/String;)Z');
  static final jni.JInstanceMethodId _deleteView =
      _class.instanceMethodId(r'deleteView', r'(I)Z');
  static final jni.JInstanceMethodId _detachView =
      _class.instanceMethodId(r'detachView', r'(I)Z');
  static final jni.JInstanceMethodId _attachView =
      _class.instanceMethodId(r'attachView', r'(III)Z');
  static final jni.JInstanceMethodId _setChildren =
      _class.instanceMethodId(r'setChildren', r'(ILjava/lang/String;)Z');
  static final jni.JInstanceMethodId _addEventListeners =
      _class.instanceMethodId(r'addEventListeners', r'(ILjava/lang/String;)Z');
  static final jni.JInstanceMethodId _removeEventListeners =
      _class.instanceMethodId(r'removeEventListeners', r'(ILjava/lang/String;)Z');
  static final jni.JInstanceMethodId _startBatchUpdate =
      _class.instanceMethodId(r'startBatchUpdate', r'()Z');
  static final jni.JInstanceMethodId _commitBatchUpdate =
      _class.instanceMethodId(r'commitBatchUpdate', r'(Ljava/lang/String;)Z');
  static final jni.JInstanceMethodId _cancelBatchUpdate =
      _class.instanceMethodId(r'cancelBatchUpdate', r'()Z');
  static final jni.JInstanceMethodId _tunnel = _class.instanceMethodId(
    r'tunnel',
    r'(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;',
  );
  static final jni.JInstanceMethodId _getScreenDimensions =
      _class.instanceMethodId(r'getScreenDimensions', r'()Ljava/lang/String;');
  static final jni.JInstanceMethodId _getSessionToken =
      _class.instanceMethodId(r'getSessionToken', r'()Ljava/lang/String;');
  static final jni.JInstanceMethodId _createSessionToken =
      _class.instanceMethodId(r'createSessionToken', r'()Ljava/lang/String;');
  static final jni.JInstanceMethodId _clearSessionToken =
      _class.instanceMethodId(r'clearSessionToken', r'()V');
  static final jni.JInstanceMethodId _cleanupViews =
      _class.instanceMethodId(r'cleanupViews', r'()V');
  static final jni.JInstanceMethodId _consumePendingEvents =
      _class.instanceMethodId(r'consumePendingEvents', r'()Ljava/lang/String;');

  factory DCFlightJni(jni.JObject context) {
    final object = _constructor.call(_class, jni.JObject.type, [context]);
    return DCFlightJni.fromReference(object.reference);
  }

  static void setEventCallback(DCFlightJniEventCallback callback) {
    _setEventCallback.call(_class, jni.jvoid.type, [callback]);
  }

  static void setScreenDimensionsCallback(
    DCFlightJniScreenDimensionsCallback callback,
  ) {
    _setScreenDimensionsCallback.call(_class, jni.jvoid.type, [callback]);
  }

  bool initialize() => _initialize.call(this, jni.jboolean.type, const []);

  bool createView(int viewId, jni.JString viewType, jni.JString propsJson) =>
      _createView.call(this, jni.jboolean.type, [viewId, viewType, propsJson]);

  bool updateView(int viewId, jni.JString propsJson) =>
      _updateView.call(this, jni.jboolean.type, [viewId, propsJson]);

  bool deleteView(int viewId) =>
      _deleteView.call(this, jni.jboolean.type, [viewId]);

  bool detachView(int viewId) =>
      _detachView.call(this, jni.jboolean.type, [viewId]);

  bool attachView(int childId, int parentId, int index) =>
      _attachView.call(this, jni.jboolean.type, [childId, parentId, index]);

  bool setChildren(int viewId, jni.JString childrenIdsJson) =>
      _setChildren.call(this, jni.jboolean.type, [viewId, childrenIdsJson]);

  bool addEventListeners(int viewId, jni.JString eventTypesJson) =>
      _addEventListeners.call(this, jni.jboolean.type, [viewId, eventTypesJson]);

  bool removeEventListeners(int viewId, jni.JString eventTypesJson) =>
      _removeEventListeners.call(this, jni.jboolean.type, [viewId, eventTypesJson]);

  bool startBatchUpdate() =>
      _startBatchUpdate.call(this, jni.jboolean.type, const []);

  bool commitBatchUpdate(jni.JString updatesJson) =>
      _commitBatchUpdate.call(this, jni.jboolean.type, [updatesJson]);

  bool cancelBatchUpdate() =>
      _cancelBatchUpdate.call(this, jni.jboolean.type, const []);

  jni.JString? tunnel(
    jni.JString componentType,
    jni.JString method,
    jni.JString paramsJson,
  ) => _tunnel.call(
        this,
        jni.JString.nullableType,
        [componentType, method, paramsJson],
      );

  jni.JString? getScreenDimensions() =>
      _getScreenDimensions.call(this, jni.JString.nullableType, const []);

  jni.JString? getSessionToken() =>
      _getSessionToken.call(this, jni.JString.nullableType, const []);

  jni.JString createSessionToken() =>
      _createSessionToken.call(this, jni.JString.type, const []);

  void clearSessionToken() =>
      _clearSessionToken.call(this, jni.jvoid.type, const []);

  void cleanupViews() => _cleanupViews.call(this, jni.jvoid.type, const []);

    jni.JString? consumePendingEvents() =>
            _consumePendingEvents.call(this, jni.JString.nullableType, const []);
}

class DCFlightJniEventCallback extends jni.JObject {
  DCFlightJniEventCallback.fromReference(super.reference) : super.fromReference();
}

class DCFlightJniScreenDimensionsCallback extends jni.JObject {
  DCFlightJniScreenDimensionsCallback.fromReference(super.reference)
      : super.fromReference();
}
