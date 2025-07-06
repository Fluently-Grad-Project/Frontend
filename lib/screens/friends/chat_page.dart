// At the top of chat_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:provider/provider.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For HTTP requests
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart'; // For WebSocket

// import 'package:web_socket_channel/io.dart'; // if you need IOWebSocketChannel for specific headers, though query params are usually fine

// Adjust path as needed
import '../../models/user_model.dart';

import '../../providers/user_provider.dart';
import '../../services/refresh_token_service.dart';
import 'friend_profile.dart';

// --- Placeholder for current user info ---
// In a real app, this would come from your auth service/state management

// --- Message Status Enum ---
// Aligns with your server's possible statuses, plus a client-side "sending"
enum MessageStatus {
  sending, // Client-side only: message is being sent via WebSocket
  sent,    // Server confirmed: message created by sender
  delivered, // Server confirmed: recipient received
  read,      // Server confirmed: recipient viewed
  failed,  // Client-side only: WebSocket send failed
  none,    // Default for received messages before server status is known (or if not applicable)
}

MessageStatus _parseMessageStatus(String? statusStr) {
  switch (statusStr?.toLowerCase()) {
    case 'sent':
      return MessageStatus.sent;
    case 'delivered':
      return MessageStatus.delivered;
    case 'read':
      return MessageStatus.read;
    default:
      return MessageStatus.none; // Or handle as an error/unknown
  }
}



class ChatMessage {
  final String id; // Client-generated ID for messages sent from this client, server ID for history
  final int? serverMessageId; // From chat history `id`
  final int senderId;
  final int receiverId;
  final String text;
  final DateTime timestamp;
  MessageStatus status; // Mutable
  final bool isSentByMe;

  ChatMessage({
    required this.id,
    this.serverMessageId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.status,
    required this.isSentByMe,
  });

  // Factory constructor for messages from chat history API
  factory ChatMessage.fromHistoryJson(Map<String, dynamic> json, int currentUserId) {
    int sId = json['sender_id'];
    return ChatMessage(
      id: json['id'].toString() + "_history", // Create a unique ID for list management
      serverMessageId: json['id'],
      senderId: sId,
      receiverId: json['receiver_id'],
      text: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      status: _parseMessageStatus(json['status']),
      isSentByMe: sId == currentUserId,
    );
  }

  // Factory constructor for messages received via WebSocket
  // Assuming format "SenderName: Message Text" and we know the sender from context or need to parse
  factory ChatMessage.fromWebSocketString(String wsString, int currentUserId, User otherUser) {
    String messageText = wsString;
    int senderId = otherUser.id; // Assume messages from WS are from the otherUser in 1-to-1
    String? senderNameFromWs;

    int colonIndex = wsString.indexOf(':');
    if (colonIndex != -1 && colonIndex + 1 < wsString.length) {
      senderNameFromWs = wsString.substring(0, colonIndex).trim();
      messageText = wsString.substring(colonIndex + 1).trim();
      // If your backend guarantees senderNameFromWs is always accurate and maps to otherUser.name, great.
      // Otherwise, you might need a more robust way to identify the sender if it's a group chat.
      // For 1-on-1, if the message isn't from currentAppUser, it's from widget.chatUser.
    }

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + "_ws", // Client-side unique ID
      senderId: senderId, // This is the ID of the person who sent the message via WS
      receiverId: currentUserId, // The current user is the receiver of this WS message
      text: messageText,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered, // Assume delivered if received via WS, server might send updates later
      isSentByMe: false, // Messages from WebSocket onMessage are from others
    );
  }
}













// Continuing in chat_page.dart

class ChatPage extends StatefulWidget {
  final User chatUser; // The user you are chatting with

