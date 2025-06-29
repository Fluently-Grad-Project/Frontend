import 'package:flutter/material.dart';

class OnboardingData {
  int? id;
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
  String? profileImage;

  Object get name => firstName! + ' ' + lastName!;

  Map<String, dynamic> toJson() => {
    'id': id,
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
    'profile_image': profileImage,
  };
}

class OnboardingProvider with ChangeNotifier {
  final OnboardingData _data = OnboardingData();

  OnboardingData get data => _data;

  void clearAll() {
    _data.id = null;
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
    _data.profileImage = null;
    notifyListeners();
  }
}
