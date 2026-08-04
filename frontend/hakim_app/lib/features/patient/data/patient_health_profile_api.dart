import '../../../core/network/authenticated_api_client.dart';
import 'patient_health_profile.dart';
import 'patient_health_profile_update.dart';

class PatientHealthProfileApi {
  static const String _profilePath = '/patients/health-profile/';

  final AuthenticatedApiClient _apiClient;

  PatientHealthProfileApi(this._apiClient);

  Future<PatientHealthProfile> getProfile() async {
    final response = await _apiClient.get(_profilePath);

    return PatientHealthProfile.fromJson(response);
  }

  Future<PatientHealthProfile> updateProfile(
    PatientHealthProfileUpdate update,
  ) async {
    final response = await _apiClient.patch(
      _profilePath,
      body: update.toJson(),
    );

    return PatientHealthProfile.fromJson(response);
  }

  Future<PatientHealthProfile> markReviewed() async {
    final response = await _apiClient.patch(
      _profilePath,
      body: const <String, dynamic>{},
    );

    return PatientHealthProfile.fromJson(response);
  }
}
