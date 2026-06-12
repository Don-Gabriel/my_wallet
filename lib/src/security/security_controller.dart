import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/formatters.dart';

class SecuritySettingsController extends ChangeNotifier {
  SecuritySettingsController._(this._prefs) {
    _loadFromPrefs();
  }

  static const _hideAmountsKey = 'security.hideAmounts';
  static const _privacyScreenKey = 'security.privacyScreenEnabled';
  static const _channel = MethodChannel('mywallet/security');

  final SharedPreferences _prefs;

  bool hideAmounts = false;
  bool privacyScreenEnabled = false;

  static Future<SecuritySettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SecuritySettingsController._(prefs);
    if (controller.privacyScreenEnabled) {
      await controller.applyPrivacyScreen();
    }
    return controller;
  }

  void _loadFromPrefs() {
    hideAmounts = _prefs.getBool(_hideAmountsKey) ?? false;
    privacyScreenEnabled = _prefs.getBool(_privacyScreenKey) ?? false;
    MoneyPrivacy.hideAmounts = hideAmounts;
  }

  Future<void> setHideAmounts(bool value) async {
    hideAmounts = value;
    MoneyPrivacy.hideAmounts = value;
    await _prefs.setBool(_hideAmountsKey, value);
    notifyListeners();
  }

  Future<void> setPrivacyScreenEnabled(bool value) async {
    privacyScreenEnabled = value;
    await _prefs.setBool(_privacyScreenKey, value);
    await applyPrivacyScreen();
    notifyListeners();
  }

  Future<void> resetLocalSettings() async {
    await _prefs.remove(_hideAmountsKey);
    await _prefs.remove(_privacyScreenKey);
    _loadFromPrefs();
    await applyPrivacyScreen();
    notifyListeners();
  }

  Future<void> applyPrivacyScreen() async {
    try {
      await _channel.invokeMethod<void>('setPrivacyScreen', {
        'enabled': privacyScreenEnabled,
      });
    } on MissingPluginException {
      // Non-Android platforms can ignore the secure-window flag.
    }
  }
}
