import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_call_page.dart';
import 'home_page.dart';
import 'chatbot_test.dart';

const String geminiApiKey = 'AIzaSyB3aZtJbUB6u_qinP7FqInZRVKQI16QmhE';

class AIChatPage extends StatefulWidget {
  const AIChatPage({Key? key}) : super(key: key);

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final List<String> _userMessages = [];
  bool _isLoadingFeedback = false;
  int _selectedIndex = 3;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _userMessages.add(text);

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScrollToBottom());

    final aiReply = await _fetchAIResponse(text);

    setState(() {
      _messages.add({'sender': 'ai', 'text': aiReply});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScrollToBottom());
  }

  Future<String> _fetchAIResponse(String userMessage) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final content = [Content.text(userMessage)];
      final response = await model.generateContent(content);

      return response.text ?? "No response from Gemini.";
    } catch (e) {
      print("Gemini error: $e");
      return "Failed to get response from Gemini.";
    }
  }

  Future<void> _getGrammarFeedback() async {
    if (_userMessages.isEmpty) return;

    setState(() {
      _isLoadingFeedback = true;
      _messages.add({'sender': 'ai', 'text': '🕐 Generating feedback...'});
    });

    final userText = _userMessages.join(" ");
    final prompt = '''
Check the following conversation for grammar and spelling mistakes.
Provide friendly feedback and corrections:\n$userText
''';

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final feedback = response.text ?? "No feedback generated.";

      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add({'sender': 'ai', 'text': "📝 Feedback:\n$feedback"});
        _isLoadingFeedback = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScrollToBottom());
    } catch (e) {
      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add({'sender': 'ai', 'text': "❗ Failed to get grammar feedback."});
        _isLoadingFeedback = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeScrollToBottom());
      print("Gemini feedback error: $e");
    }
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['sender'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFD3D3D3) : const Color(0xFF9F86C0),
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
            color: isUser ? Colors.black : Colors.white,
            fontSize: isUser ? 16 : 14,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _maybeScrollToBottom() {
    if (_scrollController.hasClients) {
      final threshold = 100.0;
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

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

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
      // Already on AI page, do nothing
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/account');
    }

    print("HomePage: Navigating to index $index");

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
          IconButton(
            icon: const Icon(Icons.spellcheck, color: Colors.black),
            onPressed: _getGrammarFeedback,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AudioChatScreen()),
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
