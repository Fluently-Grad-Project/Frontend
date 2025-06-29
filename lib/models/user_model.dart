// In your user_model.dart

// (Keep your _calculateAge helper function if you use birth_date)
int? _calculateAge(String? birthDateString) {
  if (birthDateString == null) return null;
  try {
    final dob = DateTime.parse(birthDateString);
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age < 0 ? null : age;
  } catch (e) {
    print("Error parsing birth_date ('$birthDateString') for age: $e");
    return null;
  }
}

class User {
   int id;
  final String? username;
  final String? email;
   String? firstName;
   String? lastName;
   String? gender;
   int? age;     // This should ideally be calculated from birth_date if server provides that
  List<String>? interests;
  // Fields that were in your original User class but not directly in the factory you showed
  // Ensure these are handled or removed if not needed by your app logic that uses the User object
   String? profile_image; // This was in your constructor but set to ''
  final bool? is_active;
  final String? full_name; // You had a getter `name`, this field might be redundant
  final bool? is_verified;
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
    // From original constructor - map or remove
    this.profile_image, // This is distinct from 'image'
    this.is_active,
    this.full_name,
    this.is_verified,
    this.rating = 0.0, // Default rating to 0.0

  });

  factory User.fromJson(Map<String, dynamic> json) {
    print("User.fromJson: Received JSON for user ID ${json['user_id'] ?? json['id']}: $json");

    List<String>? serverInterests;
    // 1. Attempt to parse "interests" directly from the server JSON
    if (json['interests'] != null && json['interests'] is List) {
      serverInterests = (json['interests'] as List)
          .map((interest) => interest?.toString()) // Convert each item to string
          .where((interest) => interest != null && interest.isNotEmpty) // Filter out nulls/empty strings
          .map((interest) => interest!.trim()) // Trim valid strings
          .toSet() // Remove duplicates from server list
          .toList(); // Convert back to list

      if (serverInterests.isEmpty) {
        // If server sends an empty list [], it means "no interests" explicitly.
        // If you prefer to represent this as null, change to: serverInterests = null;
        // Current: empty list means user has explicitly zero interests.
      }
      print("User.fromJson: Parsed server 'interests' for ID ${json['user_id'] ?? json['id']}: $serverInterests");
    } else {
      serverInterests = null; // No "interests" key or it's not a list, so no interests from server.
      print("User.fromJson: Server 'interests' field is null, not a List, or not found for ID ${json['user_id'] ?? json['id']}. Value: ${json['interests']}");
    }

    String? actualFirstName = json['firstName'] as String? ?? json['first_name'] as String?;
    String? actualLastName = json['lastName'] as String? ?? json['last_name'] as String?;
    String calculatedFullName = "${actualFirstName ?? ''} ${actualLastName ?? ''}".trim();
    if (calculatedFullName.isEmpty && json['username'] is String && (json['username'] as String).isNotEmpty) {
      calculatedFullName = json['username'] as String;
    }

    // Determine age: use 'age' from DummyJSON directly if available, otherwise calculate from 'birth_date'
    int? finalAge = json['age'] as int?; // For DummyJSON direct 'age' field
    if (finalAge == null && (json['birth_date'] is String || json['birthDate'] is String) ) {
      finalAge = _calculateAge(json['birth_date'] as String? ?? json['birthDate'] as String?);
    }

    return User(
      // Prefer 'user_id' from matchmaking, fallback to 'id' from profile
      id: json['user_id'] as int? ?? json['id'] as int? ?? 0,
      username: json['username'] as String?,
      email: json['email'] as String?,
      firstName: actualFirstName,
      lastName: actualLastName,
      full_name: calculatedFullName.isNotEmpty ? calculatedFullName : null,
      gender: json['gender'] as String?,
      profile_image: json['profile_image'] as String?, // From your actual API
      age: finalAge,
      interests: serverInterests, // Directly use the parsed server interests
      is_active: json['is_active'] as bool? ?? false, // Default if not present
      is_verified: json['is_verified'] as bool? ?? false, // Default if not present

    );
  }

  // Getter for name (convenience, using your original logic)
  String get name => (full_name != null && full_name!.isNotEmpty)
      ? full_name!
      : (username != null && username!.isNotEmpty ? username! : firstName! + ' ' + lastName!);

// Getter for rating (if you use it like this)
// double get rating => averageRating ?? 0.0; // Example
}