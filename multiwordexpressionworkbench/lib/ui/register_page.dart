import 'package:flutter/material.dart';
import 'package:multiwordexpressionworkbench/fetchData/fetchProjectItems.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _selectedRole;
  String? _selectedOrganisation;
  List _selectedLanguages = [];
  final List<String> _languages = [
    'Assamese',
    'Boro',
    'English',
    'Hindi',
    'Nepali',
    'Manipuri',
    'Bangla',
    'Maithili',
    'Marathi',
    'Konkani'
  ];

  void _showSnackbar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isSuccess ? Colors.green[700] : Colors.red[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedLanguages.isEmpty ||
        _selectedRole == null ||
        _selectedOrganisation == null) {
      _showSnackbar("All fields are required", false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String languagesStr = _selectedLanguages.join(",");

      final result = await registerUser(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        languagesStr,
        _selectedRole!,
        _selectedOrganisation!,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _showSnackbar("Registration successful! Please log in.", true);
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // Show detailed error dialog
        _showRegistrationErrorDialog(
          result['error'] ?? 'Registration failed',
          result['suggestion'] ?? 'Please try again',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar("An unexpected error occurred", false);
    }
  }

  void _showRegistrationErrorDialog(String message, String suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Registration Issue"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
            Text(suggestion,
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
          if (message.toLowerCase().contains('email'))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
              child: Text("Go to Login"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                color: Colors.white,
                child: Column(
                  children: [
                    Image.asset(
                      "images/logo.png",
                      height: 70,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MultiWord Annotation Workbench',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24.0),
                margin: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create an Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please fill in all the required information',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a strong password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[400]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Language field
                    MultiSelectDialogField(
                      items: _languages
                          .map((lang) => MultiSelectItem<String>(lang, lang))
                          .toList(),
                      title: const Text("Select Languages"),
                      selectedColor: Colors.blue,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                        color: Colors.grey[50],
                      ),
                      buttonIcon: const Icon(Icons.language),
                      buttonText: const Text(
                        "Select Languages",
                        style: TextStyle(fontSize: 16),
                      ),
                      onConfirm: (values) {
                        setState(() {
                          _selectedLanguages =
                              values.cast<String>(); // ✅ Fix: Explicitly cast
                        });
                      },
                      chipDisplay: MultiSelectChipDisplay(
                        chipColor: Colors.blue[100],
                        textStyle: const TextStyle(color: Colors.black),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Role field
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        hintText: 'Select your role',
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      items: ['Admin', 'Annotator'].map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select a role'
                          : null, // Validation
                    ),
                    const SizedBox(height: 16),

                    // Organisation field
                    // Organisation field (NEW - Dropdown)
                    DropdownButtonFormField<String>(
                      value: _selectedOrganisation,
                      decoration: InputDecoration(
                        labelText: 'Organisation',
                        hintText: 'Select your organisation',
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      items: [
                        'NBU',
                        'DU',
                        'IIITM',
                        'IITB',
                        'IIT BHU',
                        'IIITH',
                        'GU',
                        'IIIT Manipur',
                        'NIT Meghalaya',
                        'JNU',
                        'CDAC-Pune',
                        'CDAC-Kolkata',
                        'Goa University'
                      ].map((String org) {
                        return DropdownMenuItem<String>(
                          value: org,
                          child: Text(org),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedOrganisation = newValue;
                        });
                      },
                      validator: (value) => value == null
                          ? 'Please select an organisation'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Colors.blue[700],
                                strokeWidth: 3,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          child: Text(
                            "Sign In",
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        color: Colors.grey[300],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                // Navigate to Contact Us page
                Navigator.pushNamed(context, '/contact');
              },
              child: const Text("Contact Us"),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Feedback page
                Navigator.pushNamed(context, '/feedback');
              },
              child: const Text("Feedback"),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Terms & Conditions page
                Navigator.pushNamed(context, '/terms');
              },
              child: const Text("Terms & Conditions"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
