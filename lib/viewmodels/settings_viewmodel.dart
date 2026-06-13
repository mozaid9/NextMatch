import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colours.dart';

/// Holds the user's appearance + accessibility preferences, persists them
/// locally with [SharedPreferences], and applies the colour-affecting ones to
/// [AppColours] so the whole app retints on change.
class SettingsViewModel extends ChangeNotifier {
  static const _kAccent = 'settings.accentColour';
  static const _kTextScale = 'settings.textScale';
  static const _kHighContrast = 'settings.highContrast';
  static const _kReduceMotion = 'settings.reduceMotion';

  /// Allowed text-scale range, surfaced by the Settings slider.
  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.4;

  SharedPreferences? _prefs;

  Color _accent = AppColours.defaultAccent;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;

  Color get accent => _accent;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;

  /// Load persisted settings and apply them to [AppColours]. Call once in
  /// `main()` before `runApp` so the saved accent is live on the first frame.
  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    final accentValue = prefs.getInt(_kAccent);
    if (accentValue != null) _accent = Color(accentValue);
    _textScale = prefs.getDouble(_kTextScale) ?? 1.0;
    _highContrast = prefs.getBool(_kHighContrast) ?? false;
    _reduceMotion = prefs.getBool(_kReduceMotion) ?? false;
    _applyColours();
    notifyListeners();
  }

  void _applyColours() {
    AppColours.configure(accent: _accent, highContrast: _highContrast);
  }

  Future<void> setAccent(Color colour) async {
    if (colour == _accent) return;
    _accent = colour;
    _applyColours();
    notifyListeners();
    await _prefs?.setInt(_kAccent, colour.toARGB32());
  }

  Future<void> setTextScale(double scale) async {
    final clamped = scale.clamp(minTextScale, maxTextScale);
    if (clamped == _textScale) return;
    _textScale = clamped;
    notifyListeners();
    await _prefs?.setDouble(_kTextScale, clamped);
  }

  Future<void> setHighContrast(bool value) async {
    if (value == _highContrast) return;
    _highContrast = value;
    _applyColours();
    notifyListeners();
    await _prefs?.setBool(_kHighContrast, value);
  }

  Future<void> setReduceMotion(bool value) async {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    notifyListeners();
    await _prefs?.setBool(_kReduceMotion, value);
  }
}
