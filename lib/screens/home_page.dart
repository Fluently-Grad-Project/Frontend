import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'Profile/profile_page.dart';
import 'ai_chat_page.dart';
import 'friends/friend_profile.dart';
import 'friends/friends_page.dart';
import 'leaderboard_page.dart';
import 'matchmaking/user_chat_request_page.dart';
import 'notification_page.dart';
import '../models/word_of_the_day.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> languages = ['English'];
  String selectedLanguage = 'English';

  int _selectedIndex = 0;
  final FlutterTts flutterTts = FlutterTts();

  bool isLeaderboardPressed = false;
  bool isMatchPressed = false;

  WordOfTheDay? wordOfTheDay;
  bool isLoadingWord = true;

  int currentStreak = 0;
  String totalTime = '0h 0m';


  bool isLoadingStreak = true;
  bool isLoadingTime = true;


  @override
  void initState() {
    super.initState();
    fetchWordOfTheDay();
    fetchStreak();
    fetchPracticeHours();
  }

  Future<void> fetchWordOfTheDay() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.53:8001/word-of-the-day/today'),
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          wordOfTheDay = WordOfTheDay.fromJson(data);
          isLoadingWord = false;
        });
      } else {
        setState(() {
          isLoadingWord = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingWord = false;
      });
      print('Error: $e');
    }
  }

  Future<void> fetchStreak() async {
    final url = Uri.parse('http://192.168.1.53:8000/activity/get_streaks');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          currentStreak = data['streak'] ?? 0;
          isLoadingStreak = false; // ✅ mark loading as false
        });
      } else {
        setState(() {
          isLoadingStreak = false; // ✅ even on failure
        });
        print('❌ Failed to fetch streaks: ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoadingStreak = false; // ✅ even on error
      });
      print('❌ Error fetching streak: $e');
    }
  }

  Future<void> fetchPracticeHours() async {
    final url = Uri.parse('http://192.168.1.53:8000/activity/get_practice_hours');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final totalSeconds = data['total_time'] ?? 0;

        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;

        final formattedTime = '${hours}h ${minutes}m';

        setState(() {
          totalTime = '${hours}h ${minutes}m';
          isLoadingTime = false;
        });
      } else {
        setState(() {
          totalTime = '0h 0m'; // fallback for failure
          isLoadingTime = false;
        });
        print('❌ Failed to fetch practice hours: ${response.body}');
      }
    } catch (e) {
      setState(() {
        totalTime = '0h 0m'; // fallback for error
        isLoadingTime = false;
      });
      print('❌ Error fetching practice hours: $e');
    }
  }


  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/friends');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/chat');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/ai');
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/account');
    }

    print("HomePage: Navigating to index $index");

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            children: [
              Container(height: 8, color: Colors.white),
              Container(
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF9F86C0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLanguage,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'English',
                            child: Image.asset(
                              'assets/uk-flag-icon.png',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NotificationPage()),
                        );
                      },
                      child: Image.asset(
                        'assets/bell-icon.png',
                        width: 35,
                        height: 35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF9F86C0),
                  image: const DecorationImage(
                    image: AssetImage('assets/waves-lines.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isLoadingWord
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : wordOfTheDay == null
                    ? const Text('Failed to load word of the day.', style: TextStyle(color: Colors.white))
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Word of the Day',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          wordOfTheDay!.word,
                          style: const TextStyle(fontSize: 26, color: Colors.white),
                        ),
                        GestureDetector(
                          onTap: () => _speak(wordOfTheDay!.word),
                          child: Image.asset(
                            'assets/speaker-filled-audio-tool 2.png',
                            width: 30,
                            height: 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wordOfTheDay!.partsOfSpeech,
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white54, thickness: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Definition: ${wordOfTheDay!.description}',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Example: ${wordOfTheDay!.example}',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/streak1-icon.webp',
                                  width: 30,
                                  height: 30,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isLoadingStreak ? 'Loading...' : '$currentStreak',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF9F86C0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Current Streak',
                              style: TextStyle(fontSize: 16, color: Color(0xFF9F86C0)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 95,
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/clock3-icon.png',
                                  width: 30,
                                  height: 30,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isLoadingTime ? 'Loading...' : totalTime,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF9F86C0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Total Time',
                              style: TextStyle(fontSize: 16, color: Color(0xFF9F86C0)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() => isLeaderboardPressed = true);
                    await Future.delayed(Duration(milliseconds: 150));
                    setState(() => isLeaderboardPressed = false);

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LeaderboardPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLeaderboardPressed ? Color(0xFF7B5FA3) : Color(0xFF9F86C0),
                    elevation: isLeaderboardPressed ? 2 : 6,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 8),
                      const Text(
                        'Leaders List',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() => isMatchPressed = true);
                    await Future.delayed(Duration(milliseconds: 150));
                    setState(() => isMatchPressed = false);

                    Navigator.pushNamed(context, '/chat');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMatchPressed ? Color(0xFF7B5FA3) : Color(0xFF9F86C0),
                    elevation: isMatchPressed ? 2 : 6,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Match & Practice',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'AI'), // Changed icon
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 159, 134, 192),
        unselectedItemColor: Colors.grey[600],
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 5,
      ),
    );
  }
}
