import 'package:flutter/material.dart';
import 'auth_services.dart';
import '../Layer1/AppLoadingPage.dart';
import '../Layer2/HomePage.dart';
import '../Layer1/main.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    this.pageIfNotConnected,
  });

  final Widget? pageIfNotConnected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: authServices,
      builder: (context, authService, child) {
        return StreamBuilder(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingPage();
            }
            
            // If the snapshot has a user (is not null), go to HomePage
            if (snapshot.hasData && snapshot.data != null) {
              return const HomePage();
            }
            
            // Otherwise, show the welcome/login screen
            return pageIfNotConnected ?? const WelcomeScreen();
          },
        );
      },
    );
  }
}
