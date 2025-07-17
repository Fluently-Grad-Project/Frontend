import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/Ip_provider.dart';
import 'home_page.dart';
import 'ai_chat_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> leaders = [];
  bool isLoading = true;

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

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchLeaderboard();
  }

  Future<void> fetchLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('http://${IpAddress}:8000/leaderboard/all'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          leaders = data.map((item) => {
            'name': '${item['first_name']} ${item['last_name']}',
            'profile_image': item['profile_image'],
            'streaks': item['streaks'],
            'minutes': item['minutes'],
            'score': item['score'],
          }).toList();
          isLoading = false;
        });
      } else {
        print('Failed to load leaderboard: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: leaders.length,
              itemBuilder: (context, index) {
                final leader = leaders[index];
                final int totalMinutes = leader['minutes'] ?? 0;
                final int hours = totalMinutes ~/ 60;
                final int minutes = totalMinutes % 60;
                final String timeString = '${hours}h ${minutes}m';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color(0x6E9F86C0),
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        offset: const Offset(0, 4),
                        blurRadius: 8.0,
                        spreadRadius: 1.0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Center(
                          child: index == 0
                              ? Image.asset('assets/first-place-icon.png', width: 47, height: 47)
                              : index == 1
                              ? Image.asset('assets/second-place-icon.png', width: 47, height: 47)
                              : index == 2
                              ? Image.asset('assets/third-place-icon.png', width: 47, height: 47)
                              : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: (leader['profile_image'] != null && leader['profile_image'].toString().trim().isNotEmpty)
                            ? Image.network(
                          leader['profile_image'],
                          width: 47,
                          height: 47,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset('assets/user-figma-icon.png', width: 47, height: 47);
                          },
                        )
                            : Image.asset('assets/user-figma-icon.png', width: 47, height: 47),
                      ),
                      const SizedBox(width: 11.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leader['name'],
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              timeString,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${leader['streaks']} streaks | ${leader['score']} pts',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'AI'),
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
