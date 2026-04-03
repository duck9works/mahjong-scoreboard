import 'package:flutter/material.dart';
import 'ui/home_page.dart';
import 'ui/theme/mleague_theme.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '麻雀スコア',
      theme: MLeagueTheme.light(),
      darkTheme: MLeagueTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}
