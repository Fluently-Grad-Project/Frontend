import 'package:flutter/material.dart';

import 'ai_call_page.dart';
import 'home_page.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({Key? key}) : super(key: key);

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  int _selectedIndex = 3; // Default to AI tab
  final ScrollController _scrollController = ScrollController();


  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeScrollToBottom();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _messages.add({
          'sender': 'ai',
          'text': _generateAIResponse(text),
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeScrollToBottom();
      });
    });
  }

  String _generateAIResponse(String userMessage) {
    return "You said: \"$userMessage\". I'm still learning!";
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['sender'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFD3D3D3) // User bubble: Light Gray
              : const Color(0xFF9F86C0), // AI bubble: Lavender/Purple
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Text(
          message['text'] ?? '',
          style: TextStyle(
            color: isUser ? Colors.black : Colors.white, // Change based on sender
            fontSize: isUser ? 16 : 14,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/friends');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/chat');
    } else if (index == 3) {
      // Already on AI Chat, no action needed
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/account');
    }

    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _maybeScrollToBottom() {
    // Only scroll if the user is near the bottom
    if (_scrollController.hasClients) {
      final threshold = 100.0; // Allowable distance from bottom
      final distanceFromBottom =
          _scrollController.position.maxScrollExtent - _scrollController.offset;

      if (distanceFromBottom < threshold) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // <-- This removes the back arrow
        title: const Text(
          'AI Chat',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
        backgroundColor: Colors.white,
        toolbarHeight: 60,
        centerTitle: false,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AICallPage()),
                );
              },
              child: Image.asset(
                'assets/tel-phone-icon.png',
                height: 25,
                width: 25,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/wall1-icon.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF9F86C0)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.android),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
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

