import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WildfireApp());
}

class WildfireApp extends StatelessWidget {
  const WildfireApp({super.key});

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFFF97316); // warm orange seed
    final theme = ThemeData(
      colorSchemeSeed: color,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(),
      brightness: Brightness.light,
    );
    final darkTheme = ThemeData(
      colorSchemeSeed: color,
      useMaterial3: true,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Wildfire Early Warning',
      theme: theme,
      darkTheme: darkTheme,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
