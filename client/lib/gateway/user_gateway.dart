import '../model/models.dart';
import 'api_client.dart';

class UserGateway {
  final ApiClient _api;

  UserGateway(this._api);

  Future<UserProfile> registerUser(String displayName) async {
    final map = await _api.postJson('/api/users', {'displayName': displayName});
    final value = map['user'] as Map<String, dynamic>;
    return UserProfile.fromJson(value);
  }

  Future<List<UserProfile>> getUsers() async {
    final map = await _api.getJson('/api/users');
    final list = (map['users'] as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<UserProfile> updateUser({
    required String userId,
    required String displayName,
    required int riichiVoiceId,
    required String? iconDataUrl,
    bool? isHidden,
  }) async {
    final map = await _api.putJson(
      '/api/users/$userId',
      {
        'displayName': displayName,
        'iconDataUrl': iconDataUrl,
        'riichiVoiceId': riichiVoiceId,
        'isHidden': isHidden,
      },
    );
    final value = map['user'] as Map<String, dynamic>;
    return UserProfile.fromJson(value);
  }
}
