import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/agni_colors.dart';
import '../../domain/entities/agni_content.dart';

// Main Landing Page
class AgniLandingPage extends StatefulWidget {
  final AgniContent content;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AgniLandingPage({
    super.key,
    required this.content,
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

  int _langIndex = 0;
  double _langOpacity = 1.0;
  double _langOffset = 0.0;

  Timer? _langTimer;
  List<String> get _langs => widget.content.heroLangs;

  @override
  void initState() {
    super.initState();

    _globeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

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

    _scrollController.addListener(_checkReveal);

    // Start language cycling
    _langTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cycleLang();
    });

    // Initial reveal check after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkReveal());
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

  @override
  void dispose() {
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
  Gradient get gradText => isDark ? AgniColors.gradText : AgniColors.gradTextLight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background layer
          _buildBackground(),
          // Content
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

  // ─── Background ───────────────────────────────────────────────────────────

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

  // ─── Navbar ───────────────────────────────────────────────────────────────

  Widget _buildNav() {
    final navBg = isDark
        ? const Color(0xFF030D1A).withOpacity(0.82)
        : const Color(0xFFDCEEF8).withOpacity(0.82);
    final borderColor = isDark
        ? AgniColors.darkBorder.withOpacity(0.12)
        : AgniColors.oceanMid.withOpacity(0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _gradientText('Technodysis.', GoogleFonts.playfairDisplay(
            fontSize: 24.8, fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          )),
          const Spacer(),
          Row(
            children: content.navItems.map((item) =>
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(item, style: TextStyle(
                  color: text2Color,
                  fontSize: 14.4,
                  fontWeight: FontWeight.w500,
                )),
              )
            ).toList(),
          ),
          const SizedBox(width: 36),
          _gradientButton('Contact sales →', small: true),
          const SizedBox(width: 8),
          // Theme toggle
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

  // ─── Hero ─────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Globe watermark
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
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 80),
            child: Column(
              children: [
                // Badge
                _buildHeroBadge(),
                const SizedBox(height: 32),
                // Lang ticker
                _buildLangTicker(),
                const SizedBox(height: 30),
                // Title
                _buildHeroTitle(),
                const SizedBox(height: 22),
                // Subtitle
                Text(
                  'We build agentic AI and automation that transforms Healthcare, Banking, Insurance, Telecom, and Retail — with measurable ROI from day one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: text3Color,
                    height: 1.75,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 44),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _gradientButton('Talk to an expert'),
                    const SizedBox(width: 16),
                    _ghostButton('See how it works'),
                  ],
                ),
                const SizedBox(height: 72),
                // Phone mockup
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
        boxShadow: isDark ? [
          BoxShadow(color: AgniColors.oceanBright.withOpacity(0.10), blurRadius: 20),
        ] : null,
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
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: isDark ? AgniColors.forestBright : AgniColors.forestLight,
                shape: BoxShape.circle,
                boxShadow: isDark ? [
                  BoxShadow(
                    color: AgniColors.forestBright.withOpacity(0.60),
                    blurRadius: 8,
                  ),
                ] : null,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
                child: Text(e.value, style: TextStyle(
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
          'Agentic AI + Automation',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            height: 1.06,
            letterSpacing: -2.16,
            color: textColor,
          ),
        ),
        Row(
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
      ],
    );
  }

