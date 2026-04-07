import 'package:flutter/material.dart';

import '../../domain/entities/agni_content.dart';
import '../pages/landing_page.dart';
import '../../core/socket_service.dart';

const String _wsUrl = 'ws://192.168.0.20:8000/ws';

class AgniApp extends StatefulWidget {
  final AgniContent content;
  const AgniApp({super.key, required this.content});

  @override
  State<AgniApp> createState() => _AgniAppState();
}

class _AgniAppState extends State<AgniApp> {
  bool _isDark = false;
  late final SocketService _socketService;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService(
      url: _wsUrl,
      authPayload: const {},
    )..connect();
  }

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Technodysis — Agentic AI & Automation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D7DA8),
          brightness: _isDark ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: AgniLandingPage(
        content: widget.content,
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
  }
}
