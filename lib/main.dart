import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_page.dart';
import 'services/firebase_care_service.dart';
import 'services/notification_service.dart';
import 'state/care_store.dart';
import 'widgets/paw_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase intentionally has registrations for Android and iOS only. The
  // local store remains available for widget tests and any unsupported target.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const CarePawApp());
}

class CarePawApp extends StatefulWidget {
  const CarePawApp({super.key});

  @override
  State<CarePawApp> createState() => _CarePawAppState();
}

class _CarePawAppState extends State<CarePawApp> {
  late final CareStore _store;
  late final FirebaseCareService? _firebaseCareService;
  late final NotificationService? _notificationService;
  StreamSubscription<Uri>? _appLinkSubscription;
  String? _lastInvitationLink;

  @override
  void initState() {
    super.initState();
    _firebaseCareService = Firebase.apps.isNotEmpty
        ? FirebaseCareService()
        : null;
    _notificationService = _firebaseCareService == null
        ? null
        : NotificationService(_firebaseCareService);
    _store = CareStore(
      firebaseService: _firebaseCareService,
      notificationService: _notificationService,
    );
    final notificationService = _notificationService;
    if (notificationService != null) {
      unawaited(notificationService.initialize());
    }
    unawaited(_store.restoreSession());
    if (_firebaseCareService != null) {
      unawaited(_initializeAppLinks());
    }
  }

  Future<void> _initializeAppLinks() async {
    final appLinks = AppLinks();
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) await _handleAppLink(initialLink);
    _appLinkSubscription = appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleAppLink(uri));
    });
  }

  Future<void> _handleAppLink(Uri uri) async {
    final value = uri.toString();
    if (_lastInvitationLink == value) return;
    _lastInvitationLink = value;
    await _store.handleInvitationLink(uri);
  }

  @override
  void dispose() {
    _store.dispose();
    _appLinkSubscription?.cancel();
    _notificationService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'copaw',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1,
        maxScaleFactor: 1.3,
        child: child!,
      ),
      home: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          if (_store.isRestoringSession) {
            return PawBackground(
              child: const Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: pawPurple),
                      SizedBox(height: PawSpace.lg),
                      Text(
                        'Connecting your care home…',
                        style: TextStyle(
                          color: pawInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return _store.hasHousehold
              ? HomeShell(store: _store)
              : OnboardingPage(store: _store);
        },
      ),
    );
  }
}

/// A single type ramp for the whole app.
///
/// Sizes stop at 11pt — below that iOS and Android both become hard to read —
/// and weight is used sparingly so that size, not boldness, carries the
/// hierarchy. `fontFamily` is deliberately unset so each platform renders in
/// its own system face (SF Pro on iOS, Roboto on Android).
const _pawTextTheme = TextTheme(
  displaySmall: TextStyle(
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: -.5,
  ),
  headlineMedium: TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -.4,
  ),
  headlineSmall: TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
  ),
  titleLarge: TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
  ),
  titleMedium: TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
  ),
  titleSmall: TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w700,
  ),
  bodyLarge: TextStyle(fontSize: 16, height: 1.4),
  bodyMedium: TextStyle(fontSize: 14, height: 1.45),
  bodySmall: TextStyle(fontSize: 13, height: 1.4),
  labelLarge: TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w700),
  labelMedium: TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w700,
  ),
  labelSmall: TextStyle(
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w800,
    letterSpacing: .4,
  ),
);

ThemeData _buildTheme() {
  final textTheme = _pawTextTheme.apply(
    bodyColor: pawInk,
    displayColor: pawInk,
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: pawPurple,
    brightness: Brightness.light,
    surface: Colors.white,
    primary: pawPurpleInk,
    error: pawRoseInk,
  );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(PawRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: pawCream,
    textTheme: textTheme,
    // Splash and hover tints stay legible against the cream background.
    splashColor: pawPurple.withValues(alpha: .12),
    highlightColor: pawPurple.withValues(alpha: .06),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: pawInk,
      toolbarHeight: 60,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineSmall,
      // Cream background needs dark status-bar glyphs on both platforms.
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(pawMinTouch, pawMinTouch),
        foregroundColor: pawPurpleInk,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, pawMinTouch),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.lg),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, pawMinTouch),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.lg),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, pawMinTouch),
        foregroundColor: pawPurpleInk,
        textStyle: textTheme.labelLarge,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, pawMinTouch),
        textStyle: textTheme.labelLarge,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: pawMinTouch + 8,
      titleTextStyle: TextStyle(
        color: pawInk,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: TextStyle(color: pawMuted, fontSize: 13, height: 1.35),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? pawPurpleInk
            : pawMuted.withValues(alpha: .35),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F5FF),
      hintStyle: const TextStyle(color: pawMuted, fontSize: 15),
      labelStyle: const TextStyle(color: pawMuted, fontSize: 15),
      errorStyle: TextStyle(color: colorScheme.error, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PawSpace.lg,
        vertical: PawSpace.lg,
      ),
      border: border(Colors.transparent),
      enabledBorder: border(pawPurple.withValues(alpha: .18)),
      focusedBorder: border(pawPurpleInk, 2),
      errorBorder: border(colorScheme.error),
      focusedErrorBorder: border(colorScheme.error, 2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PawRadius.xxl),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: pawMuted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: pawMutedSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PawRadius.xxl),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: pawInk,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PawRadius.md),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 72,
      indicatorColor: pawLavender,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? pawPurpleDark
              : pawMuted,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? pawPurpleDark
              : pawMuted,
        ),
      ),
    ),
  );
}
