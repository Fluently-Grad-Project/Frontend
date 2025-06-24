import 'package:flutter/material.dart';

class OnboardingData {
  String? firstName;
  String? lastName;
  String? gender;
  String? email;
  String? password;
  String? birthDate;
  String? selectedDay;
  String? selectedMonth;
  String? selectedYear;
  String? selectedLanguage;
  String? proficiencyLevel;
  String? practiceFrequency;
  List<String>? interests;

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'password': password,
    'gender': gender?.toUpperCase(),
    'birth_date': birthDate,
    'languages': [selectedLanguage],
    'proficiency_level': proficiencyLevel?.toUpperCase(),
    'practice_frequency': practiceFrequency,
    'interests': interests,
  };
}

class OnboardingProvider with ChangeNotifier {
  final OnboardingData _data = OnboardingData();

  OnboardingData get data => _data;

  void clearAll() {
    _data.firstName = null;
    _data.lastName = null;
    _data.gender = null;
    _data.email = null;
    _data.password = null;
    _data.birthDate = null;
    _data.selectedDay = null;
    _data.selectedMonth = null;
    _data.selectedYear = null;
    _data.selectedLanguage = null;
    _data.proficiencyLevel = null;
    _data.practiceFrequency = null;
    _data.interests = null;
    notifyListeners();
  }
}
