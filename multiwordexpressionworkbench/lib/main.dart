import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:multiwordexpressionworkbench/ui/contact_us.dart';
import 'package:multiwordexpressionworkbench/ui/feedback.dart';
import 'package:multiwordexpressionworkbench/ui/loginPage.dart';
import 'package:multiwordexpressionworkbench/ui/projectDisplayPage.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/register_page.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

Future<bool> checkLoginStatus() async {
  try {
    String? token = await SecureStorage().readSecureData('jwtToken');
    if (token.isEmpty || token == 'No data found!') {
      return false;
    }
    return !JwtDecoder.isExpired(token);
  } catch (e) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: checkLoginStatus(),
      builder: (context, snapshot) {
        // Show a loading screen while waiting for the future to complete
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Handle error case
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Error loading app')),
            ),
          );
        }

        final isLoggedIn = snapshot.data ?? false;

        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          initialRoute: isLoggedIn ? '/projects' : '/',
          getPages: [
            GetPage(
                name: '/',
                page: () => HomePage()), // Changed from '/home' to '/'
            GetPage(name: '/login', page: () => LoginPage()),
            GetPage(name: '/projects', page: () => ProjectsPage()),
            GetPage(name: '/register', page: () => RegisterPage()),
            GetPage(name: '/contact-us', page: () => ContactUsPage()),
            GetPage(name: '/feedback', page: () => FeedbackPage()),
            GetPage(name: '/terms', page: () => RegisterPage()),
          ],
          // Add unknown route handler as fallback
          unknownRoute: GetPage(
            name: '/not-found',
            page: () => Scaffold(
              body: Center(child: Text('Page not found')),
            ),
          ),
        );
      },
    );
  }
}
