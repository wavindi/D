import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/run_record.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});
  final int id;
  final String email;
  final String name;

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
    id: map['id'] as int,
    email: map['email'] as String,
    name: map['name'] as String,
  );
}

abstract interface class TripApi {
  String? get token;
  AuthUser? get user;
  Future<List<RunRecord>> fetchTrips();
  Future<RunRecord> saveTrip(RunRecord run);
  Future<void> deleteTrip(int id);
}

class ApiException implements Exception {
  const ApiException(this.message, {required this.statusCode});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class DApi implements TripApi {
  DApi._();
  static final instance = DApi._();

  static const baseUrl = String.fromEnvironment(
    'D_API_BASE_URL',
    defaultValue: 'https://test.wajdi.site',
  );
  static const _tokenKey = 'd_auth_token';
  static const _userKey = 'd_auth_user';
  static const _requestTimeout = Duration(seconds: 15);
  static const _secureStorage = FlutterSecureStorage();

  @override
  String? token;
  @override
  AuthUser? user;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = await _secureStorage.read(key: _tokenKey);
    final legacyToken = prefs.getString(_tokenKey);
    if (token == null && legacyToken != null) {
      token = legacyToken;
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
    }
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      user = AuthUser.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    }
    if (token == null) return;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/me'), headers: _headers())
          .timeout(_requestTimeout);
      if (res.statusCode == 200) {
        user = AuthUser.fromMap(jsonDecode(res.body) as Map<String, dynamic>);
        await prefs.setString(
          _userKey,
          jsonEncode({
            'id': user!.id,
            'email': user!.email,
            'name': user!.name,
          }),
        );
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        await logout();
      }
    } catch (_) {
      // Keep cached session if offline.
    }
  }

  Future<AuthUser> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    return _auth('/api/signup', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    return _auth('/api/login', {'email': email, 'password': password});
  }

  Future<AuthUser> _auth(String path, Map<String, String> body) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw ApiException(
        data['detail']?.toString() ?? 'Authentication failed',
        statusCode: res.statusCode,
      );
    }
    token = data['token'] as String;
    user = AuthUser.fromMap(Map<String, dynamic>.from(data['user'] as Map));
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _tokenKey, value: token!);
    await prefs.setString(
      _userKey,
      jsonEncode({'id': user!.id, 'email': user!.email, 'name': user!.name}),
    );
    return user!;
  }

  Future<void> logout() async {
    if (token != null) {
      try {
        await http
            .post(Uri.parse('$baseUrl/api/logout'), headers: _headers())
            .timeout(_requestTimeout);
      } catch (_) {
        // Local logout must remain available while offline.
      }
    }
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _tokenKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  @override
  Future<List<RunRecord>> fetchTrips() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/trips'), headers: _headers())
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw ApiException(
        data['detail']?.toString() ?? 'Could not load trips',
        statusCode: res.statusCode,
      );
    }
    final trips = (data['trips'] as List<dynamic>? ?? const []);
    return trips
        .map((item) => RunRecord.fromMap(_tripToRecord(item as Map)))
        .toList(growable: false);
  }

  @override
  Future<RunRecord> saveTrip(RunRecord run) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/trips'),
          headers: _headers(),
          body: jsonEncode({
            'client_trip_id': run.clientTripId,
            'started_at': run.startedAt.toUtc().toIso8601String(),
            'duration_seconds': run.durationSeconds,
            'distance_meters': run.distanceMeters,
            'top_speed_kmh': run.topSpeedKmh,
            'average_speed_kmh': run.averageSpeedKmh,
            'destination_name': run.destinationName,
            'stopped_seconds': run.stoppedSeconds,
            'samples': run.samples.map((s) => s.toMap()).toList(),
            'activity_type': run.activityType,
            'track_id': run.trackId,
            'track_center_lat': run.trackCenterLat,
            'track_center_lng': run.trackCenterLng,
            'track_radius_meters': run.trackRadiusMeters,
          }),
        )
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw ApiException(
        data['detail']?.toString() ?? 'Could not save trip',
        statusCode: res.statusCode,
      );
    }
    return run.copyWith(id: data['id'] as int?, syncState: 'synced');
  }

  @override
  Future<void> deleteTrip(int id) async {
    final res = await http
        .delete(Uri.parse('$baseUrl/api/trips/$id'), headers: _headers())
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400 && res.statusCode != 404) {
      throw ApiException(
        data['detail']?.toString() ?? 'Could not delete trip',
        statusCode: res.statusCode,
      );
    }
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'detail': decoded.toString()};
  }

  Map<String, Object?> _tripToRecord(Map item) => {
    'id': item['id'],
    'client_trip_id': item['client_trip_id'],
    'started_at': item['started_at'],
    'duration_seconds': item['duration_seconds'],
    'distance_meters': item['distance_meters'],
    'top_speed_kmh': item['top_speed_kmh'],
    'average_speed_kmh': item['average_speed_kmh'],
    'destination_name': item['destination_name'],
    'stopped_seconds': item['stopped_seconds'],
    'samples': item['samples'],
    'sync_state': 'synced',
    'activity_type': item['activity_type'] ?? 'drive',
    'track_id': item['track_id'],
    'track_center_lat': item['track_center_lat'],
    'track_center_lng': item['track_center_lng'],
    'track_radius_meters': item['track_radius_meters'],
  };
}
