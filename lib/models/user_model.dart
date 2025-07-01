int? _calculateAge(String? birthDateString) {
  if (birthDateString == null) return null;
  try {
    final dob = DateTime.parse(birthDateString);
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  } catch (e) {
    return null;
  }
}

class User {
  int id;
  String? username;
  String? email;
  String? firstName;
  String? lastName;
  String? gender;
  int? age;
  List<String>? interests;
  String? profile_image;
  bool? is_active;
  String? full_name;
  bool? is_verified;
  double? rating;

  User({
    required this.id,
    this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.gender,
    this.age,
    this.interests,
    this.profile_image,
    this.is_active,
    this.full_name,
    this.is_verified,
    this.rating = 0.0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final actualFirst = json['first_name'] ?? json['firstName'];
    final actualLast = json['last_name'] ?? json['lastName'];

    int? finalAge = json['age'];
    if (finalAge == null) {
      finalAge = _calculateAge(json['birth_date'] ?? json['birthDate']);
    }

    List<String> cleanInterests = [];
    if (json['interests'] is List) {
      cleanInterests = (json['interests'] as List).map((e) => e.toString()).toList();
    }

    return User(
      id: json['user_id'] ?? json['id'] ?? 0,
      username: json['username'],
      email: json['email'],
      firstName: actualFirst,
      lastName: actualLast,
      full_name: json['full_name'],
      gender: json['gender'],
      profile_image: json['profile_image'],
      is_active: json['is_active'],
      is_verified: json['is_verified'],
      rating: json['rating']?.toDouble() ?? 0.0,
      interests: cleanInterests,
      age: finalAge,
    );
  }

  String get name {
    if (full_name != null && full_name!.isNotEmpty) return full_name!;
    if (username != null && username!.isNotEmpty) return username!;
    if (firstName != null || lastName != null) {
      return "${firstName ?? ''} ${lastName ?? ''}".trim();
    }
    return "Unknown User";
  }

  get proficiency => null;
}
