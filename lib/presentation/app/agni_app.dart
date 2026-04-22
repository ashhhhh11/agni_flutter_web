import 'package:flutter/material.dart';

import '../../domain/entities/agni_content.dart';
import '../pages/landing_page.dart';
import '../../core/socket_service.dart';

const String _defaultWsUrl = 'wss://demo.nitya.ai/new/ws';
const String _envWsUrl = String.fromEnvironment('AGNI_WS_URL');
final String _wsUrl = _envWsUrl.isEmpty ? _defaultWsUrl : _envWsUrl;

class AgniApp extends StatefulWidget {
  final AgniContent content;
  const AgniApp({super.key, required this.content});

  @override
  State<AgniApp> createState() => _AgniAppState();
}

class _AgniAppState extends State<AgniApp> {
  bool _isDark = false;
  late final SocketService _socketService;
  int _rxMsgCount = 0;
  int _rxChunkCount = 0;
  int _rxChunkBytes = 0;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService(
      url: _wsUrl,
      authPayload: const {},
    );

    // ── Diagnostics ──────────────────────────────────────────────────────────
    _socketService.messages.listen((msg) {
      print("[AgniApp] Received message: $msg");
      _rxMsgCount += 1;
      final type = msg['type']?.toString() ?? 'unknown';
      final latency = msg['latency'];
      debugPrint(
        '[AgniApp] ✅ message[$_rxMsgCount] type=$type '
        'keys=${msg.keys.join(",")} '
        'latency=${latency is Map ? latency : "n/a"}',
      );
    });

    _socketService.audioChunks.listen((bytes) {
      _rxChunkCount += 1;
      _rxChunkBytes += bytes.length;
      debugPrint(
        '[AgniApp] 🔊 audio chunk[$_rxChunkCount] '
        'bytes=${bytes.length} total=$_rxChunkBytes',
      );
    });

    // Connect after listeners are wired so we don't miss early messages.
    _socketService.connect().then((_) {
      debugPrint(
        '[AgniApp] connect() resolved — '
        'url=$_wsUrl '
        'isConnected=${_socketService.isConnected} '
        'isConnecting=${_socketService.isConnecting}',
      );
      if (mounted) setState(() {}); // rebuild to reflect connection state
    });
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
        socketService: _socketService,
        isDark: _isDark,
        onToggleTheme: () => setState(() => _isDark = !_isDark),
      ),
    );
  }
}
