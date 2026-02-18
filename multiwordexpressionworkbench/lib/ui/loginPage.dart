// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as https;
import 'package:multiwordexpressionworkbench/fetchData/user_details.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/projectDisplayPage.dart';
import 'package:multiwordexpressionworkbench/ui/register_page.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  bool _validateInput() {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackbar("Email and Password cannot be empty.");
      return false;
    }
    return true;
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.blueGrey[800],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_validateInput()) return;

    setState(() {
      _isLoading = true;
    });

    bool success = await _validLogin(
      emailController.text,
      passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _showToolSelectionDialog();
    } else {
      _showSnackbar("Incorrect Email or Password");
    }
  }

  Future<bool> _validLogin(String email, String password) async {
    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis//user/login');
    var body = jsonEncode({"email": email, "password": password});

    try {
      final response = await https.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: body,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['access_token'] != null &&
            jsonResponse['role'] != null &&
            jsonResponse['organisation'] != null &&
            jsonResponse['email'] != null &&
            jsonResponse['name'] != null &&
            jsonResponse['user_id'] != null) {
          await SecureStorage().writeSecureData(
            'jwtToken',
            jsonResponse['access_token'],
          );
          await SecureStorage().writeSecureData('role', jsonResponse['role']);
          await SecureStorage().writeSecureData(
            'organization',
            jsonResponse['organisation'],
          );
          await SecureStorage().writeSecureData(
            'user_id',
            jsonResponse['user_id'].toString(),
          );
          await SecureStorage().writeSecureData(
            'user_email',
            jsonResponse['email'].toString(),
          );
          await SecureStorage().writeSecureData(
            'user_name',
            jsonResponse['name'].toString(),
          );
        } else {
          _showSnackbar("Invalid response from the server.");
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      _showSnackbar("Network Error. Please try again.");
      return false;
    }
  }

  void _showToolSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.app_shortcut, size: 50, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  "Choose a Tool",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Select a tool to continue with your workflow:",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.back();
                    Get.to(const ProjectsPage());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: const Icon(Icons.build, size: 24),
                  label: const Text(
                    "MWE Tool",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(
                        'https://www.cfilt.iitb.ac.in/annotation_tool_apis//home');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      _showSnackbar("Could not open the NER tool.");
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[400]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: const Icon(Icons.language, size: 24),
                  label: const Text(
                    "NER Tool",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    TextEditingController emailController = TextEditingController();
    TextEditingController otpController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    bool isOtpSent = false;
    bool isOtpVerified = false;
    bool isPasswordVisible = false;
    bool isSendingOtp = false;
    bool isVerifyingOtp = false;
    bool isResettingPassword = false;
    String infoMessage = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                "Forgot Password",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              content: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isOtpSent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.email, color: Colors.blue),
                            hintText: "Enter your email",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.blue[50],
                          ),
                        ),
                      ),
                    if (isOtpSent && !isOtpVerified)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock, color: Colors.blue),
                            hintText: "Enter OTP",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.blue[50],
                          ),
                        ),
                      ),
                    if (isOtpVerified)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TextField(
                          controller: passwordController,
                          obscureText:
                              !isPasswordVisible, // ✅ Hide or show password
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Colors.blue,
                            ),
                            hintText: "Enter new password",
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.blue[50],
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible =
                                      !isPasswordVisible; // ✅ Toggle visibility
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    if (infoMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          infoMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(height: 20),
                    if (isOtpSent)
                      Text(
                        "Enter the OTP sent to your email.",
                        style: TextStyle(color: Colors.green, fontSize: 14),
                      ),
                    if (isOtpVerified)
                      Text(
                        "Enter your new password.",
                        style: TextStyle(color: Colors.green, fontSize: 14),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
                if (!isOtpSent)
                  ElevatedButton(
                    onPressed: isSendingOtp
                        ? null
                        : () async {
                            setState(() {
                              isSendingOtp = true;
                              infoMessage = "";
                            });

                            bool ok = await sendOtp(emailController.text);

                            setState(() {
                              isSendingOtp = false;
                              if (ok) {
                                isOtpSent = true;
                                infoMessage =
                                    "OTP sent successfully to your email.";
                              } else {
                                infoMessage =
                                    "Failed to send OTP. Please try again.";
                              }
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: isSendingOtp
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text("Send OTP"),
                  ),
                if (isOtpSent && !isOtpVerified)
                  ElevatedButton(
                    onPressed: isVerifyingOtp
                        ? null
                        : () async {
                            setState(() {
                              isVerifyingOtp = true;
                              infoMessage = "";
                            });

                            bool verified = await verifyOtp(
                              emailController.text,
                              otpController.text,
                            );

                            setState(() {
                              isVerifyingOtp = false;
                              isOtpVerified = verified;
                              infoMessage = verified
                                  ? "OTP verified successfully."
                                  : "Invalid OTP. Please try again.";
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: isVerifyingOtp
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text("Verify OTP"),
                  ),
                if (isOtpVerified)
                  ElevatedButton(
                    onPressed: isResettingPassword
                        ? null
                        : () async {
                            setState(() {
                              isResettingPassword = true;
                              infoMessage = "";
                            });

                            bool ok = await resetPassword(
                              emailController.text,
                              passwordController.text,
                            );

                            setState(() {
                              isResettingPassword = false;
                              infoMessage = ok
                                  ? "Password reset successful."
                                  : "Failed to reset password.";
                            });

                            if (ok) {
                              await Future.delayed(Duration(seconds: 1));
                              Navigator.pop(context);
                              _showSnackbar("Password reset successfully.");
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                    ),
                    child: isResettingPassword
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text("Reset Password"),
                  ),
              ],
            );
          },
        );
      },
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
                padding: const EdgeInsets.symmetric(vertical: 32),
                color: Colors.white,
                child: Column(
                  children: [
                    Image.asset("images/logo.png", height: 80),
                    const SizedBox(height: 16),
                    Text(
                      'Multiword Expression Workbench',
                      style: TextStyle(
                        fontSize: 24,
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
                      'Sign In',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your credentials to access your account',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: [
                        AutofillHints.email,
                      ], // Enable autofill for email
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
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
                          borderSide: BorderSide(
                            color: Colors.blue[400]!,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        AutofillHints.password,
                      ], // Enable autofill for password
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
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
                          borderSide: BorderSide(
                            color: Colors.blue[400]!,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _showForgotPasswordDialog(context);
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Get.to(RegisterPage());
                          },
                          child: Text(
                            "Sign Up",
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
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                // Navigate to Contact Us page
                Navigator.pushNamed(context, '/contact-us');
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
}
