import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/cards/glass_card.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../data/question_bank.dart';
import '../providers/questionnaire_provider.dart';

class LoadingAnalysisPage extends ConsumerStatefulWidget {
  const LoadingAnalysisPage({super.key});

  @override
  ConsumerState<LoadingAnalysisPage> createState() =>
      _LoadingAnalysisPageState();
}

class _LoadingAnalysisPageState extends ConsumerState<LoadingAnalysisPage>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _dotsCtrl;
  late final AnimationController _logoCtrl;
  late final Animation<double> _progressAnim;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _domainTimer;
  Timer? _quoteTimer;

  // ── State ─────────────────────────────────────────────────────────────────
  int _currentDomainIndex = 0;
  int _currentQuoteIndex = 0;
  bool _isComplete = false;

  // ── Domain data ───────────────────────────────────────────────────────────
  static const _domains = [
    ('Attention & Play',   Icons.sports_esports_outlined),
    ('Cognitive',          Icons.psychology_outlined),
    ('Daily Living',       Icons.home_outlined),
    ('Fine Motor',         Icons.back_hand_outlined),
    ('Gross Motor',        Icons.directions_run_outlined),
    ('Sensory',            Icons.sensors_outlined),
    ('Social & Emotional', Icons.favorite_outline),
    ('Communication',      Icons.chat_bubble_outline),
  ];

  // ── Quotes ────────────────────────────────────────────────────────────────
  static const List<String> _quotes = [
    "Every child blooms at their own pace — and every bloom is beautiful.",
    "You noticed. You showed up. That's already the most important step.",
    "Progress isn't always visible, but it's always happening.",
    "The fact that you're here means your child has an incredible advocate.",
    "Small steps taken consistently lead to remarkable journeys.",
    "Your child's potential is not defined by a timeline.",
    "Love and attention are the most powerful developmental tools.",
    "Every 'not yet' is just a 'not yet' — not a never.",
    "You are doing better than you think you are.",
    "Understanding your child is the foundation of helping them thrive.",
    "Patience, consistency, and love — you already have what matters most.",
    "Today's effort is tomorrow's breakthrough.",
    "Every child has a unique story. You're helping write a beautiful one.",
    "The journey of a thousand milestones begins with a single step.",
    "Your presence in your child's life is their greatest advantage.",
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOut,
    );
    _progressCtrl.forward();
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _domainTimer?.cancel();
        setState(() => _isComplete = true);
      }
    });

    _domainTimer = Timer.periodic(const Duration(milliseconds: 1250), (_) {
      if (mounted) {
        setState(() {
          _currentDomainIndex = (_currentDomainIndex + 1) % _domains.length;
        });
      }
    });

    _quoteTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
        });
      }
    });

    // Trigger assessment save in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveAssessmentData();
    });
  }

  Future<void> _saveAssessmentData() async {
    try {
      final child = ref.read(childNotifierProvider);
      if (child == null) return;

      final ageGroup = child.ageGroup;
      final regularQuestions = QuestionBank.domainOrder
          .take(7)
          .expand((d) => QuestionBank.regularQuestions(ageGroup, d))
          .toList();

      final commSlots = ref.read(questionnaireNotifierProvider).commSlots;

      await ref
          .read(questionnaireNotifierProvider.notifier)
          .saveAssessment(
            regularQuestions: regularQuestions,
            commSlots: commSlots,
          );
    } catch (e) {
      // Silent fail — don't interrupt the UX
      debugPrint('Assessment save error: $e');
    }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _progressCtrl.dispose();
    _dotsCtrl.dispose();
    _logoCtrl.dispose();
    _domainTimer?.cancel();
    _quoteTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = ref.watch(activeColorSchemeProvider);

    return Scaffold(
      backgroundColor: scheme.background,
      body: Stack(
        children: [
          // ── Animated gradient background (same as auth_page) ───────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) {
              final t = _bgCtrl.value;
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

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildHeader(scheme),
                const SizedBox(height: 40),
                _buildCarousel(scheme),
                const SizedBox(height: 32),
                _buildProgressSection(scheme),
                const SizedBox(height: 24),
                _buildQuoteCard(scheme),
                const Spacer(),
                _buildCompletionButton(scheme),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppColorScheme scheme) {
    return Column(
      children: [
        _buildBloomLogo(scheme),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _isComplete ? 'Analysis Complete! 🎉' : "Analyzing Your Child's Profile",
            key: ValueKey(_isComplete),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: scheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _isComplete ? "Your child's profile is ready" : 'This takes just a moment',
            key: ValueKey(_isComplete),
            style: TextStyle(fontSize: 14, color: scheme.textMuted),
          ),
        ),
      ],
    );
  }

  // ── Bloom logo ─────────────────────────────────────────────────────────────

  Widget _buildBloomLogo(AppColorScheme scheme) {
    return AnimatedBuilder(
      animation: _logoCtrl,
      builder: (_, __) {
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 6; i++)
                Transform.translate(
                  offset: Offset(
                    16 * math.cos(
                        (i * 60 - 90 + _logoCtrl.value * 360) * math.pi / 180),
                    16 * math.sin(
                        (i * 60 - 90 + _logoCtrl.value * 360) * math.pi / 180),
                  ),
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: scheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Domain carousel ────────────────────────────────────────────────────────

  Widget _buildCarousel(AppColorScheme scheme) {
    final (String domainName, IconData domainIcon) = _domains[_currentDomainIndex];
    final width = MediaQuery.of(context).size.width * 0.75;

    return SizedBox(
      width: width,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _isComplete
            ? GlassCard(
                key: const ValueKey('complete'),
                borderRadius: 20,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All domains analyzed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '8 of 8 complete',
                      style: TextStyle(fontSize: 13, color: scheme.textMuted),
                    ),
                  ],
                ),
              )
            : GlassCard(
                key: ValueKey(_currentDomainIndex),
                borderRadius: 20,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(domainIcon, color: scheme.primary, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      domainName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyzing...',
                      style: TextStyle(fontSize: 13, color: scheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    _buildDotsAnimation(scheme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDotsAnimation(AppColorScheme scheme) {
    return AnimatedBuilder(
      animation: _dotsCtrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_dotsCtrl.value - i / 3.0) % 1.0);
            final opacity = (1.0 - (phase * 2 - 1).abs()).clamp(0.3, 1.0);
            return Padding(
              padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Progress section ───────────────────────────────────────────────────────

  Widget _buildProgressSection(AppColorScheme scheme) {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (_, __) {
        final pct = (_progressAnim.value * 100).round();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isComplete ? 'Analysis complete' : 'Processing results...',
                    style: TextStyle(fontSize: 12, color: scheme.textMuted),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressAnim.value,
                  minHeight: 8,
                  backgroundColor: scheme.primary.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Quote card ─────────────────────────────────────────────────────────────

  Widget _buildQuoteCard(AppColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: Column(
            key: ValueKey(_currentQuoteIndex),
            children: [
              Text(
                '"',
                style: TextStyle(
                  fontSize: 32,
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  height: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _quotes[_currentQuoteIndex],
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.textPrimary,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Completion button ──────────────────────────────────────────────────────

  Widget _buildCompletionButton(AppColorScheme scheme) {
    return AnimatedSlide(
      offset: _isComplete ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _isComplete ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: GestureDetector(
            onTap: () => context.go(AppRoutes.onboardingPriorities),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(28),
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
                  'View Results',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}