import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../services/refresh_token_service.dart';
import 'chat_page.dart';


class ProfilePage extends StatelessWidget {
  final User user;
  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(user.name ?? "User Profile")),
      body: Center(child: Text("Profile of ${user.name ?? "Unknown"}")),
    );
  }
}


class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final Dio _dio = Dio();
  List<User> _allFetchedUsers = []; // Stores all users fetched from API
  List<User> _displayedUsers = [];  // Stores users to be displayed (can be filtered)
  bool _isLoading = false;
  String _currentSearchText = ""; // To keep track of the current search query

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Renamed for clarity
  }


  // Fetches the initial full list of users
  Future<void> _loadInitialData() async {
    final SharedPreferences prefs =  await SharedPreferences.getInstance();
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });
    refreshToken();

    String url = "http://10.0.2.2:8000/friends/get-friend-list";
    try {
      Response res = await _dio.get(url,
          options: Options(
              headers: {'Authorization': 'Bearer ${prefs.getString("token")}'
              }
              )
      );
      print("FriendsPage: Response status: ${res.statusCode}");

      List<User> tempUsers = [];
      if (res.data == null) {
        print("FriendsPage: Response data is null.");
      } else if (res.data is Map && (res.data as Map).containsKey('users') && (res.data as Map)['users'] is List) {
        List<dynamic> userDataList = (res.data as Map)['users'];
        print("FriendsPage: Response data is a Map with 'users' List. Count: ${userDataList.length}");
        if (userDataList.isNotEmpty) {
          print("FriendsPage: First item in 'users' data: ${userDataList.first}");
        }
        if (res.statusCode == 200) {
          for (var p in userDataList) {
            try {
              tempUsers.add(User.fromJson(p as Map<String, dynamic>));
            } catch (e, s) {
              print("FriendsPage: Error parsing user JSON: $p. Error: $e. Stacktrace: $s");
            }
          }
        } else {
          print("FriendsPage: Failed to get valid data. Status: ${res.statusCode}");
        }
      } else if (res.data is List) { // Assuming the API might sometimes return a direct list
        List<dynamic> userDataList = res.data as List;
        print("FriendsPage: Response data is a List. Count: ${userDataList.length}");
        if (userDataList.isNotEmpty) {
          print("FriendsPage: First item in response data: ${userDataList.first}");
        }
        if (res.statusCode == 200) {
          for (var p in userDataList) {
            try {
              tempUsers.add(User.fromJson(p as Map<String, dynamic>));
            } catch (e, s) {
              print("FriendsPage: Error parsing user JSON: $p. Error: $e. Stacktrace: $s");
            }
          }
        }
      }

      _allFetchedUsers = tempUsers;
      _applySearchFilter(); // Apply current search (if any) to the newly loaded data

    } catch (e, s) {
      _allFetchedUsers = [];
      _displayedUsers = []; // Also clear displayed users on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load friends. ${e.toString()}'))
        );
      }
      print("FriendsPage: Error loading initial data: $e. Stacktrace: $s");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          print("FriendsPage: _loadInitialData finished. _allFetchedUsers count: ${_allFetchedUsers.length}, _displayedUsers count: ${_displayedUsers.length}");
        });
      } else {
        _isLoading = false;
        print("FriendsPage: _loadInitialData finished. Widget not mounted.");
      }
    }
  }

  // Applies search filter to _allFetchedUsers and updates _displayedUsers
  void _applySearchFilter({String? searchText}) {
    if (searchText != null) {
      _currentSearchText = searchText.toLowerCase().trim();
    }

    if (_currentSearchText.isEmpty) {
      _displayedUsers = List.from(_allFetchedUsers);
    } else {
      _displayedUsers = _allFetchedUsers.where((user) {
        final nameMatches = user.name?.toLowerCase().contains(_currentSearchText) ?? false;
        final emailMatches = user.email?.toLowerCase().contains(_currentSearchText) ?? false;
        // Add other fields to search if needed, e.g., username
        // final usernameMatches = user.username?.toLowerCase().contains(_currentSearchText) ?? false;
        return nameMatches || emailMatches; // || usernameMatches;
      }).toList();
    }

    if (mounted) {
      setState(() {
        // This setState will trigger a rebuild of _friendsListView with the filtered list
        print("FriendsPage: Search filter applied. Displaying ${_displayedUsers.length} users for query: '$_currentSearchText'");
      });
    }
  }


  int _selectedIndex = 1; // 0: Home, 1: Friends, 2: Chat, 3: AI, 4: Account

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    else if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      // Already on friends page, potentially refresh or do nothing
      // If you want pull-to-refresh to also work with search, you might just reload initial data
      // _loadInitialData(); // This would clear the search
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/chat');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/ai');
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/account');
    }
    print("FriendsPage: Navigating to index $index");
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        onChanged: (value) { // Use onChanged for live filtering or onSubmitted
          _applySearchFilter(searchText: value);
        },
        // onSubmitted: (value) { // Or use onSubmitted if you prefer search on enter
        //   _applySearchFilter(searchText: value.trim());
        // },
        decoration: InputDecoration(
          hintText: "Search by name or email...", // Updated hint text
          contentPadding: const EdgeInsets.fromLTRB(12.0, 0, 0, 0),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(
                width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13.0),
            borderSide: const BorderSide(
                width: 2.0, color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide: const BorderSide(width: 2.0,
                color: Color.fromARGB(
                    255, 159, 134, 192)),
          ),
        ),
      ),
    );
  }

  Widget _friendsListView() {
    // Now uses _displayedUsers instead of _users
    print("FriendsPage: _friendsListView called. Rendering ${_displayedUsers.length} users.");
    if (_displayedUsers.isEmpty && !_isLoading) {
      if (_currentSearchText.isNotEmpty) {
        return Center(child: Text("No users found matching '$_currentSearchText'."));
      }
      return const Center(child: Text("No users found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _displayedUsers.length,
      itemBuilder: (context, index) {
        User user = _displayedUsers[index]; // Use from _displayedUsers

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              backgroundImage: (user.profile_image != null && user.profile_image!.isNotEmpty)
                  ? NetworkImage(user.profile_image!)
                  : null,
              onBackgroundImageError: (user.profile_image != null && user.profile_image!.isNotEmpty)
                  ? (exception, stackTrace) {
                print('Error loading image for ${user.name}: $exception');
              }
                  : null,
              child: (user.profile_image == null || user.profile_image!.isEmpty)
                  ? Text(
                (user.name?.isNotEmpty == true) ? user.name![0].toUpperCase() : (user.username?.isNotEmpty == true ? user.username![0].toUpperCase() : '?'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              )
                  : null,
            ),
            title: Text(
              user.name ?? user.username ?? "Unnamed User", // Fallback to username if name is null
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              // Display email if available, otherwise maybe city or other info
              "${user.email != null ? ' ${user.age}' : ''}",
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),



            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color.fromARGB(
                255, 159, 134, 192), size: 18),
            onTap: () {
              print("FriendsPage: Tapped on user: ${user.name ?? user.username}");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatPage(chatUser: user)),
              );
            },

          ),
        );
      },
    );
  }

  Widget buildUI() {
    // Uses _displayedUsers and _allFetchedUsers for conditions
    print("FriendsPage: buildUI called. _displayedUsers count: ${_displayedUsers.length}, _isLoading: $_isLoading");
    if (_isLoading && _allFetchedUsers.isEmpty) { // Show loading only if there's no data at all yet
      return const Center(child: CircularProgressIndicator());
    } else if (!_isLoading && _allFetchedUsers.isEmpty) { // No data loaded from API and not loading
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No Friends Found 😓", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text("Try searching or pull to refresh.", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    } else { // Data is loaded (or was loaded), show the list (which might be empty due to search)
      return Expanded(
        child: _friendsListView(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print("FriendsPage: Full build method called.");
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Good for pages with search bars
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Friends",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87),
        ),
         actions: [
           IconButton(
             icon: Icon(Icons.refresh),
             onPressed: () {
               _currentSearchText = ""; // Clear search on manual refresh
               // Consider clearing the text field as well if you have a controller for it
               _loadInitialData();
             },
           )
         ],
      ),
      body: Column(
        children: [
          _searchBar(),
          buildUI(), // This will now use _displayedUsers
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