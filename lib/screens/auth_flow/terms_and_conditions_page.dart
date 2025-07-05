import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Color(0xFF9F86C0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''
Welcome to Fluently!

By creating an account, you agree to the following terms and conditions:

1. **Usage Agreement:**  
You agree to use the app responsibly and for its intended purposes only.

2. **Privacy Policy:**  
We respect your privacy. Your data will be stored securely and will not be shared with third parties without your consent.

3. **Account Security:**  
You are responsible for maintaining the confidentiality of your account details.

4. **Modification of Terms:**  
We reserve the right to modify these terms at any time.

For full details, please contact fluently567@gmail.com .

Thanks for using our app! 
            ''',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
