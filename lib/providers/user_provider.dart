import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/models/user_model.dart';

class UserProvider with ChangeNotifier {
  User? _current;
  User? get current => _current;

  Object get name => _current?.firstName ?? '' + ' ' + (_current!.lastName)! ?? ' ';
  Future<void> fetchById(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) return;

    final dio = Dio();
    dio.options.headers['Authorization'] = 'Bearer $token';
    dio.options.headers['Accept'] = 'application/json';

    final response = await dio.get("http://10.0.2.2:8000/users/$userId/profile");
    _current = User.fromJson(response.data);
    notifyListeners();
  }

  void clear() {
    _current = null;
    notifyListeners();
  }
}
