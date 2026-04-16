import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../core/agni_colors.dart';
import '../../core/contact_email.dart';
import '../../core/conversation_download.dart';
import '../../core/socket_service.dart';
import '../controllers/voice_chat_controller.dart';
import '../viewmodels/voice_chat_view_model.dart';
import '../widgets/earth_globe_painter.dart';
import '../../domain/entities/agni_content.dart';

// ─── Video Player Widget ───────────────────────────────────────────────────────

class _VideoPlayerWidget extends StatefulWidget {
  const _VideoPlayerWidget();

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/demo.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Stack(
            children: [
              VideoPlayer(_controller),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}

// ─── Main Landing Page ────────────────────────────────────────────────────────

class AgniLandingPage extends StatefulWidget {
  final AgniContent content;
  final SocketService socketService;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AgniLandingPage({
    super.key,
    required this.content,
    required this.socketService,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<AgniLandingPage> createState() => _AgniLandingPageState();
}

class _AgniLandingPageState extends State<AgniLandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _revealKeys = List.generate(5, (_) => GlobalKey());
  final List<bool> _revealed = List.filled(5, false);
  late AnimationController _globeController;
  late AnimationController _waveController;
  late AnimationController _marqueeController;
  late AnimationController _langController;
  late AnimationController _floatController;
  late final VoiceChatViewModel _voiceChatViewModel;

  int _langIndex = 0;
  double _langOpacity = 1.0;
  double _langOffset = 0.0;

  Timer? _langTimer;
  List<String> get _langs => widget.content.heroLangs;

  void _openContactForm() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _ContactFormDialog(),
    );
  }

  void _openDemoVideo() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const _VideoPlayerWidget(),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _globeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _langController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _voiceChatViewModel =
        VoiceChatViewModel(socketService: widget.socketService)
          ..addListener(_handleChatControllerChange);

    _scrollController.addListener(_checkReveal);

    _langTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cycleLang();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReveal());
  }

  void _handleChatControllerChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _cycleLang() async {
    setState(() {
      _langOpacity = 0.0;
      _langOffset = 8.0;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _langIndex = (_langIndex + 1) % _langs.length;
      _langOpacity = 1.0;
      _langOffset = 0.0;
    });
  }

  void _checkReveal() {
    for (int i = 0; i < _revealKeys.length; i++) {
      if (_revealed[i]) continue;
      final ctx = _revealKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      final screenH = MediaQuery.of(context).size.height;
      if (pos.dy < screenH * 0.88) {
        setState(() => _revealed[i] = true);
      }
    }
  }

  Future<void> _onTapToTalk() async {
    await _voiceChatViewModel.onTalkPressed();
  }

  Future<void> _downloadConversation() async {
    final visibleConversation = _voiceChatViewModel.visibleConversation;

    final buffer = StringBuffer()
      ..writeln('Technodysis Conversation Export')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln();

    if (visibleConversation.isEmpty) {
      buffer.writeln('No conversation yet.');
    }

    for (final message in visibleConversation) {
      final speaker = message.source == 'user' ? 'User' : 'Assistant';
      buffer
        ..writeln('$speaker:')
        ..writeln(message.text.trim())
        ..writeln();
    }

    final didDownload = await downloadConversationText(
      filename:
          'technodysis_conversation_${DateTime.now().millisecondsSinceEpoch}.txt',
      content: buffer.toString(),
    );

    if (!mounted || didDownload) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Conversation download is only available in the web app.'),
      ),
    );
  }

  @override
  void dispose() {
    _voiceChatViewModel
      ..removeListener(_handleChatControllerChange)
      ..dispose();
    _globeController.dispose();
    _waveController.dispose();
    _marqueeController.dispose();
    _langController.dispose();
    _floatController.dispose();
    _scrollController.dispose();
    _langTimer?.cancel();
    super.dispose();
  }

  AgniContent get content => widget.content;
  bool get isDark => widget.isDark;

  Color get bgColor => isDark ? AgniColors.darkBg : AgniColors.lightBg;
  Color get textColor => isDark ? AgniColors.darkText : AgniColors.lightText;
  Color get text2Color => isDark ? AgniColors.darkText2 : AgniColors.lightText2;
  Color get text3Color => isDark ? AgniColors.darkText3 : AgniColors.lightText3;
  Gradient get gradText =>
      isDark ? AgniColors.gradText : AgniColors.gradTextLight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackground(),
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              _checkReveal();
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  _buildNav(),
                  _buildHero(),
                  _buildMarquee(),
                  _buildStats(),
                  _buildFeatures(),
                  _buildComparison(),
                  _buildEarthSection(),
                  _buildCTABanner(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _globeController,
        builder: (_, __) => CustomPaint(
          painter: BackgroundPainter(
            isDark: isDark,
            t: _globeController.value,
          ),
        ),
      ),
    );
  }

  Widget _buildNav() {
    final isCompact = MediaQuery.of(context).size.width < 1240;
    final navBg = isDark
        ? const Color(0xFF030D1A).withOpacity(0.82)
        : const Color(0xFFDCEEF8).withOpacity(0.82);
    final borderColor = isDark
        ? AgniColors.darkBorder.withOpacity(0.12)
        : AgniColors.oceanMid.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _gradientText(
              'Technodysis.',
              GoogleFonts.playfairDisplay(
                fontSize: 24.8,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              )),
          const Spacer(),
          if (!isCompact) ...[
            Row(
              children: content.navItems
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(item,
                            style: TextStyle(
                              color: text2Color,
                              fontSize: 14.4,
                              fontWeight: FontWeight.w500,
                            )),
                      ))
                  .toList(),
            ),
            const SizedBox(width: 16),
          ],
          _gradientButton('Contact sales ->', small: true),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onToggleTheme,
            child: Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AgniColors.darkBorder.withOpacity(0.10)
                    : AgniColors.oceanMid.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AgniColors.darkBorder.withOpacity(0.20)
                      : AgniColors.oceanMid.withOpacity(0.18),
                ),
              ),
              child: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                size: 16,
                color: isDark ? AgniColors.oceanBright : AgniColors.oceanMid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _globeController,
            builder: (_, __) => CustomPaint(
              size: const Size(720, 720),
              painter: GlobeBgPainter(
                isDark: isDark,
                t: _globeController.value,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            child: Column(
              children: [
                _buildHeroBadge(),
                const SizedBox(height: 32),
                _buildLangTicker(),
                const SizedBox(height: 30),
                _buildHeroTitle(),
                const SizedBox(height: 22),
                Text(
                  'We build agentic AI and automation that transforms Banking, Telecom, Healthcare, Insurance, and Retail — with measurable ROI from day one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: text3Color,
                    height: 1.75,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _openContactForm,
                      child: _gradientButton('Talk to an expert'),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _openDemoVideo,
                      child: _ghostButton('See how it works'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildPhoneMockup(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AgniColors.oceanBright.withOpacity(0.08)
            : Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark
              ? AgniColors.oceanBright.withOpacity(0.25)
              : AgniColors.oceanMid.withOpacity(0.16),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                    color: AgniColors.oceanBright.withOpacity(0.10),
                    blurRadius: 20),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPulseDot(),
          const SizedBox(width: 8),
          Text(
            'Founded in 2020 · Bangalore HQ',
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w500,
              color: isDark ? AgniColors.oceanBright : AgniColors.oceanMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot() {
    return AnimatedBuilder(
      animation: _globeController,
      builder: (_, __) {
        final t = _globeController.value;
        final scale = 1.0 + (t - 0.5).abs() * 0.8;
        final opacity = 1.0 - (t - 0.5).abs() * 1.2;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.2, 1.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    isDark ? AgniColors.forestBright : AgniColors.forestLight,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AgniColors.forestBright.withOpacity(0.60),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLangTicker() {
    final tags = content.tickerTags;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: tags.asMap().entries.map((e) {
        return AnimatedBuilder(
          animation: _floatController,
          builder: (_, __) {
            final delay = e.key * 0.4;
            final t = ((_floatController.value + delay) % 1.0);
            final offset = math.sin(t * math.pi * 2) * 7;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0E2D4A).withOpacity(0.60)
                      : Colors.white.withOpacity(0.68),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark
                        ? AgniColors.oceanBright.withOpacity(0.12)
                        : AgniColors.oceanMid.withOpacity(0.14),
                  ),
                ),
                child: Text(e.value,
                    style: TextStyle(
                      fontSize: 13.6,
                      color: text2Color,
                      fontWeight: FontWeight.w500,
                    )),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildHeroTitle() {
    return Column(
      children: [
        Text(
          'Conversational AI + Automation',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            height: 1.06,
            letterSpacing: -2.16,
            color: textColor,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'for modern ',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                  letterSpacing: -2.16,
                  color: textColor,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => gradText.createShader(bounds),
                child: Text(
                  'enterprises.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    height: 1.06,
                    letterSpacing: -2.16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneMockup() {
    final isNarrow = MediaQuery.of(context).size.width < 1180;

    final phoneCard = Container(
      width: 340,
      height: 500,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF08162A).withOpacity(0.80)
            : Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isDark
              ? AgniColors.oceanBright.withOpacity(0.18)
              : Colors.white.withOpacity(0.90),
          width: isDark ? 1 : 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                    color: AgniColors.oceanBright.withOpacity(0.20),
                    blurRadius: 80),
                BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.40),
                    blurRadius: 24,
                    offset: const Offset(0, 24)),
              ]
            : [
                BoxShadow(
                    color: const Color(0xFF0A2342).withOpacity(0.22),
                    blurRadius: 80,
                    offset: const Offset(0, 20)),
              ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: LinearGradient(
                begin: const Alignment(-0.7, -0.9),
                end: const Alignment(1, 1),
                colors: isDark
                    ? [
                        AgniColors.oceanBright.withOpacity(0.06),
                        AgniColors.forestLight.withOpacity(0.05),
                      ]
                    : [
                        const Color(0xFFB4D7EB).withOpacity(0.22),
                        const Color(0xFFB4E1C8).withOpacity(0.18),
                      ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 80,
                height: 6,
                decoration: BoxDecoration(
                  color: isDark
                      ? AgniColors.oceanBright.withOpacity(0.15)
                      : AgniColors.oceanMid.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTalkingAvatar(),
                  const SizedBox(height: 14),
                  _buildWaveform(),
                  const SizedBox(height: 20),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _langOpacity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      transform: Matrix4.translationValues(0, _langOffset, 0),
                      child: Text(
                        _langs[_langIndex],
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 27.2,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agentic copilots · 24/7 uptime',
                    style: GoogleFonts.dmMono(
                      fontSize: 12.48,
                      color: text3Color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _onTapToTalk,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: AgniColors.grad,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AgniColors.oceanBright.withOpacity(
                              isDark ? 0.35 : 0.28,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _voiceChatViewModel.state == VoiceChatState.processing
                            ? '● Processing...'
                            : _voiceChatViewModel.state ==
                                    VoiceChatState.listening
                                ? '■ Tap to stop'
                                : '● Tap to talk',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (isNarrow) ...[
                    const SizedBox(height: 14),
                    _buildConversationPanel(width: 280, height: 170),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isNarrow) return phoneCard;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            phoneCard,
            const SizedBox(width: 40),
            _buildConversationPanel(width: 500, height: 500),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    final heights = [20.0, 36.0, 48.0, 28.0, 40.0, 24.0, 44.0, 32.0, 20.0];
    final delays = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
    return AnimatedBuilder(
      animation: _waveController,
      builder: (_, __) => SizedBox(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(heights.length, (i) {
            final phase = (_waveController.value + delays[i]) % 1.0;
            final scale = 0.3 + math.sin(phase * math.pi) * 0.7;
            return Container(
              width: 4,
              height: heights[i] * scale,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: AgniColors.grad,
                borderRadius: BorderRadius.circular(100),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: AgniColors.oceanBright.withOpacity(0.40),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTalkingAvatar() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (_, __) {
        final pulse = 0.08 + (_waveController.value * 0.12);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AgniColors.grad,
                boxShadow: [
                  BoxShadow(
                    color: AgniColors.oceanBright
                        .withOpacity(isDark ? 0.30 : 0.24),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF0E2D4A).withOpacity(0.65)
                    : Colors.white.withOpacity(0.82),
                border: Border.all(
                  color: isDark
                      ? AgniColors.oceanBright.withOpacity(0.30)
                      : AgniColors.oceanMid.withOpacity(0.22),
                  width: 1.4,
                ),
              ),
              child: Icon(
                Icons.person,
                color: isDark ? AgniColors.oceanBright : AgniColors.oceanMid,
                size: 28,
              ),
            ),
            Container(
              width: 86 + pulse * 80,
              height: 86 + pulse * 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AgniColors.oceanBright.withOpacity(0.10),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationPanel({
    double width = 228,
    double height = 152,
  }) {
    final panelBg = isDark
        ? const Color(0xFF08162A).withOpacity(0.78)
        : Colors.white.withOpacity(0.76);
    final border = isDark
        ? AgniColors.oceanBright.withOpacity(0.20)
        : AgniColors.oceanMid.withOpacity(0.18);

    final visibleConversation = _voiceChatViewModel.visibleConversation;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _downloadConversation,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                foregroundColor:
                    isDark ? AgniColors.oceanBright : AgniColors.oceanMid,
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                'Download',
                style: TextStyle(
                  fontSize: width >= 300 ? 12.2 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: visibleConversation.isEmpty
                ? Center(
                    child: Text(
                      'Speak to start conversation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: text3Color,
                        height: 1.4,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: visibleConversation.length,
                    itemBuilder: (context, index) {
                      final item = visibleConversation[
                          visibleConversation.length - 1 - index];
                      final isUser = item.source == 'user';
                      final isAssistant = item.source == 'assistant';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: width * 0.72),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? (isDark
                                      ? AgniColors.oceanBright.withOpacity(0.22)
                                      : AgniColors.oceanBright
                                          .withOpacity(0.16))
                                  : (isAssistant
                                      ? (isDark
                                          ? AgniColors.forestLight
                                              .withOpacity(0.18)
                                          : AgniColors.forestLight
                                              .withOpacity(0.16))
                                      : (isDark
                                          ? AgniColors.darkBorder
                                              .withOpacity(0.20)
                                          : Colors.white.withOpacity(0.75))),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    _sourceColor(item.source).withOpacity(0.30),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.text,
                              style: TextStyle(
                                fontSize: width >= 300 ? 12.2 : 10.8,
                                color: text2Color,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'user':
        return isDark ? AgniColors.oceanBright : AgniColors.oceanMid;
      case 'assistant':
        return isDark ? AgniColors.forestLight : AgniColors.forestMid;
      default:
        return text3Color;
    }
  }

  Widget _buildMarquee() {
    final items = content.marqueeItems;
    final doubled = [...items, ...items];
    final borderColor = isDark
        ? AgniColors.oceanBright.withOpacity(0.12)
        : const Color(0xFF1A4A6B).withOpacity(0.10);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF050F20).withOpacity(0.70)
            : Colors.white.withOpacity(0.55),
        border: Border.symmetric(
          horizontal: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'TRUSTED BY 2,100+ BUSINESSES ACROSS 12 COUNTRIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 12 * 0.12,
              color: text3Color,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 41,
            child: AnimatedBuilder(
              animation: _marqueeController,
              builder: (_, __) {
                return _MarqueeRow(
                  items: doubled,
                  progress: _marqueeController.value,
                  textStyle: TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w500,
                    color: text2Color,
                  ),
                  dividerColor: borderColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = content.stats;
    return RevealWidget(
      key: _revealKeys[0],
      revealed: _revealed[0],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Row(
          children: stats
              .map((s) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildStatCard(s.value, s.description),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStatCard(String num, String desc) {
    return _GlassCard(
      isDark: isDark,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: AgniColors.grad,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(color: Color(0x804EB3D3), blurRadius: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => gradText.createShader(b),
                  child: Text(num,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: Colors.white,
                      )),
                ),
                const SizedBox(height: 10),
                Text(desc,
                    style: TextStyle(
                      fontSize: 14.4,
                      color: text3Color,
                      height: 1.55,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    final features = content.features;
    return RevealWidget(
      key: _revealKeys[1],
      revealed: _revealed[1],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTag('Why Technodysis'),
            const SizedBox(height: 18),
            _sectionTitle('Not translated.', 'Native.'),
            const SizedBox(height: 16),
            Text(
              'Built from day one for the languages that matter most — not as an afterthought.',
              style: TextStyle(fontSize: 17.6, color: text3Color, height: 1.7),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 22,
              runSpacing: 22,
              children: features
                  .map((f) => SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 104 - 44) / 3,
                        child: _buildFeatCard(
                            f.icon, f.title, f.description, f.stat),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatCard(String icon, String title, String desc, String stat) {
    return _GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AgniColors.oceanBright.withOpacity(0.12),
                        AgniColors.forestBright.withOpacity(0.10),
                      ]
                    : [
                        AgniColors.oceanMid.withOpacity(0.10),
                        AgniColors.forestMid.withOpacity(0.10),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AgniColors.oceanBright.withOpacity(0.25)
                    : AgniColors.oceanMid.withOpacity(0.16),
              ),
            ),
            child:
                Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 19.2,
                fontWeight: FontWeight.w700,
                color: textColor,
              )),
          const SizedBox(height: 10),
          Text(desc,
              style:
                  TextStyle(fontSize: 14.4, color: text3Color, height: 1.65)),
          const SizedBox(height: 20),
          Text(stat,
              style: GoogleFonts.dmMono(
                fontSize: 12.8,
                color: isDark ? AgniColors.forestBright : AgniColors.forestMid,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _buildComparison() {
    final comparisons = content.comparisons;
    return RevealWidget(
      key: _revealKeys[2],
      revealed: _revealed[2],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTag('The difference'),
            const SizedBox(height: 18),
            _sectionTitle('Customer striving towards ', 'AI Transformation.'),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comparisons.isNotEmpty)
                  Expanded(
                      child: _buildCompCard(
                    isOurs: comparisons[0].isOurs,
                    badge: comparisons[0].badge,
                    headline: comparisons[0].headline,
                    items: comparisons[0].items,
                  )),
                if (comparisons.length > 1) const SizedBox(width: 24),
                if (comparisons.length > 1)
                  Expanded(
                      child: _buildCompCard(
                    isOurs: comparisons[1].isOurs,
                    badge: comparisons[1].badge,
                    headline: comparisons[1].headline,
                    items: comparisons[1].items,
                  )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompCard({
    required bool isOurs,
    required String badge,
    required String headline,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isOurs
            ? (isDark ? const Color(0xFF071828) : AgniColors.lightOceanDeep)
            : (isDark
                ? const Color(0xFF08141E).withOpacity(0.65)
                : Colors.white.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isOurs
              ? AgniColors.oceanBright.withOpacity(0.22)
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.80)),
        ),
        boxShadow: isOurs
            ? [
                BoxShadow(
                  color:
                      AgniColors.oceanBright.withOpacity(isDark ? 0.20 : 0.10),
                  blurRadius: 80,
                  offset: const Offset(0, 24),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (isOurs)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: RadialGradient(
                    center: const Alignment(0.5, -0.5),
                    radius: 1.1,
                    colors: [
                      AgniColors.oceanBright.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  gradient: isOurs ? AgniColors.grad : null,
                  color: isOurs
                      ? null
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : AgniColors.oceanMid.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(100),
                  border: isOurs
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : AgniColors.oceanMid.withOpacity(0.12),
                        ),
                  boxShadow: isOurs
                      ? [
                          BoxShadow(
                            color: AgniColors.oceanBright.withOpacity(0.30),
                            blurRadius: 20,
                          ),
                        ]
                      : null,
                ),
                child: Text(badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.06 * 12,
                      color: isOurs ? Colors.white : text3Color,
                    )),
              ),
              const SizedBox(height: 28),
              Text(headline,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24.8,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isOurs ? Colors.white.withOpacity(0.90) : textColor,
                  )),
              const SizedBox(height: 28),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            isOurs ? '✓' : '✕',
                            style: TextStyle(
                              fontSize: 12.8,
                              color: isOurs
                                  ? AgniColors.forestBright
                                  : (isDark
                                      ? const Color(0xFF334455)
                                      : const Color(0xFFBBBBBB)),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(item,
                                style: TextStyle(
                                  fontSize: 15.2,
                                  color: isOurs
                                      ? Colors.white.withOpacity(0.85)
                                      : (isDark
                                          ? text2Color.withOpacity(0.75)
                                          : AgniColors.lightText2),
                                  height: 1.5,
                                ))),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarthSection() {
    final langPills = content.langPills;
    return RevealWidget(
      key: _revealKeys[3],
      revealed: _revealed[3],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 48),
        child: Column(
          children: [
            _sectionTag('Global delivery'),
            const SizedBox(height: 18),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.playfairDisplay(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1.44,
                  color: textColor,
                ),
                children: [
                  const TextSpan(
                      text: "Built in Bangalore.\nDelivered across "),
                  WidgetSpan(
                    child: ShaderMask(
                      shaderCallback: (b) => gradText.createShader(b),
                      child: Text('the world.',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            height: 1.1,
                            letterSpacing: -1.44,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Technodysis builds from Bangalore and delivers with teams in Austin, London, and Dubai — partnering with clients across USA, Europe, MENA, and Africa.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.6, color: text3Color, height: 1.7),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _globeController,
              builder: (_, __) => Column(
                children: [
                  WireframeDottedGlobe(size: 360, isDark: isDark),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 820,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: langPills
                    .map((p) => _buildLangPill(p.label, p.type))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangPill(String label, String type) {
    Gradient? gradient;
    if (type == 'ocean') gradient = AgniColors.gradOcean;
    if (type == 'forest') gradient = AgniColors.gradLand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? (isDark
                ? const Color(0xFF0E2D4A).withOpacity(0.55)
                : Colors.white.withOpacity(0.65))
            : null,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: gradient != null
              ? Colors.transparent
              : (isDark
                  ? AgniColors.oceanBright.withOpacity(0.12)
                  : Colors.white.withOpacity(0.85)),
        ),
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: type == 'ocean'
                      ? AgniColors.oceanBright.withOpacity(isDark ? 0.25 : 0.22)
                      : AgniColors.forestLight
                          .withOpacity(isDark ? 0.22 : 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 14.4,
            fontWeight: FontWeight.w500,
            color: gradient != null ? Colors.white : text2Color,
          )),
    );
  }

  Widget _buildCTABanner() {
    return RevealWidget(
      key: _revealKeys[4],
      revealed: _revealed[4],
      child: Container(
        margin: const EdgeInsets.fromLTRB(52, 0, 52, 100),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF040E1C) : AgniColors.lightOceanDeep,
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment(-1, -1),
                  end: Alignment(1, 1),
                  colors: [
                    Color(0xFF040E1C),
                    Color(0xFF071828),
                    Color(0xFF0A2038)
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(48),
          border: isDark
              ? Border.all(
                  color: AgniColors.oceanBright.withOpacity(0.18),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: AgniColors.oceanBright.withOpacity(isDark ? 0.20 : 0.10),
              blurRadius: 80,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  gradient: RadialGradient(
                    center: const Alignment(0.3, -0.3),
                    radius: 1.1,
                    colors: [
                      AgniColors.oceanBright.withOpacity(isDark ? 0.22 : 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48),
              child: Column(
                children: [
                  Text(
                    'Talk to Technodysis.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFF7AB8D8), Color(0xFF74C69D)],
                        ).createShader(b),
                        child: Text('No signup needed.',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              height: 1.1,
                              color: Colors.white,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'See how agentic AI, RPA, and data platforms deliver 10x ROI for your industry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17.6,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _lightButton('Talk to an expert'),
                      const SizedBox(width: 16),
                      _outlineLightButton('Contact sales →'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final links = [
      'Technodysis',
      'Nitya.AI',
      'LinkedIn',
      'Twitter',
      'hello@technodysis.com'
    ];
    final isCompact = MediaQuery.of(context).size.width < 1200;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF030A16).withOpacity(0.70)
            : Colors.white.withOpacity(0.42),
        border: Border(
            top: BorderSide(
          color: isDark
              ? AgniColors.oceanBright.withOpacity(0.12)
              : AgniColors.oceanMid.withOpacity(0.12),
        )),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => gradText.createShader(b),
                  child: Text('(c) 2024 Technodysis. All rights reserved.',
                      style: TextStyle(fontSize: 12.8, color: text3Color)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: links
                      .map((link) => Text(link,
                          style: TextStyle(fontSize: 14, color: text3Color)))
                      .toList(),
                ),
                const SizedBox(height: 14),
                Text(
                    'Subramanya Arcade, Bannerghatta Main Road, Bengaluru, Karnataka – 560029',
                    style: TextStyle(fontSize: 12.8, color: text3Color)),
              ],
            )
          : Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => gradText.createShader(b),
                  child: Text('(c) 2024 Technodysis. All rights reserved.',
                      style: TextStyle(fontSize: 12.8, color: text3Color)),
                ),
                const Spacer(),
                Row(
                  children: links
                      .map((link) => Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(link,
                                style:
                                    TextStyle(fontSize: 14, color: text3Color)),
                          ))
                      .toList(),
                ),
                const Spacer(),
                Text(
                    'Subramanya Arcade, Bannerghatta Main Road, Bengaluru, Karnataka – 560029',
                    style: TextStyle(fontSize: 12.8, color: text3Color)),
              ],
            ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AgniColors.oceanBright.withOpacity(0.08)
            : AgniColors.oceanMid.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark
              ? AgniColors.oceanBright.withOpacity(0.25)
              : AgniColors.oceanMid.withOpacity(0.18),
        ),
      ),
      child: Text(text.toUpperCase(),
          style: GoogleFonts.dmMono(
            fontSize: 12,
            letterSpacing: 0.10 * 12,
            color: isDark ? AgniColors.oceanBright : AgniColors.oceanLight,
            fontWeight: FontWeight.w500,
          )),
    );
  }

  Widget _sectionTitle(String plain, String italic) {
    return Row(
      children: [
        Text(plain,
            style: GoogleFonts.playfairDisplay(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.44,
              color: textColor,
            )),
        ShaderMask(
          shaderCallback: (b) => gradText.createShader(b),
          child: Text(italic,
              style: GoogleFonts.playfairDisplay(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                height: 1.1,
                letterSpacing: -1.44,
                color: Colors.white,
              )),
        ),
      ],
    );
  }

  Widget _gradientText(String text, TextStyle style) {
    return ShaderMask(
      shaderCallback: (b) => gradText.createShader(b),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }

  Widget _gradientButton(String label, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 26 : 36,
        vertical: small ? 10 : 16,
      ),
      decoration: BoxDecoration(
        gradient: AgniColors.grad,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: AgniColors.oceanBright.withOpacity(isDark ? 0.35 : 0.32),
            blurRadius: isDark ? 32 : 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(label,
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 14 : 16,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _ghostButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0E2D4A).withOpacity(0.50)
            : Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark
              ? AgniColors.oceanBright.withOpacity(0.25)
              : AgniColors.oceanMid.withOpacity(0.20),
          width: 1.5,
        ),
      ),
      child: Text(label,
          style: TextStyle(
            color: text2Color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          )),
    );
  }

  Widget _lightButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 32,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Text(label,
          style: const TextStyle(
            color: Color(0xFF071828),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _outlineLightButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: AgniColors.oceanBright.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Text(label,
          style: TextStyle(
            color: AgniColors.darkText2,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}

// ─── Reveal Widget ────────────────────────────────────────────────────────────

class RevealWidget extends StatelessWidget {
  final bool revealed;
  final Widget child;

  const RevealWidget({super.key, required this.revealed, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 700),
      opacity: revealed ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 700),
        offset: revealed ? Offset.zero : const Offset(0, 0.06),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

// ─── Marquee ─────────────────────────────────────────────────────────────────

class _MarqueeRow extends StatefulWidget {
  final List<String> items;
  final double progress;
  final TextStyle textStyle;
  final Color dividerColor;

  const _MarqueeRow({
    required this.items,
    required this.progress,
    required this.textStyle,
    required this.dividerColor,
  });

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow> {
  @override
  Widget build(BuildContext context) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    double totalHalfWidth = 0;
    for (int i = 0; i < widget.items.length ~/ 2; i++) {
      tp.text = TextSpan(text: widget.items[i], style: widget.textStyle);
      tp.layout();
      totalHalfWidth += tp.width + 72 + 1;
    }

    final offset = -(widget.progress * totalHalfWidth);

    return ClipRect(
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.items
                .map((label) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          right:
                              BorderSide(color: widget.dividerColor, width: 1),
                        ),
                      ),
                      child: Text(label, style: widget.textStyle),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Glass Card ───────────────────────────────────────────────────────────────

class _GlassCard extends StatefulWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.isDark,
    required this.child,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF08182C).withOpacity(0.70)
              : Colors.white.withOpacity(0.68),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isDark
                ? AgniColors.oceanBright.withOpacity(_hovered ? 0.25 : 0.12)
                : Colors.white.withOpacity(_hovered ? 1.0 : 0.90),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDark
                  ? AgniColors.oceanBright.withOpacity(_hovered ? 0.14 : 0.08)
                  : AgniColors.oceanMid.withOpacity(_hovered ? 0.14 : 0.08),
              blurRadius: _hovered ? 48 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────

class BackgroundPainter extends CustomPainter {
  final bool isDark;
  final double t;
  BackgroundPainter({required this.isDark, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      _paintDark(canvas, size);
    } else {
      _paintLight(canvas, size);
    }
  }

  void _paintDark(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF030D1A));
    final blobs = [
      (
        size.width * 0.0,
        size.height * 0.0,
        700.0,
        const Color(0xFF0E3A60),
        0.55
      ),
      (
        size.width - 150,
        size.height - 120,
        600.0,
        const Color(0xFF1A4030),
        0.45
      ),
      (
        size.width * 0.38,
        size.height * 0.38,
        500.0,
        const Color(0xFF0A2D4A),
        0.35
      ),
      (
        size.width * 0.78,
        size.height * 0.15,
        350.0,
        const Color(0xFF2D6A4F),
        0.25
      ),
      (
        size.width * 0.05,
        size.height * 0.75,
        280.0,
        const Color(0xFF4EB3D3),
        0.10
      ),
    ];
    for (final b in blobs) {
      canvas.drawCircle(
          Offset(b.$1, b.$2),
          b.$3 / 2,
          Paint()
            ..color = b.$4.withOpacity(b.$5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80));
    }
  }

  void _paintLight(Canvas canvas, Size size) {
    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
        baseRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-0.5, -1),
            end: Alignment(0.5, 1),
            colors: [Color(0xFFDAEEF8), Color(0xFFE8F5F0), Color(0xFFD8EEE0)],
          ).createShader(baseRect));
    final blobs = [
      (
        size.width * 0.15,
        size.height * 0.20,
        650.0,
        const Color(0xFF7AB8D8),
        0.18
      ),
      (
        size.width - 120,
        size.height - 100,
        550.0,
        const Color(0xFF52B788),
        0.16
      ),
      (
        size.width * 0.40,
        size.height * 0.45,
        420.0,
        const Color(0xFF2D7DA8),
        0.12
      ),
      (
        size.width * 0.90,
        size.height * 0.20,
        300.0,
        const Color(0xFF74C69D),
        0.14
      ),
    ];
    for (final b in blobs) {
      canvas.drawCircle(
          Offset(b.$1, b.$2),
          b.$3 / 2,
          Paint()
            ..color = b.$4.withOpacity(b.$5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70));
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter old) => old.isDark != isDark;
}

class GlobeBgPainter extends CustomPainter {
  final bool isDark;
  final double t;
  GlobeBgPainter({required this.isDark, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = 1.0 + math.sin(t * math.pi) * 0.02;
    final r = (size.width / 2) * pulse;

    if (!isDark) {
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = AgniColors.oceanBright.withOpacity(0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60));
    }

    canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = (isDark ? AgniColors.oceanBright : AgniColors.oceanMid)
              .withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawCircle(
        center,
        r - 50,
        Paint()
          ..color = (isDark ? AgniColors.forestLight : AgniColors.forestMid)
              .withOpacity(0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawCircle(
        center,
        r - 110,
        Paint()
          ..color = (isDark ? AgniColors.oceanBright : AgniColors.oceanMid)
              .withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(GlobeBgPainter old) => old.t != t || old.isDark != isDark;
}

class EarthGlobePainter extends CustomPainter {
  final double t;
  final bool isDark;
  EarthGlobePainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final globeRect = Rect.fromCircle(center: center, radius: r);
    final spinOffset = math.sin(t * math.pi) * 0.04;

    final clipPath = Path()..addOval(globeRect);
    canvas.save();
    canvas.clipPath(clipPath);

    canvas.drawOval(
        globeRect,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0xFF1A4A6B), Color(0xFF0A2342)],
          ).createShader(globeRect));

    _drawRadialPatch(canvas, center, r,
        cx: 0.75 + spinOffset,
        cy: 0.25,
        stop1: 0.35,
        c0: const Color(0xFF7AB8D8),
        c1: Colors.transparent);
    _drawRadialPatch(canvas, center, r,
        cx: 0.20 - spinOffset,
        cy: 0.70,
        stop1: 0.35,
        c0: const Color(0xFF74C69D),
        c1: Colors.transparent);
    _drawRadialPatch(canvas, center, r,
        cx: 0.68 + spinOffset * 0.5,
        cy: 0.58,
        stop1: 0.55,
        midStop: 0.25,
        c0: const Color(0xFF52B788),
        cMid: const Color(0xFF2D6A4F),
        c1: Colors.transparent);
    _drawRadialPatch(canvas, center, r,
        cx: 0.32 - spinOffset * 0.5,
        cy: 0.38,
        stop1: 0.55,
        midStop: 0.25,
        c0: const Color(0xFF4EB3D3),
        cMid: const Color(0xFF2D7DA8),
        c1: Colors.transparent);
    _drawRadialPatch(canvas, center, r,
        cx: 0.28,
        cy: 0.32,
        stop1: 0.30,
        c0: Colors.white.withOpacity(0.15),
        c1: Colors.transparent);

    canvas.restore();

    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawOval(
        globeRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.7, 0.75),
            radius: 0.9,
            colors: [
              const Color(0xFF0A2342).withOpacity(0.40),
              Colors.transparent,
            ],
          ).createShader(globeRect));
    canvas.drawOval(
        globeRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.5, -0.55),
            radius: 0.7,
            colors: [Colors.white.withOpacity(0.08), Colors.transparent],
          ).createShader(globeRect));
    canvas.restore();

    final glowPulse = isDark ? 0.20 + math.sin(t * math.pi) * 0.15 : 0.20;

    canvas.drawCircle(
        center,
        r + 0.5,
        Paint()
          ..color = const Color(0xFF4EB3D3).withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawCircle(
        center,
        r + 2,
        Paint()
          ..color = const Color(0xFF4EB3D3).withOpacity(glowPulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    canvas.drawCircle(
        Offset(center.dx, center.dy + 20),
        r * 0.85,
        Paint()
          ..color = const Color(0xFF0A2342).withOpacity(0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
  }

  void _drawRadialPatch(
    Canvas canvas,
    Offset center,
    double r, {
    required double cx,
    required double cy,
    required double stop1,
    required Color c0,
    required Color c1,
    double? midStop,
    Color? cMid,
  }) {
    final patchCenter = Offset(
      center.dx + (cx - 0.5) * r * 2,
      center.dy + (cy - 0.5) * r * 2,
    );
    final patchRadius = stop1 * r * 2;
    final patchRect = Rect.fromCircle(center: patchCenter, radius: patchRadius);

    final List<Color> colors;
    final List<double> stops;

    if (midStop != null && cMid != null) {
      colors = [c0, cMid, c1];
      stops = [0.0, midStop / stop1, 1.0];
    } else {
      colors = [c0, c1];
      stops = [0.0, 1.0];
    }

    canvas.drawCircle(
        patchCenter,
        patchRadius,
        Paint()
          ..shader = RadialGradient(colors: colors, stops: stops)
              .createShader(patchRect));
  }

  @override
  bool shouldRepaint(EarthGlobePainter old) =>
      old.t != t || old.isDark != isDark;
}

class _ContactFormDialog extends StatefulWidget {
  @override
  State<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<_ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  bool submitted = false;

  Future<void> _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;

    final didSend = await composeContactEmail(
      recipientEmail: emailController.text.trim(),
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      senderEmail: emailController.text.trim(),
    );

    if (!mounted) return;
    if (didSend) {
      setState(() => submitted = true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to send email right now. Please try again.'),
      ),
    );
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Full name is required";
    }

    final parts = value.trim().split(" ");
    if (parts.length < 2) {
      return "Enter full name (first & last)";
    }

    final nameRegex = RegExp(r'^[a-zA-Z ]+$');
    if (!nameRegex.hasMatch(value)) {
      return "Only letters allowed";
    }

    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Phone number is required";
    }

    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return "Enter valid 10-digit number";
    }

    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Email is required";
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(value)) {
      return "Enter valid email";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF08162A).withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF4EB3D3).withOpacity(0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4EB3D3).withOpacity(0.25),
              blurRadius: 40,
              spreadRadius: 2,
            )
          ],
        ),
        child: submitted ? _successView() : _formView(),
      ),
    );
  }

  // 🎯 SUCCESS VIEW
  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF52B788), size: 60),
        const SizedBox(height: 16),
        const Text(
          "You're all set!",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Someone will get in touch with you shortly.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 24),
        _gradientButton("Close", () async {
          Navigator.pop(context);
        }),
      ],
    );
  }

  // 🎯 FORM VIEW
  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Talk to an Expert",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "We’ll reach out within 24 hours",
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          _inputField(
            "Full Name",
            nameController,
            validator: validateName,
          ),
          const SizedBox(height: 14),
          _inputField(
            "Phone Number",
            phoneController,
            keyboard: TextInputType.phone,
            validator: validatePhone,
          ),
          const SizedBox(height: 14),
          _inputField(
            "Email Address",
            emailController,
            keyboard: TextInputType.emailAddress,
            validator: validateEmail,
          ),
          const SizedBox(height: 24),
          _gradientButton("Submit", _submitContactForm),
        ],
      ),
    );
  }

  // 🎯 PREMIUM INPUT FIELD
  Widget _inputField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF4EB3D3),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // 🎯 GRADIENT BUTTON
  Widget _gradientButton(String text, Future<void> Function() onTap) {
    return GestureDetector(
      onTap: () {
        unawaited(onTap());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4EB3D3), Color(0xFF52B788)],
          ),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4EB3D3).withOpacity(0.4),
              blurRadius: 20,
            )
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