  const ChatPage({
    Key? key,
    required this.chatUser,
    // No need to pass currentUserToken if it's globally accessible via AppCurrentUser
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {


  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  WebSocketChannel? _channel;
  bool _isLoadingHistory = false;
  bool _isConnectedToWebSocket = false;
  String? _connectionStatusMessage; // For general status like "Connecting..."

  // Client-side unique ID generator (simple timestamp based)
  String _generateClientMessageId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + "_client";
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _channel?.sink.close();
    super.dispose();
  }


  Future<void> _loadInitialData() async {
    await _fetchChatHistory(); // Wait for history to load
    // After history is fetched and messages are populated
    if (mounted && _messages.isNotEmpty) {
      // Mark messages from the current chatUser as read
      _markMessagesAsRead(widget.chatUser.id);
    }
  }

  Future<void> _fetchChatHistory() async {
    print("DEBUG: _fetchChatHistory called.");

    if (_isLoadingHistory) {
      print("DEBUG: _fetchChatHistory: Already loading history, returning.");
      return;
    }

    setState(() {
      _isLoadingHistory = true;
      // Optionally show a loading indicator for history
    });
    print("DEBUG: _fetchChatHistory: Set _isLoadingHistory to true.");

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      print("DEBUG: _fetchChatHistory: SharedPreferences instance obtained.");
    } catch (e) {
      print("DEBUG: _fetchChatHistory: ERROR obtaining SharedPreferences: $e");
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing storage: $e')),
        );
      }
      return;
    }

    final String? token = prefs.getString("token");
    print("DEBUG: _fetchChatHistory: Token from prefs: '$token'");

