/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import 'package:dcflight/framework/components/hooks/state_hook.dart';

/// A hook that memoizes a value, re-creating it only when dependencies change.
class MemoHook<T> extends Hook {
  final T Function() create;
  List<dynamic> dependencies;
  T? _value;

  MemoHook(this.create, this.dependencies);

  T get value {
    _value ??= create();
    return _value!;
  }

  void updateDependencies(List<dynamic> newDependencies) {
    if (!_hasDependenciesChanged(dependencies, newDependencies)) {
      return;
    }
    dependencies = newDependencies;
    _value = create();
  }

  bool _hasDependenciesChanged(List<dynamic> oldDeps, List<dynamic> newDeps) {
    if (oldDeps.length != newDeps.length) return true;
    for (var i = 0; i < oldDeps.length; i++) {
      if (oldDeps[i] != newDeps[i]) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _value = null;
  }
}