  Widget _buildPhoneMockup() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 280,
          height: 460,
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
            boxShadow: isDark ? [
              BoxShadow(color: AgniColors.oceanBright.withOpacity(0.20), blurRadius: 80),
              BoxShadow(color: const Color(0xFF000000).withOpacity(0.40), blurRadius: 24, offset: const Offset(0, 24)),
            ] : [
              BoxShadow(color: const Color(0xFF0A2342).withOpacity(0.22), blurRadius: 80, offset: const Offset(0, 20)),
            ],
          ),
          child: Stack(
            children: [
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: LinearGradient(
                    begin: const Alignment(-0.7, -0.9),
                    end: const Alignment(1, 1),
                    colors: isDark ? [
                      AgniColors.oceanBright.withOpacity(0.06),
                      AgniColors.forestLight.withOpacity(0.05),
                    ] : [
                      const Color(0xFFB4D7EB).withOpacity(0.22),
                      const Color(0xFFB4E1C8).withOpacity(0.18),
                    ],
                  ),
                ),
              ),
              // Notch
              Positioned(
                top: 16, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: 80, height: 6,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AgniColors.oceanBright.withOpacity(0.15)
                          : AgniColors.oceanMid.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              // Center content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWaveform(),
                    const SizedBox(height: 20),
                    // Language display
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AgniColors.grad,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: AgniColors.oceanBright.withOpacity(isDark ? 0.35 : 0.28),
                            blurRadius: 20, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '● Tap to talk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Floating cards
        Positioned(
          top: 50, right: -120,
          child: _buildFloatingCard(
            content.floatingCards.isNotEmpty ? content.floatingCards[0].stat : '100K+',
            content.floatingCards.isNotEmpty ? content.floatingCards[0].label : 'Daily calls',
            content.floatingCards.isNotEmpty ? content.floatingCards[0].delayFactor : 1.0,
          ),
        ),
        Positioned(
          bottom: 90, left: -110,
          child: _buildFloatingCard(
            content.floatingCards.length > 1 ? content.floatingCards[1].stat : '\$0.03/min',
            content.floatingCards.length > 1 ? content.floatingCards[1].label : 'Total cost',
            content.floatingCards.length > 1 ? content.floatingCards[1].delayFactor : 2.2,
          ),
        ),
      ],
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
                boxShadow: isDark ? [
                  BoxShadow(
                    color: AgniColors.oceanBright.withOpacity(0.40),
                    blurRadius: 8,
                  ),
                ] : null,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFloatingCard(String stat, String label, double delayFactor) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, __) {
        final t = ((_floatController.value * (1 / 4.0)) + delayFactor / 4.0) % 1.0;
        final offset = math.sin(t * math.pi * 2) * 7;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF08162A).withOpacity(0.88)
                  : Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AgniColors.oceanBright.withOpacity(0.25)
                    : Colors.white.withOpacity(0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: AgniColors.oceanBright.withOpacity(isDark ? 0.10 : 0.08),
                  blurRadius: 48, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => gradText.createShader(bounds),
                  child: Text(stat, style: const TextStyle(
                    fontSize: 17.6,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
                ),
                Text(label, style: TextStyle(
                  fontSize: 12.8,
                  color: text2Color,
                  fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Marquee ──────────────────────────────────────────────────────────────
  // CSS: .marquee-item { padding:10px 36px; font-size:.95rem; font-weight:500;
  //        color:text2; border-right:1px solid rgba(26,74,107,.10); flex-shrink:0; }
  // CSS: @keyframes marquee { from{translateX(0)} to{translateX(-50%)} }
  // HTML has exactly 20 items (10 + 10 duplicated). Scrolling -50% = one set.

  Widget _buildMarquee() {
    final items = content.marqueeItems;
    // Exactly 20 items as in HTML
    final doubled = [...items, ...items];

    final borderColor = isDark
        ? AgniColors.oceanBright.withOpacity(0.12)
        : const Color(0xFF1A4A6B).withOpacity(0.10);

    return Container(
      // padding:44px 0
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        // background:rgba(255,255,255,.55) light / rgba(5,15,32,.70) dark
        color: isDark
            ? const Color(0xFF050F20).withOpacity(0.70)
            : Colors.white.withOpacity(0.55),
        // border-top + border-bottom
        border: Border.symmetric(
          horizontal: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // .marquee-label: font-size:.75rem=12px; letter-spacing:.12em; uppercase; mb:24px
          Text(
            'TRUSTED BY 2,100+ BUSINESSES ACROSS 12 COUNTRIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 12 * 0.12, // .12em
              color: text3Color,
            ),
          ),
          const SizedBox(height: 24),
          // Overflow hidden wrapper, marquee scrolls naturally
          SizedBox(
            height: 41, // 10px top + 10px bottom padding + ~21px text
            child: AnimatedBuilder(
              animation: _marqueeController,
              builder: (_, __) {
                return _MarqueeRow(
                  items: doubled,
                  progress: _marqueeController.value,
                  textStyle: TextStyle(
                    fontSize: 15.2,  // .95rem
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

  // ─── Stats ────────────────────────────────────────────────────────────────

  Widget _buildStats() {
    final stats = content.stats;

    return RevealWidget(
      key: _revealKeys[0],
      revealed: _revealed[0],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 100),
        child: Row(
          children: stats.map((s) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _buildStatCard(s.value, s.description),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildStatCard(String num, String desc) {
    return _GlassCard(
      isDark: isDark,
      child: Stack(
        children: [
          // Top gradient line
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: AgniColors.grad,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x804EB3D3),
                    blurRadius: 16,
                  ),
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
                  child: Text(num, style: GoogleFonts.playfairDisplay(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: Colors.white,
                  )),
                ),
                const SizedBox(height: 10),
                Text(desc, style: TextStyle(
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

  // ─── Features ─────────────────────────────────────────────────────────────

  Widget _buildFeatures() {
    final features = content.features;

    return RevealWidget(
      key: _revealKeys[1],
      revealed: _revealed[1],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 100),
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
            const SizedBox(height: 56),
            // 3-column grid
            Wrap(
              spacing: 22,
              runSpacing: 22,
              children: features.map((f) => SizedBox(
                width: (MediaQuery.of(context).size.width - 104 - 44) / 3,
                child: _buildFeatCard(f.icon, f.title, f.description, f.stat),
              )).toList(),
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
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [
                  AgniColors.oceanBright.withOpacity(0.12),
                  AgniColors.forestBright.withOpacity(0.10),
                ] : [
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
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.playfairDisplay(
            fontSize: 19.2,
            fontWeight: FontWeight.w700,
            color: textColor,
          )),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(fontSize: 14.4, color: text3Color, height: 1.65)),
          const SizedBox(height: 20),
          Text(stat, style: GoogleFonts.dmMono(
            fontSize: 12.8,
            color: isDark ? AgniColors.forestBright : AgniColors.forestMid,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  // ─── Comparison ───────────────────────────────────────────────────────────

  Widget _buildComparison() {
    final comparisons = content.comparisons;

    return RevealWidget(
      key: _revealKeys[2],
      revealed: _revealed[2],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTag('The difference'),
            const SizedBox(height: 18),
            _sectionTitle('Everyone else is fighting\nover ', 'the same market.'),
            const SizedBox(height: 56),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comparisons.isNotEmpty)
                  Expanded(child: _buildCompCard(
                    isOurs: comparisons[0].isOurs,
                    badge: comparisons[0].badge,
                    headline: comparisons[0].headline,
                    items: comparisons[0].items,
                  )),
                if (comparisons.length > 1) const SizedBox(width: 24),
                if (comparisons.length > 1)
                  Expanded(child: _buildCompCard(
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
          width: isOurs ? 1 : 1,
        ),
        boxShadow: isOurs ? [
          BoxShadow(
            color: AgniColors.oceanBright.withOpacity(isDark ? 0.20 : 0.10),
            blurRadius: 80, offset: const Offset(0, 24),
          ),
        ] : null,
      ),
      child: Stack(
        children: [
          if (isOurs) Positioned.fill(
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  gradient: isOurs ? AgniColors.grad : null,
                  color: isOurs ? null : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : AgniColors.oceanMid.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(100),
                  border: isOurs ? null : Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.10)
                        : AgniColors.oceanMid.withOpacity(0.12),
                  ),
                  boxShadow: isOurs ? [
                    BoxShadow(
                      color: AgniColors.oceanBright.withOpacity(0.30),
                      blurRadius: 20,
                    ),
                  ] : null,
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06 * 12,
                    color: isOurs ? Colors.white : text3Color,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(headline, style: GoogleFonts.playfairDisplay(
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
                              : (isDark ? const Color(0xFF334455) : const Color(0xFFBBBBBB)),
                          fontWeight: FontWeight.w700,
                          shadows: isOurs && isDark ? [
                            Shadow(color: AgniColors.forestBright.withOpacity(0.60), blurRadius: 8),
                          ] : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item, style: TextStyle(
                      fontSize: 15.2,
                      color: isOurs
                          ? Colors.white.withOpacity(0.85)
                          : (isDark ? text2Color.withOpacity(0.75) : AgniColors.lightText2),
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

  // ─── Earth Section ────────────────────────────────────────────────────────

  Widget _buildEarthSection() {
    final langPills = content.langPills;

    return RevealWidget(
      key: _revealKeys[3],
      revealed: _revealed[3],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 100),
        child: Column(
          children: [
            _sectionTag('Global delivery'),
            const SizedBox(height: 18),
            // Title: "The next billion calls\nwon't be in English." (italic gradient)
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
                  const TextSpan(text: "Built in Bangalore.\nDelivered across "),
                  WidgetSpan(
                    child: ShaderMask(
                      shaderCallback: (b) => gradText.createShader(b),
                      child: Text('the world.', style: GoogleFonts.playfairDisplay(
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
            const SizedBox(height: 56),

            // ── Earth Globe ── exact CSS radial-gradient layers
            // margin:56px auto 0; width:340px; height:340px; border-radius:50%
            // background: 5 radial-gradient layers
            // box-shadow: ring + glow + drop + inset-dark + inset-light
            // ::before: highlight spot at 28% 32%
            // ::after: drop shadow ellipse below globe
            AnimatedBuilder(
              animation: _globeController,
              builder: (_, __) => Column(
                children: [
                  CustomPaint(
                    size: const Size(340, 340),
                    painter: EarthGlobePainter(
                      t: _globeController.value,
                      isDark: isDark,
                    ),
                  ),
                  // .earth-globe::after — drop shadow ellipse
                  // width:360px; height:30px; background:rgba(10,35,66,.18); blur(20px); bottom:-40px
                  Transform.translate(
                    offset: const Offset(0, -10), // overlap slightly
                    child: Container(
                      width: 360,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(180),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A2342).withOpacity(0.18),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                        color: const Color(0xFF0A2342).withOpacity(0.18),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            // Language pills
            SizedBox(
              width: 820,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: langPills.map((p) => _buildLangPill(p.label, p.type)).toList(),
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
        boxShadow: gradient != null ? [
          BoxShadow(
            color: type == 'ocean'
                ? AgniColors.oceanBright.withOpacity(isDark ? 0.25 : 0.22)
                : AgniColors.forestLight.withOpacity(isDark ? 0.22 : 0.22),
            blurRadius: 20, offset: const Offset(0, 4),
          ),
        ] : [
          BoxShadow(
            color: AgniColors.oceanMid.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(label, style: TextStyle(
        fontSize: 14.4,
        fontWeight: FontWeight.w500,
        color: gradient != null ? Colors.white : text2Color,
      )),
    );
  }

  // ─── CTA Banner ───────────────────────────────────────────────────────────

  Widget _buildCTABanner() {
    return RevealWidget(
      key: _revealKeys[4],
      revealed: _revealed[4],
      child: Container(
        margin: const EdgeInsets.fromLTRB(52, 0, 52, 100),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF040E1C) : AgniColors.lightOceanDeep,
          gradient: isDark ? const LinearGradient(
            begin: Alignment(-1, -1),
            end: Alignment(1, 1),
            colors: [Color(0xFF040E1C), Color(0xFF071828), Color(0xFF0A2038)],
          ) : null,
          borderRadius: BorderRadius.circular(48),
          border: isDark ? Border.all(
            color: AgniColors.oceanBright.withOpacity(0.18),
          ) : null,
          boxShadow: [
            BoxShadow(
              color: AgniColors.oceanBright.withOpacity(isDark ? 0.20 : 0.10),
              blurRadius: 80, offset: const Offset(0, 24),
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
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
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
                        child: Text('No signup needed.', style: GoogleFonts.playfairDisplay(
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

  // ─── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final links = ['Technodysis', 'Nitya.AI', 'Careers', 'LinkedIn', 'Twitter', 'hello@technodysis.com'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 48),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF030A16).withOpacity(0.70)
            : Colors.white.withOpacity(0.42),
        border: Border(top: BorderSide(
          color: isDark
              ? AgniColors.oceanBright.withOpacity(0.12)
              : AgniColors.oceanMid.withOpacity(0.12),
        )),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => gradText.createShader(b),
            child: Text('Technodysis.', style: GoogleFonts.playfairDisplay(
              fontSize: 20.8, fontWeight: FontWeight.w900, color: Colors.white,
            )),
          ),
          const Spacer(),
          Row(
            children: links.map((link) => Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(link, style: TextStyle(
                fontSize: 14,
                color: text3Color,
              )),
            )).toList(),
          ),
          const Spacer(),
          Text('© 2026 Technodysis. All rights reserved.', style: TextStyle(
            fontSize: 12.8,
            color: text3Color,
          )),
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
        boxShadow: isDark ? [
          BoxShadow(color: AgniColors.oceanBright.withOpacity(0.08), blurRadius: 16),
        ] : null,
      ),
      child: Text(text.toUpperCase(), style: GoogleFonts.dmMono(
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
        Text(plain, style: GoogleFonts.playfairDisplay(
          fontSize: 48,
          fontWeight: FontWeight.w900,
          height: 1.1,
          letterSpacing: -1.44,
          color: textColor,
        )),
        ShaderMask(
          shaderCallback: (b) => gradText.createShader(b),
          child: Text(italic, style: GoogleFonts.playfairDisplay(
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
            blurRadius: isDark ? 32 : 24, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(label, style: TextStyle(
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
      child: Text(label, style: TextStyle(
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
          BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 32, offset: const Offset(0, 8)),
        ],
      ),
      child: const Text('Talk to an expert', style: TextStyle(
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
      child: Text(label, style: TextStyle(
        color: AgniColors.darkText2,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      )),
    );
  }
}

// ─── Reveal Widget ────────────────────────────────────────────────────────────

// ─── Marquee Track ────────────────────────────────────────────────────────────
// Replicates CSS @keyframes marquee { from{translateX(0)} to{translateX(-50%)} }
// Items are NOT fixed-width — they size to content + padding:10px 36px, exactly
// matching the CSS .marquee-item { padding:10px 36px; flex-shrink:0; border-right }

class _MarqueeTrack extends StatelessWidget {
  final List<String> items;
  final double progress; // 0..1 from AnimationController
  final TextStyle textStyle;
  final Color dividerColor;

  const _MarqueeTrack({
    required this.items,
    required this.progress,
    required this.textStyle,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    // Build items as IntrinsicWidth children so each is sized to text+padding
    final itemWidgets = items.map((label) => Container(
      // padding:10px 36px (top/bottom + left/right)
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      child: Text(label, style: textStyle),
    )).toList();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // We need to measure total width of all 20 items.
        // Since 20 = 10×2, -50% translation = exactly 10 items = seamless.
        // Use a custom render approach: overflow:hidden + Transform.translate
        return ClipRect(
          child: _MarqueeScroller(
            progress: progress,
            children: itemWidgets,
          ),
        );
      },
    );
  }
}

class _MarqueeScroller extends StatelessWidget {
  final double progress;
  final List<Widget> children;

  const _MarqueeScroller({required this.progress, required this.children});

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _MarqueeLayoutDelegate(),
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: double.infinity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children.map((child) => _MarqueeItem(
            progress: progress,
            child: child,
          )).toList(),
        ),
      ),
    );
  }
}

class _MarqueeItem extends StatelessWidget {
  final double progress;
  final Widget child;
  const _MarqueeItem({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _MarqueeLayoutDelegate extends SingleChildLayoutDelegate {
  @override
  bool shouldRelayout(_MarqueeLayoutDelegate old) => false;
  @override
  Size getSize(BoxConstraints constraints) =>
      Size(constraints.maxWidth, constraints.maxHeight);
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxHeight: constraints.maxHeight);
  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset.zero;
}

// Stateful marquee that measures its children and translates
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
    // Estimate item width from text metrics + padding
    // padding:10px 36px = 72px horizontal padding per item
    // We use TextPainter to measure each label
    final tp = TextPainter(textDirection: TextDirection.ltr);
    double totalHalfWidth = 0;
    for (int i = 0; i < widget.items.length ~/ 2; i++) {
      tp.text = TextSpan(text: widget.items[i], style: widget.textStyle);
      tp.layout();
      totalHalfWidth += tp.width + 72 + 1; // text + horizontal padding + border
    }

    // CSS: translateX(-50%) of the 20-item total = -totalHalfWidth
    final offset = -(widget.progress * totalHalfWidth);

    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: Offset(offset, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.items.map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: widget.dividerColor, width: 1),
                ),
              ),
              child: Text(label, style: widget.textStyle),
            )).toList(),
          ),
        ),
      ),
    );
  }
}

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
    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(baseRect, Paint()..color = const Color(0xFF030D1A));

    final blobs = [
      (size.width * 0.0, size.height * 0.0, 700.0, const Color(0xFF0E3A60), 0.55),
      (size.width - 150, size.height - 120, 600.0, const Color(0xFF1A4030), 0.45),
      (size.width * 0.38, size.height * 0.38, 500.0, const Color(0xFF0A2D4A), 0.35),
      (size.width * 0.78, size.height * 0.15, 350.0, const Color(0xFF2D6A4F), 0.25),
      (size.width * 0.05, size.height * 0.75, 280.0, const Color(0xFF4EB3D3), 0.10),
    ];

    for (final b in blobs) {
      final paint = Paint()
        ..color = b.$4.withOpacity(b.$5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(Offset(b.$1, b.$2), b.$3 / 2, paint);
    }
  }

  void _paintLight(Canvas canvas, Size size) {
    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final bgPaint = Paint()..shader = const LinearGradient(
      begin: Alignment(-0.5, -1),
      end: Alignment(0.5, 1),
      colors: [Color(0xFFDAEEF8), Color(0xFFE8F5F0), Color(0xFFD8EEE0)],
    ).createShader(baseRect);
    canvas.drawRect(baseRect, bgPaint);

    final blobs = [
      (size.width * 0.15, size.height * 0.20, 650.0, const Color(0xFF7AB8D8), 0.18),
      (size.width - 120, size.height - 100, 550.0, const Color(0xFF52B788), 0.16),
      (size.width * 0.40, size.height * 0.45, 420.0, const Color(0xFF2D7DA8), 0.12),
      (size.width * 0.90, size.height * 0.20, 300.0, const Color(0xFF74C69D), 0.14),
    ];

    for (final b in blobs) {
      final paint = Paint()
        ..color = b.$4.withOpacity(b.$5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
      canvas.drawCircle(Offset(b.$1, b.$2), b.$3 / 2, paint);
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
      // Light mode: colored radial inside circle
      final p = Paint()..color = AgniColors.oceanBright.withOpacity(0.15);
      p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(center, r, p);
    }

    // Rings
    final ringPaint = Paint()
      ..color = (isDark ? AgniColors.oceanBright : AgniColors.oceanMid).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r, ringPaint);

    final ringPaint2 = Paint()
      ..color = (isDark ? AgniColors.forestLight : AgniColors.forestMid).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r - 50, ringPaint2);

    final ringPaint3 = Paint()
      ..color = (isDark ? AgniColors.oceanBright : AgniColors.oceanMid).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r - 110, ringPaint3);
  }

  @override
  bool shouldRepaint(GlobeBgPainter old) => old.t != t || old.isDark != isDark;
}

// ─── Earth Globe Painter ──────────────────────────────────────────────────────
// Exact CSS replication (light mode):
//
// background:
//   radial-gradient(circle at 32% 38%, #4eb3d3 0%, #2d7da8 25%, transparent 55%),
//   radial-gradient(circle at 68% 58%, #52b788 0%, #2d6a4f 25%, transparent 55%),
//   radial-gradient(circle at 20% 70%, #74c69d 0%, transparent 35%),
//   radial-gradient(circle at 75% 25%, #7ab8d8 0%, transparent 35%),
//   radial-gradient(circle at 50% 50%, #1a4a6b 0%, #0a2342 100%);
//
// box-shadow:
//   0 0 0 1px rgba(78,179,211,.25),       ← thin ring
//   0 0 60px rgba(78,179,211,.20),         ← outer glow
//   0 20px 80px rgba(10,35,66,.30),        ← drop shadow
//   inset -30px -20px 60px rgba(10,35,66,.40),  ← dark side (bottom-right)
//   inset 20px 15px 40px rgba(255,255,255,.08);  ← light highlight (top-left)
//
// ::before: radial-gradient(circle at 28% 32%, rgba(255,255,255,.15) 0%, transparent 30%)
// animation: globeSpin 20s ease-in-out infinite alternate
//   → shift background-position, simulate continent drift
//
// Dark mode adds stronger glow: globePulse animation varies box-shadow intensity

class EarthGlobePainter extends CustomPainter {
  final double t; // 0..1 from AnimationController (globeController, 8s reverse)
  final bool isDark;

  EarthGlobePainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final globeRect = Rect.fromCircle(center: center, radius: r);

    // globeSpin: 20s ease-in-out infinite alternate — shifts continent positions slightly
    // We simulate by offsetting patch centers slightly over time
    final spinOffset = math.sin(t * math.pi) * 0.04; // ±4% drift

    // ── 1. Clip everything to the circle ──────────────────────────────────
    final clipPath = Path()..addOval(globeRect);
    canvas.save();
    canvas.clipPath(clipPath);

    // ── 2. Base layer: radial(50%50%, #1a4a6b → #0a2342) ─────────────────
    // This is the deepest ocean base
    final basePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: const [Color(0xFF1A4A6B), Color(0xFF0A2342)],
      ).createShader(globeRect);
    canvas.drawOval(globeRect, basePaint);

    // ── 3. Continent patch: radial(75% 25%, #7ab8d8 → transparent 35%) ───
    // Top-right blue water highlight
    _drawRadialPatch(canvas, center, r,
      cx: 0.75 + spinOffset, cy: 0.25,
      stop0: 0.0, stop1: 0.35,
      c0: const Color(0xFF7AB8D8), c1: Colors.transparent,
    );

    // ── 4. Continent patch: radial(20% 70%, #74c69d → transparent 35%) ───
    // Bottom-left forest green
    _drawRadialPatch(canvas, center, r,
      cx: 0.20 - spinOffset, cy: 0.70,
      stop0: 0.0, stop1: 0.35,
      c0: const Color(0xFF74C69D), c1: Colors.transparent,
    );

    // ── 5. Continent patch: radial(68% 58%, #52b788 → #2d6a4f 25%, transp 55%) ─
    // Center-right green landmass
    _drawRadialPatch(canvas, center, r,
      cx: 0.68 + spinOffset * 0.5, cy: 0.58,
      stop0: 0.0, midStop: 0.25, stop1: 0.55,
      c0: const Color(0xFF52B788), cMid: const Color(0xFF2D6A4F), c1: Colors.transparent,
    );

    // ── 6. Continent patch: radial(32% 38%, #4eb3d3 → #2d7da8 25%, transp 55%) ─
    // Top-left ocean blue (painted last = frontmost in CSS stacking = first in CSS list)
    _drawRadialPatch(canvas, center, r,
      cx: 0.32 - spinOffset * 0.5, cy: 0.38,
      stop0: 0.0, midStop: 0.25, stop1: 0.55,
      c0: const Color(0xFF4EB3D3), cMid: const Color(0xFF2D7DA8), c1: Colors.transparent,
    );

    // ── 7. ::before highlight: radial(28% 32%, rgba(255,255,255,.15) → transp 30%) ─
    _drawRadialPatch(canvas, center, r,
      cx: 0.28, cy: 0.32,
      stop0: 0.0, stop1: 0.30,
      c0: Colors.white.withOpacity(0.15), c1: Colors.transparent,
    );

    canvas.restore(); // end clip

    // ── 8. Inset shadows (simulated as overlays inside clip) ───────────────
    // inset -30px -20px 60px rgba(10,35,66,.40) → dark bottom-right
    // inset 20px 15px 40px rgba(255,255,255,.08) → light top-left
    canvas.save();
    canvas.clipPath(clipPath);

    // Dark side: bottom-right
    final darkInset = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, 0.75),
        radius: 0.9,
        colors: [
          const Color(0xFF0A2342).withOpacity(0.40),
          Colors.transparent,
        ],
      ).createShader(globeRect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawOval(globeRect, darkInset);

    // Light side: top-left
    final lightInset = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.55),
        radius: 0.7,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(globeRect);
    canvas.drawOval(globeRect, lightInset);

    canvas.restore();

    // ── 9. Outer glow & ring (box-shadow) ─────────────────────────────────
    // Dark mode pulses: globePulse 8s ease-in-out infinite
    final glowPulse = isDark
        ? 0.20 + math.sin(t * math.pi) * 0.15  // 0.20→0.35
        : 0.20;

    // box-shadow: 0 0 0 1px rgba(78,179,211,.25)  ← 1px ring
    final ringPaint = Paint()
      ..color = const Color(0xFF4EB3D3).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, r + 0.5, ringPaint);

    // box-shadow: 0 0 60px rgba(78,179,211,.20)  ← soft outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF4EB3D3).withOpacity(glowPulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, r + 2, glowPaint);

    // box-shadow: 0 20px 80px rgba(10,35,66,.30)  ← drop shadow
    // Drawn as a downward-offset blurred circle
    final dropPaint = Paint()
      ..color = const Color(0xFF0A2342).withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(center.dx, center.dy + 20), r * 0.85, dropPaint);
  }

  /// Draw a radial gradient patch anchored at (cx*diameter, cy*diameter) relative to globe top-left.
  /// Supports 2-stop or 3-stop gradients matching CSS radial-gradient(circle at X% Y%, c0 s0, [cMid sMid,] c1 s1)
  void _drawRadialPatch(
    Canvas canvas, Offset center, double r, {
    required double cx, required double cy,
    required double stop0, required double stop1,
    required Color c0, required Color c1,
    double? midStop, Color? cMid,
  }) {
    // Center of this patch in canvas coordinates
    final patchCenter = Offset(
      center.dx + (cx - 0.5) * r * 2,
      center.dy + (cy - 0.5) * r * 2,
    );
    // Radius of patch = stop1 * globe diameter
    final patchRadius = stop1 * r * 2;
    final patchRect = Rect.fromCircle(center: patchCenter, radius: patchRadius);

    final List<Color> colors;
    final List<double> stops;

    if (midStop != null && cMid != null) {
      colors = [c0, cMid, c1];
      stops = [stop0, midStop / stop1, 1.0];
    } else {
      colors = [c0, c1];
      stops = [stop0, 1.0];
    }

    final paint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: stops,
      ).createShader(patchRect);

    canvas.drawCircle(patchCenter, patchRadius, paint);
  }

  @override
  bool shouldRepaint(EarthGlobePainter old) => old.t != t || old.isDark != isDark;
}
