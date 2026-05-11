import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/app_entry.dart';
import 'core/const/keys/global_keys.dart';
import 'core/providers/logout_view_model.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/company/providers/company_provider.dart';
import 'features/example_field_delay/providers/example_field_delay_provider.dart';
import 'features/login/providers/login_provider.dart';
import 'features/profile/providers/profile_provider.dart';

import 'features/review/services/review_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/splash/splash_screen.dart';


final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();
void main() {
  WidgetsFlutterBinding.ensureInitialized();


  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(create: (_) => LogoutViewModel()),

      ChangeNotifierProvider(create: (_) => ExampleFieldDelayProvider()),
      ChangeNotifierProvider<LoginProvider>(
        create: (_) => LoginProvider(),
      ),
      ChangeNotifierProvider<SessionService>.value(
        value: SessionService.instance,
      ),

      // Provide CompanyProvider globally and initialize companies on app start
      ChangeNotifierProvider(
        create: (_) {
          final p = CompanyProvider();
          // Kick off initial load from server; will show loading in selector
          p.initialize();
          return p;
        },
      ),

    ],
      child: const MyApp())
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.


  @override
  void initState() {
    super.initState();
    // Track app open for review system after a delay to ensure activity is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        ReviewService().trackAppOpen();
      });
    });
  }

  @override
  Widget build(BuildContext context) {

    return Consumer<ThemeProvider>(

      builder: (context, provider, child) {
        return MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: [routeObserver],
            scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'mobo feild service',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.themeMode,
          debugShowCheckedModeBanner: false,
          home: SplashScreen()
        );
      }
    );
  }
}