    if (token == null || token.isEmpty) {
      print("DEBUG: _fetchChatHistory: Token is null or empty. Cannot fetch history.");
      // Potentially handle this by trying to refresh token or redirecting to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication token not found. Please log in again.'), backgroundColor: Colors.red),
        );
        // Consider navigating to login: Navigator.pushReplacementNamed(context, '/login');
        setState(() {
          _isLoadingHistory = false;
        });
      }
      return;
    }

    UserProvider currentUserProvider;
    try {
      // Ensure context is valid before using Provider.of
      if (!mounted) {
        print("DEBUG: _fetchChatHistory: Context is not mounted before accessing UserProvider. Returning.");
        setState(() { _isLoadingHistory = false; });
        return;
      }
      currentUserProvider = Provider.of<UserProvider>(context, listen: false);
      print("DEBUG: _fetchChatHistory: UserProvider obtained.");
    } catch (e) {
      print("DEBUG: _fetchChatHistory: ERROR obtaining UserProvider: $e");
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing user data: $e')),
        );
      }
      return;
    }

    final User? currentUser = currentUserProvider.current;
    if (currentUser == null) {
      print("DEBUG: _fetchChatHistory: currentUser from UserProvider is NULL.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current user data not available. Please try again.'), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoadingHistory = false;
        });
      }
      return;
    }
    print("DEBUG: _fetchChatHistory: Current user ID: ${currentUser.id}");
    print("DEBUG: _fetchChatHistory: Target chat user ID (receiver_id): ${widget.chatUser.id}");


    try {
      final targetUrl = 'http://192.168.1.62:8000/chat/history?receiver_id=${widget.chatUser.id}';
      print("DEBUG: _fetchChatHistory: Sending API request to: $targetUrl");
      print("DEBUG: _fetchChatHistory: Authorization Header: 'Bearer $token'");

      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'Authorization': 'Bearer $token', // Re-check if prefs.getString("token") was indeed correct
        },
      );
      print("DEBUG: _fetchChatHistory: API response received. Status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        print("DEBUG: _fetchChatHistory: Response Body: ${response.body}");
        List<dynamic> historyJson;
        try {
          historyJson = jsonDecode(response.body);
          print("DEBUG: _fetchChatHistory: Successfully decoded JSON. Number of history items: ${historyJson.length}");
        } catch (e) {
          print("DEBUG: _fetchChatHistory: ERROR decoding JSON response: $e");
          print("DEBUG: _fetchChatHistory: Malformed JSON was: ${response.body}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Received malformed data from server.')),
            );
          }
          return; // Exit here as we can't process further
        }

        final List<ChatMessage> historyMessages = historyJson
            .map((jsonItem) {
          print("DEBUG: _fetchChatHistory: Mapping JSON item: $jsonItem");
          // Add a null check for jsonItem before passing to fromHistoryJson if it can be null
          if (jsonItem == null) {
            print("DEBUG: _fetchChatHistory: WARNING - JSON item in history list is null.");
            return null; // or handle appropriately
          }
          try {
            return ChatMessage.fromHistoryJson(jsonItem as Map<String, dynamic>, currentUser.id);
          } catch (e) {
            print("DEBUG: _fetchChatHistory: ERROR in ChatMessage.fromHistoryJson for item $jsonItem: $e");
            return null; // Skip problematic items
          }
        })
            .whereType<ChatMessage>() // This will filter out any nulls if you return null for bad items
            .toList();

        print("DEBUG: _fetchChatHistory: Successfully mapped ${historyMessages.length} messages.");

        if (mounted) {
          setState(() {
            _messages.addAll(historyMessages);
            _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
            print("DEBUG: _fetchChatHistory: Messages added to state and sorted. Total messages: ${_messages.length}");
          });
        }
      } else if (response.statusCode == 401) {
        print("DEBUG: _fetchChatHistory: Unauthorized (401). Current token: '$token'. Attempting refresh.");
        // Ensure refreshToken is awaited and its success is checked
        bool refreshed = await refreshToken(); // Assuming refreshToken returns bool
        if (refreshed) {
          print("DEBUG: _fetchChatHistory: Token refreshed successfully. Retrying _fetchChatHistory.");
          _fetchChatHistory(); // Recursive call, be mindful of potential infinite loops if refresh fails repeatedly
        } else {
          print("DEBUG: _fetchChatHistory: Token refresh failed. User may need to log in again.");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session expired. Please log in again.'), backgroundColor: Colors.red),
            );
            // Potentially navigate to login screen
          }
        }
      } else {
        print('DEBUG: _fetchChatHistory: Failed to load chat history. Status: ${response.statusCode}, Body: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load chat history: ${response.reasonPhrase} (Status: ${response.statusCode})')),
          );
        }
      }
    } catch (e, stackTrace) { // Added stackTrace for more detailed error
      print('DEBUG: _fetchChatHistory: CRITICAL ERROR fetching chat history: $e');
      print('DEBUG: _fetchChatHistory: StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading history: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        print("DEBUG: _fetchChatHistory: Set _isLoadingHistory to false in finally block.");
      } else {
        print("DEBUG: _fetchChatHistory: Not mounted in finally block, cannot set state.");
      }
    }
  }


  Future<void> _markMessagesAsRead(int senderId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      print("ChatPage: Cannot mark messages as read. User not authenticated.");
      // Optionally show a message to the user or attempt refresh token logic
      return;
    }

    // Check if there are any unread messages from this sender before making the call
    bool hasUnreadMessagesFromSender = _messages.any((msg) =>
    !msg.isSentByMe && // Message is received
        msg.senderId == senderId && // From the specific sender
        msg.status != MessageStatus.read && // Is not already read
        msg.status != MessageStatus.sending && // Not a client-side only status
        msg.status != MessageStatus.failed
    );

    if (!hasUnreadMessagesFromSender) {
      print("ChatPage: No unread messages from sender $senderId to mark as read.");
      return;
    }

    final String apiUrl = "http://192.168.1.62:8000/chat/mark-as-read/$senderId";
    print("ChatPage: Marking messages from sender $senderId as read. URL: $apiUrl");

    try {
      final dio = Dio(); // You might want to use a shared Dio instance
      final response = await dio.post(
        apiUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 204) { // 204 No Content is also a success
        print("ChatPage: Successfully marked messages from sender $senderId as read via API.");
        if (mounted) {
          setState(() {
            for (var message in _messages) {
              if (!message.isSentByMe && message.senderId == senderId && message.status != MessageStatus.read) {
                message.status = MessageStatus.read;
              }
            }
            // Optional: If you sort messages by status or have UI elements dependent on read counts,
            // you might need to re-sort or explicitly trigger UI updates here.
            // For now, updating individual message.status should be picked up by ListView.builder.
          });
        }
      } else if (response.statusCode == 401) {
        print("ChatPage: Unauthorized to mark messages as read. Attempting token refresh.");
        bool refreshed = await refreshToken(); // Assuming refreshToken() is accessible
        if (refreshed) {
          _markMessagesAsRead(senderId); // Retry after successful refresh
        } else {
          print("ChatPage: Token refresh failed. Could not mark messages as read.");
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session expired. Please try again.'),backgroundColor: Colors.orange,),
            );
          }
        }
      }
      else {
        print("ChatPage: Failed to mark messages as read. Status: ${response.statusCode}, Body: ${response.data}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update read status: ${response.statusCode}')),
          );
        }
      }
    } on DioException catch (e) {
      print("ChatPage: DioException marking messages as read: ${e.message}");
      if (e.response?.statusCode == 401) {
        print("ChatPage: Unauthorized (DioException). Attempting token refresh.");
        bool refreshed = await refreshToken();
        if (refreshed) {
          _markMessagesAsRead(senderId); // Retry
        } else {
          print("ChatPage: Token refresh failed (DioException).");
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session expired. Please try again.'),backgroundColor: Colors.orange,),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating read status: ${e.message}')),
        );
      }
    }
    catch (e) {
      print("ChatPage: Unexpected error marking messages as read: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  Future<void> _connectWebSocket() async {
    if (_isConnectedToWebSocket || _channel != null) return; // Already connected or trying
    final currentUser = Provider.of<UserProvider>(context, listen: false);
    final SharedPreferences prefs =  await SharedPreferences.getInstance();

    refreshToken();
    final wsUrl = Uri.parse('ws://192.168.1.62:8000/ws/chat?token=${prefs.getString("token")}');
    print("ChatPage: Attempting to connect to WebSocket: $wsUrl");
    setState(() {
      _connectionStatusMessage = "Connecting...";
    });

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnectedToWebSocket = true; // Optimistic, listen stream will confirm
      if (mounted) {
        setState(() {
          _connectionStatusMessage = null; // Or "Connected" briefly
        });
      }
      print("ChatPage: WebSocket channel initiated. Listening for messages...");

      _channel!.stream.listen(
            (messageData) {
          print('--------------------------------------------------');
          print('ChatPage: WebSocket Raw messageData TYPE: ${messageData.runtimeType}');
          print('ChatPage: WebSocket Raw messageData VALUE: "$messageData"');

          if (!mounted) {
            print('ChatPage: Not mounted, returning.');
            print('--------------------------------------------------');
            return;
          }

          // --- Try to parse as JSON first, as status updates might be JSON ---
          try {
            final decodedJson = jsonDecode(messageData as String); // Assuming messageData is a string
            print('ChatPage: Successfully parsed as JSON: $decodedJson');

            // Check if this JSON is a STATUS UPDATE
            // Example 1: {"status":"delivered", "receiver_id":2}
            // Example 2: {"type":"status", "payload": {"status":"delivered", "receiver_id":2}}
            // Adapt the checks below to YOUR EXACT JSON structure for status updates.

            String? statusType;
            int? statusReceiverId;
            String? clientMessageIdForStatusUpdate; // If server sends it back

            if (decodedJson is Map<String, dynamic>) {
              // Simple structure: {"status":"delivered", "receiver_id":2}
              if (decodedJson.containsKey('status') && decodedJson.containsKey('receiver_id')) {
                statusType = decodedJson['status']?.toString().toLowerCase();
                if (decodedJson['receiver_id'] is int) {
                  statusReceiverId = decodedJson['receiver_id'] as int;
                }
                if (decodedJson.containsKey('client_message_id') && decodedJson['client_message_id'] is String) {
                  clientMessageIdForStatusUpdate = decodedJson['client_message_id'] as String;
                }
              }
              // Add more 'else if' blocks here if your server uses other JSON structures for status,
              // e.g., if (decodedJson.containsKey('type') && decodedJson['type'] == 'status_update') { ... }
            }

            if (statusType == "delivered" && statusReceiverId != null) {
              print('ChatPage: JSON identified as a "delivered" status update for receiver_id: $statusReceiverId.');
              if (statusReceiverId == widget.chatUser.id) {
                ChatMessage? messageToUpdate;
                int messageIndex = -1;

                if (clientMessageIdForStatusUpdate != null) {
                  messageIndex = _messages.indexWhere((msg) => msg.id == clientMessageIdForStatusUpdate && msg.isSentByMe);
                } else {
                  // Fallback: Update the most recent sent/sending message to this user
                  messageIndex = _messages.indexWhere((msg) =>
                  msg.isSentByMe &&
                      msg.receiverId == widget.chatUser.id &&
                      (msg.status == MessageStatus.sending || msg.status == MessageStatus.sent));
                }

                if (messageIndex != -1) {
                  print('ChatPage: Updating message ID ${_messages[messageIndex].id} to "delivered".');
                  _updateMessageStatusByClientId(_messages[messageIndex].id, MessageStatus.delivered);
                } else {
                  print('ChatPage: Received "delivered" JSON status for ${widget.chatUser.id}, but no matching sent/sending message found (Client ID for status: $clientMessageIdForStatusUpdate).');
                }
              } else {
                print('ChatPage: Received "delivered" JSON status for a different receiver: $statusReceiverId. Current chat is with ${widget.chatUser.id}.');
              }
              print('--------------------------------------------------');
              return; // IMPORTANT: Processed as JSON status update, do not display.
            }

            // If it was JSON but NOT a recognized status update, it *might* be a JSON-formatted chat message
            // from the other user. Your ChatMessage.fromWebSocketString would need to handle that,
            // or you'd add specific parsing here. For now, if it's not a status update, we'll let it fall through
            // to the string processing logic, which might be incorrect if the other user sends JSON messages.
            // THIS IS A CRITICAL POINT: If other users CAN send JSON messages, you need to handle that here.
            print('ChatPage: JSON was not a recognized status update. Potentially a JSON chat message or unexpected JSON.');
            // If you are SURE other users don't send JSON, you could even 'return;' here to discard unknown JSON.

          } catch (e) {
            // It's not valid JSON, or messageData wasn't a string.
            // Proceed to treat it as a potential string message (echo or from other user).
            print('ChatPage: Not valid JSON or not a string. Error: $e. Treating as potential string message.');
          }

          // --- If it wasn't processed as JSON status update, continue with string processing ---
          // This assumes messageData IS a string if it reaches here and failed JSON parsing
          if (messageData is! String) {
            print('ChatPage: MessageData is not a string after JSON parse attempt failed. Discarding. Type: ${messageData.runtimeType}');
            print('--------------------------------------------------');
            return;
          }
          String receivedString = (messageData as String).trim();
          print('ChatPage: Processing as string: "$receivedString"');


          // --- 2. Check for ECHO of a message THIS client sent (e.g., "MyName: My Message Text") ---
          String potentialEchoTextContent;
          String? potentialEchoSenderName;
          int colonIdxEcho = receivedString.indexOf(':');

          if (colonIdxEcho != -1 && colonIdxEcho + 1 < receivedString.length) {
            potentialEchoSenderName = receivedString.substring(0, colonIdxEcho).trim();
            potentialEchoTextContent = receivedString.substring(colonIdxEcho + 1).trim();
          } else {
            potentialEchoTextContent = receivedString;
          }

          // Check if the sender is me (based on name)
          if (potentialEchoSenderName == (currentUser.current!.firstName! + " " + currentUser.current!.lastName!)) {
            final recentlySentMessageIndex = _messages.indexWhere((m) =>
            m.isSentByMe &&
                m.text == potentialEchoTextContent &&
                DateTime.now().difference(m.timestamp).inSeconds < 7);

            if (recentlySentMessageIndex != -1) {
              print('ChatPage: Identified as STRING ECHO of own sent message: "$receivedString". Ignoring for display.');
              if (_messages[recentlySentMessageIndex].status == MessageStatus.sending) {
                _updateMessageStatusByClientId(_messages[recentlySentMessageIndex].id, MessageStatus.sent);
              }
              print('--------------------------------------------------');
              return; // It's an echo of my own message, DO NOT display.
            }
          }

          // --- 3. Process as a NEW INCOMING STRING CHAT MESSAGE from the OTHER USER ---
          // (e.g., "OtherUserName: Actual message text")
          print('ChatPage: Processing as a potential new STRING message from other user: "$receivedString"');

          // Guard: If by some chance a raw JSON status string slipped through, try to filter it one last time.
          // This is a bit defensive, ideally the JSON parsing above catches it.
          if (receivedString.toLowerCase().contains('"status":"delivered"') && receivedString.toLowerCase().contains('"receiver_id":')) {
            print('ChatPage: WARNING - Raw string looks like JSON status update, but was not caught by JSON parser. Discarding. String: "$receivedString"');
            print('--------------------------------------------------');
            return;
          }

          final newMessage = ChatMessage.fromWebSocketString(
            receivedString,
            currentUser.current!.id!,
            widget.chatUser,
          );

          if (newMessage.isSentByMe) {
            print('ChatPage: Parsed incoming STRING message as if sent by me, but it was not an identified echo. This is unusual. Discarding. Original: "$receivedString"');
            print('--------------------------------------------------');
            return;
          }

          if (!_messages.any((m) =>
          m.text == newMessage.text &&
              m.senderId == newMessage.senderId &&
              !m.isSentByMe &&
              m.timestamp.difference(newMessage.timestamp).inSeconds.abs() < 3 )) {
            setState(() {
              _messages.insert(0, newMessage);
            });
            print('ChatPage: Added new message to UI: "${newMessage.text}"');
          } else {
            print("ChatPage: Suppressed potential duplicate incoming STRING message from other user: ${newMessage.text}");
          }
          print('--------------------------------------------------');

        },
        onDone: () {
          print('ChatPage: WebSocket channel closed.');
          if (mounted) {
            setState(() {
              _isConnectedToWebSocket = false;
              _connectionStatusMessage = "Disconnected. Reconnecting...";
            });
            // Implement reconnection logic with delay
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isConnectedToWebSocket) _connectWebSocket();
            });
          }
        },
        onError: (error) {
          print('ChatPage: WebSocket error: $error');
          if (mounted) {
            setState(() {
              _isConnectedToWebSocket = false;
              _connectionStatusMessage = "Connection error. Retrying...";
            });
            _channel?.sink.close(); // Ensure old channel is closed
            _channel = null;
            // Implement reconnection logic with delay
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isConnectedToWebSocket) _connectWebSocket();
            });
          }
        },
        cancelOnError: true, // Important to stop listening on error to allow reconnection
      );
    } catch (e) {
      print("ChatPage: WebSocket connection exception: $e");
      if (mounted) {
        setState(() {
          _isConnectedToWebSocket = false;
          _connectionStatusMessage = "Connection failed. Retrying...";
        });
        // Implement reconnection logic with delay
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_isConnectedToWebSocket) _connectWebSocket();
        });
      }
    }
  }

  void _sendMessage() {
    final currentUser = Provider.of<UserProvider>(context, listen: false);
    if (_messageController.text.trim().isEmpty) return;
    if (_channel == null || !_isConnectedToWebSocket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Trying to send...')),
      );
      // Attempt to reconnect if not connected, then the user can try sending again.
      if (!_isConnectedToWebSocket) _connectWebSocket();
      // Add message with "failed" status or queue it
      final clientMessageId = _generateClientMessageId();
      final newMessage = ChatMessage(
        id: clientMessageId,
        senderId: currentUser.current!.id!,
        receiverId: widget.chatUser.id,
        text: _messageController.text.trim(),
        timestamp: DateTime.now(),
        status: MessageStatus.failed, // Mark as failed initially
        isSentByMe: true,
      );
      setState(() {
        _messages.insert(0, newMessage);
        _messageController.clear();
      });
      return;
    }

    final messageText = _messageController.text.trim();
    final clientMessageId = _generateClientMessageId(); // For client-side tracking

    // Add to UI optimistically with 'sending' status
    final newMessage = ChatMessage(
      id: clientMessageId,
      senderId: currentUser.current!.id!,
      receiverId: widget.chatUser.id,
      text: messageText,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isSentByMe: true,
    );

    setState(() {
      _messages.insert(0, newMessage); // Add to top (newest)
      _messageController.clear();
    });

    // Send to WebSocket
    final messagePayload = jsonEncode({
      'receiver_id': widget.chatUser.id,
      'message': messageText,

    });

    try {
      print("ChatPage: Sending message via WebSocket: $messagePayload");
      _channel!.sink.add(messagePayload);
      // Server should ideally send back an ack or the message itself with a server_id and 'sent' status.
      // For now, we assume 'sent' if sink.add doesn't throw.
      // A more robust solution involves server acknowledgements.
      _updateMessageStatusByClientId(clientMessageId, MessageStatus.sent);

    } catch (e) {
      print("ChatPage: Error sending message via WebSocket: $e");
      _updateMessageStatusByClientId(clientMessageId, MessageStatus.failed);
    }
  }

  // Update status for a message sent by this client
  void _updateMessageStatusByClientId(String clientMsgId, MessageStatus newStatus) {
    if (!mounted) return;
    final messageIndex = _messages.indexWhere((msg) => msg.id == clientMsgId && msg.isSentByMe);
    if (messageIndex != -1) {
      if (_messages[messageIndex].status != newStatus) {
        setState(() {
          _messages[messageIndex].status = newStatus;
        });
      }
    }
  }



  // UI Helper for message status
  Widget _buildMessageStatusWidget(ChatMessage message) {
    if (!message.isSentByMe) return const SizedBox.shrink(); // Only show status for my messages

    IconData? iconData;
    Color iconColor = Colors.white.withOpacity(0.75); // Default for sent messages
    double iconSize = 13.0;
    String statusText = "";

    // Show status for the MOST RECENT sent message only
    // This logic needs to be robust if messages can be reordered or history is loaded.
    // For simplicity, we check if this message is the first 'isSentByMe' message in the list.
    final mostRecentSentByMe = _messages.firstWhere((m) => m.isSentByMe, orElse: () => message /* fallback to current if none */);
    if (message.id != mostRecentSentByMe.id && message.status != MessageStatus.failed) { // Always show failed status
      // If not the most recent, and not failed, only show 'read' tick if applicable, otherwise nothing
      if (message.status == MessageStatus.read) {
        // No text, just the read icon
      } else {
        return const SizedBox.shrink();
      }
    }


    switch (message.status) {
      case MessageStatus.sending:
        statusText = "Sending";
        iconData = Icons.schedule_outlined;
        break;
      case MessageStatus.sent:
        statusText = "Sent";
        iconData = Icons.done;
        break;
      case MessageStatus.delivered:
        statusText = "Delivered";
        iconData = Icons.done_all;
        break;
      case MessageStatus.read:
        statusText = "Read";
        iconData = Icons.done_all;
        iconColor = Colors.lightBlueAccent[100]!; // Special color for read
        break;
      case MessageStatus.failed:
        statusText = "Failed";
        iconData = Icons.error_outline;
        iconColor = Colors.orange[200]!;
        break;
      case MessageStatus.none:
        return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if(statusText.isNotEmpty && (message.id == mostRecentSentByMe.id || message.status == MessageStatus.failed) ) // Show text only for most recent or if failed
          Text(
            statusText,
            style: TextStyle(
              fontSize: 9,
              color: iconColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        if (iconData != null) ...[
          if(statusText.isNotEmpty && (message.id == mostRecentSentByMe.id || message.status == MessageStatus.failed) ) const SizedBox(width: 2),
          Icon(iconData, size: iconSize, color: iconColor),
        ]
      ],
    );
  }
// Continuing in _ChatPageState

  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context);
    final bool canPop = Navigator.canPop(context);
    const Color headerColor = Color.fromARGB(255, 159, 134, 192); // Fluently purple

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header UI
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Row(
                  children: [
                    if (canPop)
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.arrow_back_ios_new, color: headerColor, size: 24),
                        ),
                      )
                    else
                      const SizedBox(width: 40), // Placeholder if no back button

                    // --- TAPPABLE USER INFO AREA ---
                    Expanded(
                      child: InkWell( // Wrap the user info Row with InkWell
                        onTap: () {
                          // Navigate to FriendsProfilePage with widget.chatUser.id
                          print("ChatPage: Navigating to FriendsProfilePage for user ID: ${widget.chatUser.id}");
                          // TODO: Replace 'FriendsProfilePage' with your actual page
                          // and ensure you have a route set up for it if using named routes.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProfilePage(user: widget.chatUser)
                              // Example if FriendsProfilePage takes a User object:
                              // builder: (context) => FriendsProfilePage(user: widget.chatUser),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8), // Optional: for ripple effect shape
                        child: Row( // Row containing Avatar and Name
                          mainAxisAlignment: MainAxisAlignment.center, // Center the avatar and name
                          mainAxisSize: MainAxisSize.min, // Ensure InkWell doesn't expand unnecessarily
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: headerColor.withOpacity(0.1),
                              backgroundImage: widget.chatUser.profile_image != null && widget.chatUser.profile_image!.isNotEmpty
                                  ? NetworkImage("http://192.168.1.62:8000/uploads/profile_pics/${widget.chatUser.profile_image!}")
                                  : null,
                              child: widget.chatUser.profile_image == null || widget.chatUser.profile_image!.isEmpty
                                  ? Text(
                                widget.chatUser.name.isNotEmpty ? widget.chatUser.name[0].toUpperCase() : "?",
                                style: const TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold),
                              )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.chatUser.name,
                                style: const TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 20),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- END OF TAPPABLE USER INFO AREA ---
                    const SizedBox(width: 40), // Placeholder for balance, ensure it matches the back button side
                  ],
                ),
              ),
            ),
          ),

          // Message List
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoadingHistory && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(child: Text("No messages yet. Say hi!", style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                reverse: true, // Show newest messages at the bottom
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  // Determine if sender name should be shown (for received messages from other users)
                  bool showSenderName = !message.isSentByMe &&
                      message.senderId != currentUser.current!.id! && // Should always be true for !isSentByMe
                      widget.chatUser.name.isNotEmpty; // Or use a senderName field if available from WS

                  return Align(
                    alignment: message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Card(
                      elevation: 1.0,
                      color: message.isSentByMe ? headerColor.withOpacity(0.95) : Colors.grey[200],
                      margin: EdgeInsets.only(
                        top: 4, bottom: 4,
                        left: message.isSentByMe ? 60 : 10,
                        right: message.isSentByMe ? 10 : 60,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: message.isSentByMe ? const Radius.circular(16) : const Radius.circular(4),
                          bottomRight: message.isSentByMe ? const Radius.circular(4) : const Radius.circular(16),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: message.isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showSenderName)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3.0),
                                child: Text(
                                  widget.chatUser.name, // Assuming it's the other user in 1-to-1
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: headerColor.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            Text(
                              message.text,
                              style: TextStyle(
                                color: message.isSentByMe ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            if (message.isSentByMe) // Only show status for messages sent by me
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: _buildMessageStatusWidget(message),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Message Input Area and General Connection Status
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 12.0, right: 12.0, top: 8.0,
              bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          fillColor: Colors.grey[100],
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage, // Enable/disable based on connection can be added
                      style: IconButton.styleFrom(
                        backgroundColor: headerColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                        shape: const CircleBorder(),
                      ),
                      iconSize: 26,
                    ),
                  ],
                ),
                if (_connectionStatusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      _connectionStatusMessage!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11.0),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



