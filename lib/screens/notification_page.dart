import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // ⬅ Add this
import 'home_page.dart';
import 'ai_chat_page.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}
class FriendRequest {
  final int id;
  final int senderId;
  final String sentAt;
  final String status;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.sentAt,
    required this.status,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      senderId: json['sender_id'],
      sentAt: json['sent_at'],
      status: json['status'],
    );
  }
}

class _NotificationPageState extends State<NotificationPage> {
  int _selectedIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<FriendRequest> _friendRequests = [];
  bool _isLoadingRequests = true;
  final Map<int, String> _usernamesCache = {}; // user_id -> username



  final Map<String, String> _requestStatuses = {}; // 'accepted', 'rejected', or null

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
  void initState() {
    super.initState();
    _fetchFriendRequests();
  }


  Future<void> _fetchFriendRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio();

    try {
      final response = await dio.get(
        'http://192.168.1.10:8000/friends/get-friend-requests',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final List data = response.data;
        setState(() {
          _friendRequests = data
              .map((json) => FriendRequest.fromJson(json))
              .where((f) => f.status == "PENDING")
              .toList();
          _isLoadingRequests = false;
        });
      } else {
        throw Exception('Failed to load friend requests');
      }
    } catch (e) {
      print("Error fetching friend requests: $e");
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }



  Future<void> _playAcceptSound() async {
    await _audioPlayer.play(AssetSource('accept-sound.mp3'));
  }

  Future<void> _handleFriendAction(int senderId, bool isAccept) async {
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio();

    final url = isAccept
        ? 'http://192.168.1.10:8000/friends/accept/$senderId'
        : 'http://192.168.1.10:8000/friends/reject/$senderId';

    try {
      final response = await dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${prefs.getString("token")}',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('${isAccept ? "Accepted" : "Rejected"} friend request from $senderId');
      } else {
        throw Exception("Failed to ${isAccept ? "accept" : "reject"} request");
      }
    } catch (e) {
      print("Error in friend action: $e");
    }
  }

  Future<String> _getUsernameFromUserId(int userId) async {
    if (_usernamesCache.containsKey(userId)) {
      return _usernamesCache[userId]!;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final username = query.docs.first.data()['username'] as String;
        _usernamesCache[userId] = username;
        return username;
      }
    } catch (e) {
      print('❌ Error fetching username for user_id $userId: $e');
    }

    return 'User #$userId';
  }


  Widget _buildFriendRequest(String username, FriendRequest request) {
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
                color: Colors.black,
              ),
            ),
          ),
          if (status == null) ...[
            TextButton(
              onPressed: () async {
                await _playAcceptSound();
                await _handleFriendAction(request.senderId, true);
                setState(() {
                  _requestStatuses[username] = 'accepted';
                  _friendRequests.removeWhere((r) => r.id == request.id);
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
              onPressed: () async {
                await _handleFriendAction(request.senderId, false);
                setState(() {
                  _requestStatuses[username] = 'rejected';
                  _friendRequests.removeWhere((r) => r.id == request.id);
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
              Container(height: 35, color: Colors.white),
              Container(
                height: 45,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _isLoadingRequests
                  ? const CircularProgressIndicator()
                  : Column(
                children: _friendRequests.map((req) {
                  return FutureBuilder<String>(
                    future: _getUsernameFromUserId(req.senderId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final username = snapshot.data ?? 'User #${req.senderId}';
                      return _buildFriendRequest(username, req);
                    },
                  );
                }).toList(),
              ),
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

// flutter clean
// flutter pub get
// flutter run
// #9F86C06E
// #9F86C0
// #9F86C0
// #EDECEE6E