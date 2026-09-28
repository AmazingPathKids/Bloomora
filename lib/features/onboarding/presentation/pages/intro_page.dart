import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IntroPage
// ─────────────────────────────────────────────────────────────────────────────

class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({super.key});

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // 6-second background gradient cycle
  late final AnimationController _bgController;

  // 3-second float loop for slide 1 cards
  late final AnimationController _floatController;

  // Slide 1 card entry (700ms total, 3 cards staggered 150ms × 400ms each)
  late final AnimationController _slide1Entry;

  // Bar chart grow animation for slide 3
  late final AnimationController _barController;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _slide1Entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _barController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1020), // 8 bars × 60ms stagger + 600ms
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slide1Entry.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    _floatController.dispose();
    _slide1Entry.dispose();
    _barController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    if (index == 0) _slide1Entry.forward(from: 0);
    if (index == 2) _barController.forward(from: 0);
  }

  // ── Navigation — untouched ────────────────────────────────────────────────
  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToSignup();
    }
  }

  void _skipIntro() => _goToSignup();
  void _goToSignup() => context.go(AppRoutes.signUp);
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = ref.watch(activeColorSchemeProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── Layer 1: animated gradient background ─────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) {
              final t = _bgController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(scheme.background,
                          scheme.primary.withValues(alpha: 0.12), t)!,
                      Color.lerp(scheme.primary.withValues(alpha: 0.12),
                          scheme.accent.withValues(alpha: 0.08), t)!,
                      Color.lerp(scheme.accent.withValues(alpha: 0.08),
                          scheme.background, 1 - t)!,
                      scheme.background,
                    ],
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              );
            },
          ),

          // ── Layer 2: slides ───────────────────────────────────────────────
          SafeArea(
            child: Stack(
              children: [
                PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _Slide1(
                      scheme: scheme,
                      floatCtrl: _floatController,
                      entryCtrl: _slide1Entry,
                      currentPage: _currentPage,
                      onNext: _nextPage,
                      onSignIn: () => context.go(AppRoutes.signIn),
                    ),
                    _Slide2(
                      scheme: scheme,
                      currentPage: _currentPage,
                      onNext: _nextPage,
                      onSignIn: () => context.go(AppRoutes.signIn),
                    ),
                    _Slide3(
                      scheme: scheme,
                      barCtrl: _barController,
                      currentPage: _currentPage,
                      onNext: _nextPage,
                      onSignIn: () => context.go(AppRoutes.signIn),
                    ),
                  ],
                ),

                // Skip — slides 1 & 2 only
                if (_currentPage < 2)
                  Positioned(
                    top: 8,
                    right: 16,
                    child: GestureDetector(
                      onTap: _skipIntro,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.20),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: scheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 1 — "See Your Child Clearly"
// ─────────────────────────────────────────────────────────────────────────────

class _Slide1 extends StatelessWidget {
  final AppColorScheme scheme;
  final AnimationController floatCtrl;
  final AnimationController entryCtrl;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSignIn;

  const _Slide1({
    required this.scheme,
    required this.floatCtrl,
    required this.entryCtrl,
    required this.currentPage,
    required this.onNext,
    required this.onSignIn,
  });

  // Entry intervals: card i starts at i*150ms, lasts 400ms, total 700ms
  Animation<double> _entryFade(int i) => CurvedAnimation(
        parent: entryCtrl,
        curve: Interval(i * 150 / 700, (i * 150 + 400) / 700,
            curve: Curves.easeOut),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        // ── Top 55%: illustration ─────────────────────────────────────────
        Expanded(
          flex: 55,
          child: AnimatedBuilder(
            animation: Listenable.merge([floatCtrl, entryCtrl]),
            builder: (_, __) {
              final card1Float = math.sin(floatCtrl.value * 2 * math.pi) * 8;
              final card2Float =
                  math.sin(floatCtrl.value * 2 * math.pi + math.pi / 3) * 8;
              final card3Float =
                  math.sin(floatCtrl.value * 2 * math.pi + 2 * math.pi / 3) * 8;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Card 1 — center-left, primary card (renders first = behind)
                  Positioned(
                    left: 24,
                    top: size.height * 0.15,
                    child: _entryWrap(
                      fade: _entryFade(0),
                      enter: const Offset(0, 30),
                      floatY: card1Float,
                      rotation: -5,
                      scale: 1.0,
                      child: _CognitiveCard(
                          scheme: scheme, width: size.width * 0.65),
                    ),
                  ),

                  // Card 3 — bottom left (renders second)
                  Positioned(
                    right: 85,
                    top: size.height * 0.32,
                    child: _entryWrap(
                      fade: _entryFade(2),
                      enter: const Offset(-30, 0),
                      floatY: card3Float,
                      rotation: 4,
                      scale: 1.0,
                      child:
                          _StreakCard(scheme: scheme, width: size.width * 0.52),
                    ),
                  ),

                  // Card 2 — top right (renders last = front)
                  Positioned(
                    right: 8,
                    top: size.height * 0.08,
                    child: _entryWrap(
                      fade: _entryFade(1),
                      enter: const Offset(30, 0),
                      floatY: card2Float,
                      rotation: 8,
                      scale: 1.0,
                      child:
                          _CommCard(scheme: scheme, width: size.width * 0.55),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // ── Bottom 45%: content card ──────────────────────────────────────
        Expanded(
          flex: 45,
          child: _ContentCard(
            scheme: scheme,
            title: 'See Your Child Clearly',
            subtitle: 'A structured assessment across 8 developmental domains, '
                'designed for parents — not clinicians.',
            currentPage: currentPage,
            totalPages: 3,
            onNext: onNext,
            onSignIn: onSignIn,
          ),
        ),
      ],
    );
  }

  Widget _entryWrap({
    required Animation<double> fade,
    required Offset enter,
    required double floatY,
    required double rotation,
    required double scale,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(enter.dx / 400, enter.dy / 400),
          end: Offset.zero,
        ).animate(fade),
        child: Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Slide 1 illustration cards ────────────────────────────────────────────────

class _CognitiveCard extends StatelessWidget {
  final AppColorScheme scheme;
  final double width;
  const _CognitiveCard({required this.scheme, this.width = 170});

  @override
  Widget build(BuildContext context) {
    return _GlassIllustrationCard(
      scheme: scheme,
      width: width,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Cognitive',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          Text('78%',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: scheme.textPrimary)),
          const SizedBox(height: 8),
          _SmallChip(label: 'On Track', color: AppColors.success),
        ],
      ),
    );
  }
}

class _CommCard extends StatelessWidget {
  final AppColorScheme scheme;
  final double width;
  const _CommCard({required this.scheme, this.width = 160});

  @override
  Widget build(BuildContext context) {
    return _GlassIllustrationCard(
      scheme: scheme,
      width: width,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Communication',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.60,
              backgroundColor: scheme.textMuted.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primaryLight),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          _SmallChip(label: 'Developing', color: AppColors.warning),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final AppColorScheme scheme;
  final double width;
  const _StreakCard({required this.scheme, this.width = 155});

  @override
  Widget build(BuildContext context) {
    return _GlassIllustrationCard(
      scheme: scheme,
      width: width,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today\'s Streak 🔥',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.textSecondary)),
          const SizedBox(height: 6),
          Text('7 days',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: scheme.textPrimary)),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (i) {
              final filled = i < 5;
              return Container(
                margin: const EdgeInsets.only(right: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? scheme.primary
                      : scheme.textMuted.withValues(alpha: 0.25),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 2 — "Know What To Do Next"
// ─────────────────────────────────────────────────────────────────────────────

class _Slide2 extends StatelessWidget {
  final AppColorScheme scheme;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSignIn;

  const _Slide2({
    required this.scheme,
    required this.currentPage,
    required this.onNext,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.72;

    return Column(
      children: [
        Expanded(
          flex: 55,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Back card — offset right + down, rotated +6°, 85% opacity
              Transform.translate(
                offset: const Offset(20, 16),
                child: Transform.rotate(
                  angle: 6 * math.pi / 180,
                  child: Opacity(
                    opacity: 0.85,
                    child: _GlassIllustrationCard(
                      scheme: scheme,
                      width: cardWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SmallChip(
                              label: 'Fine Motor', color: scheme.primary),
                          const SizedBox(height: 10),
                          Text(
                            'Threading Beads',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SmallChip(
                              label: '12 min', color: scheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Front card — centered, rotated -3°, full opacity
              Transform.rotate(
                angle: -3 * math.pi / 180,
                child: _GlassIllustrationCard(
                  scheme: scheme,
                  width: cardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SmallChip(label: 'Communication', color: scheme.primary),
                      const SizedBox(height: 10),
                      Text(
                        'Name That Object',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. Hold up a familiar object...',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SmallChip(
                              label: '10 min', color: scheme.textSecondary),
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 0),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                'Start',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 45,
          child: _ContentCard(
            scheme: scheme,
            title: 'Know What To Do Next',
            subtitle: 'Daily activities personalized to your child\'s age, '
                'profile, and focus areas.',
            currentPage: currentPage,
            totalPages: 3,
            onNext: onNext,
            onSignIn: onSignIn,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide 3 — "Track Real Progress"
// ─────────────────────────────────────────────────────────────────────────────

class _Slide3 extends StatelessWidget {
  final AppColorScheme scheme;
  final AnimationController barCtrl;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSignIn;

  const _Slide3({
    required this.scheme,
    required this.barCtrl,
    required this.currentPage,
    required this.onNext,
    required this.onSignIn,
  });

  static const _labels = [
    'ATT',
    'COG',
    'DAL',
    'FIN',
    'GRS',
    'SEN',
    'SOC',
    'COM'
  ];
  static const _values = [78, 45, 62, 55, 80, 38, 70, 60];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 55,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Assessment',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedBuilder(
                    animation: barCtrl,
                    builder: (_, __) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(_labels.length, (i) {
                          // Stagger: bar i starts at i*60ms / totalDuration
                          final start = (i * 60) / 1020;
                          final end = (i * 60 + 600) / 1020;
                          final t = CurvedAnimation(
                            parent: barCtrl,
                            curve: Interval(start, end, curve: Curves.easeOut),
                          ).value;
                          final pct = _values[i] / 100;

                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor: pct * t,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(4),
                                              topRight: Radius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _labels[i],
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: scheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 45,
          child: _ContentCard(
            scheme: scheme,
            title: 'Track Real Progress',
            subtitle: 'Watch your child grow across every domain. '
                'Share progress reports with therapists.',
            currentPage: currentPage,
            totalPages: 3,
            onNext: onNext,
            onSignIn: onSignIn,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────���──
// Shared: bottom content card
// ─────────────────────────────────────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  final AppColorScheme scheme;
  final String title;
  final String subtitle;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSignIn;

  const _ContentCard({
    required this.scheme,
    required this.title,
    required this.subtitle,
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.glassBase,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.glassBorder, width: 1.0),
            ),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: scheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: scheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                // Dots + Next button row
                Row(
                  children: [
                    // Page dots
                    Row(
                      children: List.generate(totalPages, (i) {
                        final active = i == currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: active ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? scheme.primary
                                : scheme.textMuted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    // Next / Get Started button
                    GestureDetector(
                      onTap: onNext,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            currentPage == totalPages - 1
                                ? 'Get Started'
                                : 'Next',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Sign in link
                GestureDetector(
                  onTap: onSignIn,
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.textMuted,
                            ),
                          ),
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable primitives
// ─────────────────────────────────────────────────────────────────────────────

/// A glass card used inside illustrations (not the bottom content card).
class _GlassIllustrationCard extends StatelessWidget {
  final AppColorScheme scheme;
  final Widget child;
  final double width;
  final EdgeInsets padding;

  const _GlassIllustrationCard({
    required this.scheme,
    required this.child,
    this.width = 160,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width == double.infinity ? null : width,
          decoration: BoxDecoration(
            color: scheme.glassBase,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.glassBorder, width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Small rounded pill chip.
class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
