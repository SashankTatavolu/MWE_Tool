import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/projectDisplayPage.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _organisationController = TextEditingController();

  bool isLoading = true;
  List<Map<String, dynamic>> organizationUsers = [];
  bool _isUpdating = false;

  // Theme colors
  final Color primaryColor = Color(0xFF3B82F6);
  final Color accentColor = Color(0xFF2563EB);
  final Color backgroundColor = Color(0xFFF1F5F9);
  final Color cardColor = Colors.white;
  final Color textColor = Color(0xFF1E293B);
  final Color subtleTextColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    String? token = await SecureStorage().readSecureData('jwtToken');

    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/user-details');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      var userData = jsonDecode(response.body);
      setState(() {
        _nameController.text = userData['name'] ?? "";
        _emailController.text = userData['email'] ?? "";
        _languageController.text = (userData['language'] as List<dynamic>).join(
          ", ",
        );
        _roleController.text = userData['role'] ?? "";
        _organisationController.text = userData['organisation'] ?? "";

        if (userData['role'] == "Admin") {
          _fetchOrganizationUsers(userData['organisation']);
        }
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> _fetchOrganizationUsers(String organisation) async {
    String? token = await SecureStorage().readSecureData('jwtToken');

    var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/organisation/$organisation',
    );
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        organizationUsers = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );
      });
    }
  }

  Future<void> _deleteUser(int userId) async {
    String? token = await SecureStorage().readSecureData('jwtToken');

    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/delete-user/$userId');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      _showSnackBar("User deleted successfully!", isError: false);
      setState(() {
        organizationUsers.removeWhere((user) => user['id'] == userId);
      });
    } else {
      _showSnackBar("Failed to delete user", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateUserProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      var url = Uri.parse(
          'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/update-profile');
      String? token = await SecureStorage().readSecureData('jwtToken');

      var body = {
        "name": _nameController.text,
        "new_email": _emailController.text,
        "language": _languageController.text,
        "role": _roleController.text,
        "organisation": _organisationController.text,
      };

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      setState(() => _isUpdating = false);

      if (response.statusCode == 200) {
        _showSnackBar("Profile updated successfully!", isError: false);
      } else {
        _showSnackBar("Failed to update profile", isError: true);
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      _showSnackBar("An error occurred", isError: true);
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        "© 2025 MWE Annotation Tool",
        style: TextStyle(color: subtleTextColor, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardColor,
        foregroundColor: textColor,
        title: Text(
          "My Profile",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProjectsPage()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(),
                        SizedBox(height: 24),
                        _buildProfileCard(),
                        SizedBox(height: 24),
                        if (_roleController.text == "Admin") _buildUserList(),
                      ],
                    ),
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: AssetImage(
                "images/profile.png",
              ), // Profile image
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _nameController.text,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined, size: 16, color: subtleTextColor),
              SizedBox(width: 6),
              Text(
                _emailController.text,
                style: GoogleFonts.poppins(
                  color: subtleTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _roleController.text == "Admin"
                      ? Icons.admin_panel_settings
                      : Icons.person,
                  size: 16,
                  color: primaryColor,
                ),
                SizedBox(width: 6),
                Text(
                  _roleController.text,
                  style: GoogleFonts.poppins(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Personal Information", Icons.person_outline),
              SizedBox(height: 16),
              _buildTextField(
                _nameController,
                "Full Name",
                prefixIcon: Icons.badge_outlined,
              ),
              _buildTextField(
                _emailController,
                "Email",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              _sectionTitle("Preferences", Icons.settings_outlined),
              SizedBox(height: 16),
              _buildLanguageMultiSelect(),
              _buildRoleDropdown(),
              _buildOrganisationDropdown(),
              const SizedBox(height: 32),
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _isUpdating ? null : _updateUserProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isUpdating
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.save_rounded),
          label: Text(
            _isUpdating ? "Updating..." : "Update Profile",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _roleController.text.isNotEmpty ? _roleController.text : null,
        items: ["Annotator", "Admin"]
            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
            .toList(),
        onChanged: (value) {
          setState(() {
            _roleController.text = value!;
          });
        },
        decoration: InputDecoration(
          labelText: "Role",
          labelStyle: TextStyle(color: subtleTextColor),
          prefixIcon: Icon(Icons.work_outline, color: subtleTextColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
        dropdownColor: cardColor,
      ),
    );
  }

  Widget _buildOrganisationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _organisationController.text.isNotEmpty
            ? _organisationController.text
            : null,
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
          'CDAC-Pune',
          'Goa University',
        ].map((org) => DropdownMenuItem(value: org, child: Text(org))).toList(),
        onChanged: (value) {
          setState(() {
            _organisationController.text = value!;
          });
        },
        decoration: InputDecoration(
          labelText: "Organisation",
          labelStyle: TextStyle(color: subtleTextColor),
          prefixIcon: Icon(Icons.business_outlined, color: subtleTextColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        icon: Icon(Icons.arrow_drop_down, color: primaryColor),
        dropdownColor: cardColor,
      ),
    );
  }

  Widget _buildLanguageMultiSelect() {
    final availableLanguages = [
      'Assamese',
      'Boro',
      'English',
      'Hindi',
      'Nepali',
      'Manipuri',
      'Bangla',
      'Marathi',
      'Konkani',
    ];

    List<String> selectedLanguages = _languageController.text.isNotEmpty
        ? _languageController.text.split(',').map((e) => e.trim()).toList()
        : [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MultiSelectDialogField<String>(
            items: availableLanguages
                .map((lang) => MultiSelectItem(lang, lang))
                .toList(),
            initialValue: selectedLanguages,
            title: Text(
              "Select Languages",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            buttonIcon: Icon(Icons.arrow_drop_down, color: primaryColor),
            buttonText: Text(
              "Languages",
              style: TextStyle(color: subtleTextColor),
            ),
            searchable: true,
            dialogHeight: MediaQuery.of(context).size.height * 0.1,
            dialogWidth: MediaQuery.of(context).size.width * 0.8,
            selectedColor: primaryColor, // Highlights selected items
            selectedItemsTextStyle: TextStyle(
              color: Colors.white,
            ), // Text color for selected items
            listType: MultiSelectListType.CHIP,
            onConfirm: (selected) {
              setState(() {
                _languageController.text = selected.join(", ");
              });
            },
            chipDisplay: MultiSelectChipDisplay(
              chipColor: primaryColor.withOpacity(0.1),
              textStyle: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
              onTap: (value) {
                setState(() {
                  selectedLanguages.remove(value);
                  _languageController.text = selectedLanguages.join(", ");
                });
              },
              icon: Icon(Icons.close, color: primaryColor, size: 16),
            ),
          ),
          if (selectedLanguages.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Please select at least one language",
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Manage Users", Icons.manage_accounts),
          SizedBox(height: 16),
          if (organizationUsers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: subtleTextColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "No users found in your organization",
                      style: TextStyle(color: subtleTextColor),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: organizationUsers.length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final user = organizationUsers[index];
                return _buildUserTile(user);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey.shade50,
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: primaryColor),
        ),
        title: Text(
          user['name'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge, size: 14, color: subtleTextColor),
                SizedBox(width: 4),
                Text(
                  "ID: ${user['id']}",
                  style: TextStyle(color: subtleTextColor),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: "Delete User",
          onPressed: () => _showDeleteConfirmation(user['id']),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Delete User"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete this user? This action cannot be undone.",
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: subtleTextColor)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            icon: Icon(Icons.delete_forever, size: 16),
            label: Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subtleTextColor),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: subtleTextColor)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (value) => value!.isEmpty ? "$label is required" : null,
      ),
    );
  }
}
