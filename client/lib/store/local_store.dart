import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _kUserId = 'userId';
  static const _kDisplayName = 'displayName';

  Future<void> saveUser(String userId, String displayName) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUserId, userId);
    await sp.setString(_kDisplayName, displayName);
  }

  Future<(String?, String?)> loadUser() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getString(_kUserId), sp.getString(_kDisplayName));
  }
}
