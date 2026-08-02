import '../../../core/network/authenticated_api_client.dart';
import 'doctor_profile.dart';
import 'doctor_profile_update.dart';
import 'specialty.dart';

class DoctorProfileApi {
  final AuthenticatedApiClient _apiClient;

  DoctorProfileApi(this._apiClient);

  Future<DoctorProfile> getProfile() async {
    final response = await _apiClient.get('/doctors/me/');

    return DoctorProfile.fromJson(response);
  }

  Future<List<Specialty>> getSpecialties() async {
    final response = await _apiClient.get('/doctors/specialties/');
    final specialtiesJson = response['specialties'] as List? ?? const [];

    return specialtiesJson
        .whereType<Map>()
        .map(
          (specialty) =>
              Specialty.fromJson(Map<String, dynamic>.from(specialty)),
        )
        .toList();
  }

  Future<DoctorProfile> updateProfile(DoctorProfileUpdate update) async {
    final response = await _apiClient.patch(
      '/doctors/me/',
      body: update.toJson(),
    );

    return DoctorProfile.fromJson(response);
  }
}
