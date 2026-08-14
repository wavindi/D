import 'dart:convert';
import 'dart:async';

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

class DApi {
  DApi._();
  static final instance = DApi._();

  static const baseUrl = 'https://test.wajdi.site';
  static const _tokenKey = 'd_auth_token';
  static const _userKey = 'd_auth_user';
  static const _requestTimeout = Duration(seconds: 15);

  String? token;
  AuthUser? user;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
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
      } else {
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
      throw StateError(data['detail']?.toString() ?? 'Authentication failed');
    }
    token = data['token'] as String;
    user = AuthUser.fromMap(Map<String, dynamic>.from(data['user'] as Map));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(
      _userKey,
      jsonEncode({'id': user!.id, 'email': user!.email, 'name': user!.name}),
    );
    return user!;
  }

  Future<void> logout() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<List<RunRecord>> fetchTrips() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/trips'), headers: _headers())
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw StateError(data['detail']?.toString() ?? 'Could not load trips');
    }
    final trips = (data['trips'] as List<dynamic>? ?? const []);
    return trips
        .map((item) => RunRecord.fromMap(_tripToRecord(item as Map)))
        .toList(growable: false);
  }

  Future<RunRecord> saveTrip(RunRecord run) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/trips'),
          headers: _headers(),
          body: jsonEncode({
            'started_at': run.startedAt.toIso8601String(),
            'duration_seconds': run.durationSeconds,
            'distance_meters': run.distanceMeters,
            'top_speed_kmh': run.topSpeedKmh,
            'average_speed_kmh': run.averageSpeedKmh,
            'destination_name': run.destinationName,
            'stopped_seconds': run.stoppedSeconds,
            'samples': run.samples.map((s) => s.toMap()).toList(),
          }),
        )
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw StateError(data['detail']?.toString() ?? 'Could not save trip');
    }
    return RunRecord(
      id: data['id'] as int?,
      startedAt: run.startedAt,
      durationSeconds: run.durationSeconds,
      distanceMeters: run.distanceMeters,
      topSpeedKmh: run.topSpeedKmh,
      averageSpeedKmh: run.averageSpeedKmh,
      destinationName: run.destinationName,
      stoppedSeconds: run.stoppedSeconds,
      samples: run.samples,
    );
  }

  Future<void> deleteTrip(int id) async {
    final res = await http
        .delete(Uri.parse('$baseUrl/api/trips/$id'), headers: _headers())
        .timeout(_requestTimeout);
    final data = _decode(res);
    if (res.statusCode >= 400) {
      throw StateError(data['detail']?.toString() ?? 'Could not delete trip');
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
    'started_at': item['started_at'],
    'duration_seconds': item['duration_seconds'],
    'distance_meters': item['distance_meters'],
    'top_speed_kmh': item['top_speed_kmh'],
    'average_speed_kmh': item['average_speed_kmh'],
    'destination_name': item['destination_name'],
    'stopped_seconds': item['stopped_seconds'],
    'samples': item['samples'],
  };
}
