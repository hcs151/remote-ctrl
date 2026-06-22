import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RemoteCtrlApp());
}

class RemoteCtrlApp extends StatelessWidget {
  const RemoteCtrlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '远程控制',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
