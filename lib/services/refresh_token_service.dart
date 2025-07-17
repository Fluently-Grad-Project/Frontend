// refresh_token_service.dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> refreshToken() async { // Changed to return bool for success
  final prefs = await SharedPreferences.getInstance();
  final String? oldRefreshToken = prefs.getString('refresh_token');

  Dio _dio = Dio();
  String url = "http://192.168.1.10:8000/auth/refresh-token?refresh_token="; // Corrected URL structure

  print("RefreshTokenService: Attempting to refresh token with URL: $url and token: $oldRefreshToken");

  try {
    final response = await _dio.post(
      "$url$oldRefreshToken",
    );

    if (response.statusCode == 200 && response.data != null) {
      final Map<String, dynamic> responseData = response.data as Map<String, dynamic>;

      final String? newAccessToken = responseData['access_token'] as String?;
      final String? newRefreshToken = responseData['refresh_token'] as String?;

      if (newAccessToken != null && newRefreshToken != null) {
        await prefs.setString('token', newAccessToken);
        await prefs.setString('refresh_token', newRefreshToken);
        print("RefreshTokenService: Tokens refreshed and saved successfully.");
        return true; // Indicate success
      } else {
        return false; // Indicate failure
      }
    } else {
      print("RefreshTokenService: Error refreshing token. Status: ${response.statusCode}, Data: ${response.data}");
      return false; // Indicate failure
    }
  } on DioException catch (e) {
    print("RefreshTokenService: DioException during token refresh: ${e.message}");
    if (e.response != null) {
      print("RefreshTokenService: DioException response data: ${e.response?.data}");
      print("RefreshTokenService: DioException response status: ${e.response?.statusCode}");
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        print("RefreshTokenService: Refresh token is invalid or expired (DioException). Clearing tokens.");
        await prefs.remove('token');
        await prefs.remove('refresh_token');
      }
    }
    return false; // Indicate failure
  } catch (e) {
    print("RefreshTokenService: Unexpected error during token refresh: $e");
    return false; // Indicate failure
  }
}