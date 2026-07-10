import '../../../core/network/api_client.dart';

class AuthApi {
  final ApiClient _apiClient;

  AuthApi(this._apiClient);

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) {
    return _apiClient.post(
      '/auth/login/',
      body: {'username': username, 'password': password},
    );
  }

  Future<Map<String, dynamic>> googleLogin({required String idToken}) {
    return _apiClient.post('/auth/google/', body: {'id_token': idToken});
  }

  Future<Map<String, dynamic>> refresh({required String refreshToken}) {
    return _apiClient.post('/auth/refresh/', body: {'refresh': refreshToken});
  }

  Future<Map<String, dynamic>> me({required String token}) {
    return _apiClient.get('/auth/me/', token: token);
  }
}
