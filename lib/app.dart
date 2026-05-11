import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_text_styles.dart';
import 'core/widgets/loading_view.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/match_service.dart';
import 'services/payment_service.dart';
import 'services/user_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/match_viewmodel.dart';
import 'viewmodels/payment_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'views/auth/profile_setup_screen.dart';
import 'views/auth/welcome_screen.dart';
import 'views/home/main_navigation_screen.dart';

class NextMatchApp extends StatelessWidget {
  const NextMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<UserService>(create: (_) => UserService()),
        Provider<MatchService>(create: (_) => MatchService()),
        Provider<PaymentService>(
          create: (context) => PaymentService(context.read<MatchService>()),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(context.read<AuthService>()),
        ),
        ChangeNotifierProvider<ProfileViewModel>(
          create: (context) => ProfileViewModel(context.read<UserService>()),
        ),
        ChangeNotifierProvider<MatchViewModel>(
          create: (context) => MatchViewModel(context.read<MatchService>()),
        ),
        ChangeNotifierProvider<PaymentViewModel>(
          create: (context) => PaymentViewModel(context.read<PaymentService>()),
        ),
      ],
      child: MaterialApp(
        title: 'NextMatch',
        debugShowCheckedModeBanner: false,
        theme: AppTextStyles.theme(),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return StreamBuilder<User?>(
      stream: authViewModel.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Warming up the pitch...');
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const WelcomeScreen();
        }

        return StreamBuilder<AppUser?>(
          stream: context.read<ProfileViewModel>().userStream(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Checking your squad sheet...');
            }

            final appUser = profileSnapshot.data;
            if (appUser == null) {
              return ProfileSetupScreen(firebaseUser: firebaseUser);
            }

            return MainNavigationScreen(currentUser: appUser);
          },
        );
      },
    );
  }
}
