import 'package:flutter/material.dart';
import 'home_page.dart';
import 'ai_chat_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AIChatPage()), // Make sure AiChatPage is a valid widget
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }


  final List<Map<String, dynamic>> leaders = [
    {'name': 'User1'},
    {'name': 'User2'},
    {'name': 'User3'},
    {'name': 'User4'},
    {'name': 'User5'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Color(0xFF9F86C0),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Color(0xFF9F86C0),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: leaders.length,
              itemBuilder: (context, index) {
                final leader = leaders[index];
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
                      // Rank icon or number
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

                      // User icon
                      Image.asset('assets/user-figma-icon.png', width: 47, height: 47),
                      const SizedBox(width: 11.0),

                      // Username
                      Expanded(
                        child: Text(
                          leader['name'],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.android), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF9F86C0),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
