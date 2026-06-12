import 'package:flutter/material.dart';

import '../data/wallet_repository.dart';
import '../features/auth/auth_gate.dart';
import '../security/security_controller.dart';
import '../security/security_scope.dart';

class MyWalletApp extends StatefulWidget {
  const MyWalletApp({super.key, required this.repository});

  final WalletRepository repository;

  @override
  State<MyWalletApp> createState() => _MyWalletAppState();
}

class _MyWalletAppState extends State<MyWalletApp> {
  ThemeMode _themeMode = ThemeMode.system;
  SecuritySettingsController? _securityController;

  @override
  void initState() {
    super.initState();
    _loadSecurity();
  }

  Future<void> _loadSecurity() async {
    final controller = await SecuritySettingsController.load();
    if (mounted) {
      setState(() => _securityController = controller);
    }
  }

  void _setThemeMode(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
  }

  @override
  Widget build(BuildContext context) {
    final securityController = _securityController;
    if (securityController == null) {
      return MaterialApp(
        title: 'MyWallet',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const LoadingAppScreen(),
      );
    }

    return MaterialApp(
      title: 'MyWallet',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: SecurityScope(
        controller: securityController,
        child: AuthGate(
          repository: widget.repository,
          themeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4967F2),
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF9BA8FF) : const Color(0xFF3047D7),
          secondary: isDark ? const Color(0xFF67D8BE) : const Color(0xFF007A68),
          tertiary: isDark ? const Color(0xFFFFC857) : const Color(0xFF985C00),
          error: isDark ? const Color(0xFFFF9A8C) : const Color(0xFFBA1A1A),
          surface: isDark ? const Color(0xFF111418) : const Color(0xFFFAFBFF),
          surfaceContainerHighest: isDark
              ? const Color(0xFF20252D)
              : const Color(0xFFE6E8F2),
          outlineVariant: isDark
              ? const Color(0xFF303640)
              : const Color(0xFFD9DCE8),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.7),
          ),
        ),
        color: isDark ? const Color(0xFF171B20) : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF151A1F) : const Color(0xFFF4F6FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF171B20) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }
}
