import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoyo_ir1_tracker/domain/remote_protocol.dart';

class RemotePreferences {
  static const _kEnabled = 'remote_enabled';
  static const _kRole = 'remote_role';
  static const _kAutoConnect = 'remote_auto_connect';
  static const _kLastPeerName = 'remote_last_peer_name';
  static const _kVerifiedOnce = 'remote_verified_once';

  Future<
    ({
      bool enabled,
      RemoteRole role,
      bool autoConnect,
      String? lastPeerName,
      bool verifiedOnce,
    })
  >
  load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? false;
    final roleName = prefs.getString(_kRole);
    final role = RemoteRole.values.asNameMap()[roleName] ?? RemoteRole.tablet;
    final autoConnect = prefs.getBool(_kAutoConnect) ?? true;
    final lastPeerName = prefs.getString(_kLastPeerName);
    final verifiedOnce = prefs.getBool(_kVerifiedOnce) ?? false;
    return (
      enabled: enabled,
      role: role,
      autoConnect: autoConnect,
      lastPeerName: lastPeerName,
      verifiedOnce: verifiedOnce,
    );
  }

  Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
  }

  Future<void> saveRole(RemoteRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRole, role.name);
  }

  Future<void> saveAutoConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoConnect, value);
  }

  Future<void> saveLastPeerName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_kLastPeerName);
    } else {
      await prefs.setString(_kLastPeerName, name);
    }
  }

  Future<void> saveVerifiedOnce(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVerifiedOnce, value);
  }
}
