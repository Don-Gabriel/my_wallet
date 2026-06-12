import 'package:flutter/material.dart';

import 'security_controller.dart';

class SecurityScope extends InheritedNotifier<SecuritySettingsController> {
  const SecurityScope({
    super.key,
    required SecuritySettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SecuritySettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SecurityScope>();
    assert(scope != null, 'SecurityScope not found');
    return scope!.notifier!;
  }
}
