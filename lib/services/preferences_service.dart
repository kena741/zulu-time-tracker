import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences. Periodic screenshots and aggregated keyboard/pointer metrics are always on (see Privacy).
class PreferencesService extends GetxService {
  static Future<PreferencesService> init() async {
    final p = await SharedPreferences.getInstance();
    final s = PreferencesService._(p);
    return s;
  }

  PreferencesService._(this._p);

  final SharedPreferences _p;

  bool get privacyConsentAccepted =>
      _p.getBool(_kPrivacyConsent) ?? false;

  Future<void> setPrivacyConsentAccepted(bool v) =>
      _p.setBool(_kPrivacyConsent, v);

  /// Core product behavior — not user-toggleable.
  bool get screenshotsEnabled => true;

  /// Default capture cadence (no Settings UI; fixed product default).
  int get screenshotIntervalMinutes =>
      _p.getInt(_kScreenshotInterval) ?? 10;

  Future<void> setScreenshotIntervalMinutes(int m) =>
      _p.setInt(_kScreenshotInterval, m.clamp(1, 120));

  /// Core product behavior — aggregated counts only, not key contents.
  bool get keyboardMetricsEnabled => true;

  /// Short memo for the active session (Work Diary header).
  String get sessionMemo => _p.getString(_kSessionMemo) ?? '';

  Future<void> setSessionMemo(String value) =>
      _p.setString(_kSessionMemo, value);

  static const _kPrivacyConsent = 'privacy_consent_v1';
  static const _kScreenshotInterval = 'screenshot_interval_minutes';
  static const _kSessionMemo = 'session_memo_v1';
  static const _kTrackingHeartbeatMs = 'tracking_heartbeat_wall_ms_v2';
  static const _kTrackingHeartbeatSid = 'tracking_heartbeat_session_uuid_v2';

  /// Last wall-clock sample while a session was running (crash / hard shutdown recovery).
  int? get trackingHeartbeatWallMs => _p.getInt(_kTrackingHeartbeatMs);

  String? get trackingHeartbeatSessionId => _p.getString(_kTrackingHeartbeatSid);

  Future<void> setTrackingHeartbeat({
    required String sessionId,
    required int wallMs,
  }) async {
    await _p.setString(_kTrackingHeartbeatSid, sessionId);
    await _p.setInt(_kTrackingHeartbeatMs, wallMs);
  }

  Future<void> clearTrackingHeartbeat() async {
    await _p.remove(_kTrackingHeartbeatSid);
    await _p.remove(_kTrackingHeartbeatMs);
  }
}
