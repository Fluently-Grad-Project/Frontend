import 'package:flutter/material.dart';
import 'language_selection_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  String firstName = '';
  String lastName = '';
  String gender = '';
  String email = '';
  String password = '';
  String? selectedDay;
  String? selectedMonth;
  String? selectedYear;
  bool acceptedTerms = false;
  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9F86C0), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _label("First Name"),
                _buildTextField(
                  hint: 'Your First Name',
                  onChanged: (val) => firstName = val,
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                _label("Last Name"),
                _buildTextField(
                  hint: 'Your Last Name',
                  onChanged: (val) => lastName = val,
                ),
                const SizedBox(height: 16),

                _label("Gender"),
                DropdownButtonFormField<String>(
                  decoration: _dropdownDecoration(),
                  value: null,
                  items: ['Female', 'Male']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) => setState(() => gender = val ?? ''),
                  validator: (val) =>
                  val == null ? 'Please select a gender' : null,
                  hint: const Text(
                    'Select Gender',
                    style: TextStyle(color: Color(0xFFA2A2A2)),
                  ),
                ),

                const SizedBox(height: 16),
                _label("Date Of Birth"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _dropdownDecoration(),
                        value: selectedMonth,
                        items: List.generate(
                          12,
                              (index) => DropdownMenuItem(
                            value: '${index + 1}',
                            child: Text('${index + 1}'),
                          ),
                        ),
                        onChanged: (val) => setState(() => selectedMonth = val),
                        hint: const Text('MM',
                            style: TextStyle(color: Color(0xFFA2A2A2))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _dropdownDecoration(),
                        value: selectedDay,
                        items: List.generate(
                          31,
                              (index) => DropdownMenuItem(
                            value: '${index + 1}',
                            child: Text('${index + 1}'),
                          ),
                        ),
                        onChanged: (val) => setState(() => selectedDay = val),
                        hint: const Text('DD',
                            style: TextStyle(color: Color(0xFFA2A2A2))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _dropdownDecoration(),
                        value: selectedYear,
                        items: List.generate(
                          2025 - 1950 + 1,
                              (index) => DropdownMenuItem(
                            value: '${1950 + index}',
                            child: Text('${1950 + index}'),
                          ),
                        ),
                        onChanged: (val) => setState(() => selectedYear = val),
                        hint: const Text('YYYY',
                            style: TextStyle(color: Color(0xFFA2A2A2))),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _label("Email Address"),
                _buildTextField(
                  hint: 'Your email',
                  onChanged: (val) => email = val,
                  validator: (val) =>
                  val!.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),

                _label("Password"),
                TextFormField(
                  obscureText: obscurePassword,
                  onChanged: (val) => password = val,
                  validator: (val) =>
                  val!.length < 6 ? 'Min 6 characters' : null,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(color: Color(0xFFA2A2A2)),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => acceptedTerms = !acceptedTerms),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: acceptedTerms
                            ? const Color(0xFF9F86C0)
                            : Colors.white,
                        child: acceptedTerms
                            ? const Icon(Icons.check,
                            size: 16, color: Colors.white)
                            : const Icon(Icons.circle_outlined,
                            size: 16, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Text(
                        'I accept the terms and privacy policy',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9F86C0),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && acceptedTerms) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LanguageSelectionPage(firstName: firstName),
                        ),
                      );
                    } else if (!acceptedTerms) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please accept the terms.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9F86C0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Color(0xFF9F86C0)),
                        children: [
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: Color(0xFF9F86C0),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA2A2A2)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
