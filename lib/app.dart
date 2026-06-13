import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_text_styles.dart';
import 'core/widgets/loading_view.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/friends_service.dart';
import 'services/match_service.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/rating_service.dart';
import 'services/team_service.dart';
import 'services/user_service.dart';
import 'services/venue_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/friends_viewmodel.dart';
import 'viewmodels/match_viewmodel.dart';
import 'viewmodels/payment_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/rating_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'viewmodels/team_viewmodel.dart';
import 'viewmodels/venue_viewmodel.dart';
import 'views/auth/profile_setup_screen.dart';
import 'views/auth/welcome_screen.dart';
import 'views/home/main_navigation_screen.dart';
import 'views/splash/animated_splash_screen.dart';

class NextMatchApp extends StatelessWidget {
  const NextMatchApp({
    super.key,
    required this.settings,
    this.startupFuture,
  });

  final SettingsViewModel settings;
  final Future<void>? startupFuture;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsViewModel>.value(value: settings),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<UserService>(create: (_) => UserService()),
        Provider<MatchService>(create: (_) => MatchService()),
        Provider<RatingService>(create: (_) => RatingService()),
        Provider<VenueService>(create: (_) => VenueService()),
        Provider<FriendsService>(create: (_) => FriendsService()),
        Provider<ChatService>(create: (_) => ChatService()),
        Provider<TeamService>(create: (_) => TeamService()),
        Provider<NotificationService>(create: (_) => NotificationService()),
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
        ChangeNotifierProvider<RatingViewModel>(
          create: (context) => RatingViewModel(context.read<RatingService>()),
        ),
        ChangeNotifierProvider<VenueViewModel>(
          create: (context) => VenueViewModel(context.read<VenueService>()),
        ),
        ChangeNotifierProvider<FriendsViewModel>(
          create: (context) =>
              FriendsViewModel(context.read<FriendsService>()),
        ),
        ChangeNotifierProvider<ChatViewModel>(
          create: (context) => ChatViewModel(context.read<ChatService>()),
        ),
        ChangeNotifierProvider<TeamViewModel>(
          create: (context) => TeamViewModel(context.read<TeamService>()),
        ),
      ],
      child: Consumer<SettingsViewModel>(
        builder: (context, settings, _) {
          final theme = AppTextStyles.theme();
          return MaterialApp(
            title: 'NextMatch',
            debugShowCheckedModeBanner: false,
            theme: settings.reduceMotion
                ? theme.copyWith(pageTransitionsTheme: _noPageTransitions)
                : theme,
            builder: (context, child) {
              // Apply the user's text-size preference app-wide.
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(settings.textScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: AnimatedSplashScreen(
              startupFuture: startupFuture ?? Future<void>.value(),
              child: const AuthGate(),
            ),
          );
        },
      ),
    );
  }
}

/// Page transitions that render instantly, used when "reduce motion" is on.
const _noPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _NoTransitionsBuilder(),
    TargetPlatform.iOS: _NoTransitionsBuilder(),
    TargetPlatform.macOS: _NoTransitionsBuilder(),
    TargetPlatform.windows: _NoTransitionsBuilder(),
    TargetPlatform.linux: _NoTransitionsBuilder(),
  },
);

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
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
