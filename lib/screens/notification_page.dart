import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // ⬅ Add this
import 'home_page.dart';
import 'ai_chat_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _selectedIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Map<String, String> _requestStatuses = {}; // 'accepted', 'rejected', or null

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AIChatPage()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _playAcceptSound() async {
    await _audioPlayer.play(AssetSource('accept-sound.mp3'));
  }

  Widget _buildFriendRequest(String username) {
    String? status = _requestStatuses[username];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/user-figma-icon.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black, // Changed from white to black
              ),
            ),
          ),
          if (status == null) ...[
            TextButton(
              onPressed: () async {
                await _playAcceptSound();
                setState(() {
                  _requestStatuses[username] = 'accepted';
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.green[100],
                foregroundColor: Colors.green[800],
              ),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _requestStatuses[username] = 'rejected';
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red[100],
                foregroundColor: Colors.red[800],
              ),
              child: const Text('Reject'),
            ),
          ] else ...[
            Text(
              status == 'accepted' ? 'Accepted' : 'Rejected',
              style: TextStyle(
                color: status == 'accepted' ? Colors.green[600] : Colors.red[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
              Container(height: 50, color: Colors.white),
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
                child: const Center(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildFriendRequest('Alice Johnson'),
              _buildFriendRequest('Bob Smith'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.android), label: 'AI'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF9F86C0),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// flutter clean
// flutter pub get
// flutter run
// #9F86C06E
// #9F86C0
// #9F86C0
// #EDECEE6E