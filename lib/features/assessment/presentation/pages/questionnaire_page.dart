import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_components.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../data/question_bank.dart';
import '../../domain/models/comm_slot_state.dart';
import '../providers/questionnaire_provider.dart';

class QuestionnairePage extends ConsumerStatefulWidget {
  const QuestionnairePage({super.key});

  @override
  ConsumerState<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends ConsumerState<QuestionnairePage>
    with TickerProviderStateMixin {
  // ── Core state — untouched ─────────────────────────────────────────────────
  late final TabController _tabController;
  late List<CommSlotState> _commSlots;
  late String _ageGroup;
  bool _commDialogShown = false;
  int _currentTabIndex = 0;

  // ── Visual state ───────────────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  final ScrollController _tabScrollController = ScrollController();
  bool _allCompleteDialogShown = false;

  // ── Domain short names for pill tabs ──────────────────────────────────────
  static const _domainShortNames = <String>[
    'ATT',
    'COG',
    'DAL',
    'FIN',
    'GRS',
    'SEN',
    'SOC',
    'COM',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final child = ref.read(childNotifierProvider);
    _ageGroup = child?.ageGroup.isNotEmpty == true
        ? child!.ageGroup
        : (child?.ageGroupFromBirthDate ?? '1-2');
    _commSlots = QuestionBank.initialCommSlots(_ageGroup);
    _tabController = TabController(
      length: QuestionBank.domainOrder.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowIntroDialog());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _bgCtrl.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIC — preserved verbatim
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _maybeShowIntroDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('hasSeenAssessmentIntro') ?? false;
    if (seen || !mounted) return;
    await prefs.setBool('hasSeenAssessmentIntro', true);
    if (!mounted) return;
    final scheme = ref.read(activeColorSchemeProvider);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AssessmentIntroDialog(scheme: scheme),
    );
  }

  void _onTabChanged() {
    final newIndex = _tabController.index;
    if (newIndex != _currentTabIndex) {
      setState(() {
        _currentTabIndex = newIndex;
      });
      if (newIndex == QuestionBank.domainOrder.length - 1 &&
          !_commDialogShown) {
        _commDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCommDialog();
        });
      }
    }
  }

  void _showCommDialog() {
    final scheme = ref.read(activeColorSchemeProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.domainCommunication,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Communication Questions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Some questions here have a follow-up.\n\n'
          'If your child doesn\'t do something yet (you select "No"), '
          'we\'ll show you a simpler version of the same question — '
          'this helps us understand exactly where your child is right now.\n\n'
          'Just keep answering — the app handles the rest!',
          style: TextStyle(
              fontSize: 14, height: 1.6, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _onCommScore(int slotIndex, int score) {
    setState(() {
      final newSlots = List<CommSlotState>.from(_commSlots);
      newSlots[slotIndex] = newSlots[slotIndex].withScore(
        newSlots[slotIndex].activeLevel,
        score,
      );
      _commSlots = newSlots;
    });
  }

  bool _isDomainComplete(String domain, Map<String, int> responses) {
    final questions = QuestionBank.regularQuestions(_ageGroup, domain);
    return questions.isNotEmpty &&
        questions.every((q) => responses.containsKey(q.id));
  }

  bool _isTabComplete(int tabIndex, Map<String, int> responses) {
    if (tabIndex == QuestionBank.domainOrder.length - 1) {
      return _commSlots.every((s) => s.isComplete);
    }
    return _isDomainComplete(QuestionBank.domainOrder[tabIndex], responses);
  }

  void _goToPreviousTab() {
    if (_currentTabIndex > 0) {
      _tabController.animateTo(_currentTabIndex - 1);
    } else {
      context.go(AppRoutes.onboardingChildProfile);
    }
  }

  void _onTabTapped(int index, Map<String, int> responses) {
    if (index <= _currentTabIndex) {
      _tabController.animateTo(index);
      return;
    }
    final allPriorComplete = List.generate(index, (i) => i)
        .every((i) => _isTabComplete(i, responses));
    if (allPriorComplete) {
      _tabController.animateTo(index);
    }
  }

  Future<void> _startAnalysis() async {
    // Sync comm slots to provider before navigating
    ref.read(questionnaireNotifierProvider.notifier).syncCommSlots(_commSlots);

    final regularQuestions = QuestionBank.domainOrder
        .take(7)
        .expand((d) => QuestionBank.regularQuestions(_ageGroup, d))
        .toList();
    try {
      await ref.read(questionnaireNotifierProvider.notifier).completeAssessment(
            regularQuestions: regularQuestions,
            commSlots: _commSlots,
          );
      if (!mounted) return;
      Navigator.of(context).pop(); // close dialog
      context.go(AppRoutes.onboardingAssessmentAnalyzing); // ignore: use_build_context_synchronously
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing assessment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  int _totalAnswered(Map<String, int> responses) {
    final regularCount = responses.length.clamp(0, 35);
    final commCount = _commSlots.where((s) => s.isComplete).length;
    return regularCount + commCount;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = ref.watch(activeColorSchemeProvider);
    final qState = ref.watch(questionnaireNotifierProvider);
    final responses = qState.responses;

    final totalAnswered = _totalAnswered(responses);
    final allComplete = totalAnswered >= 40;

    // Show final completion dialog once
    if (allComplete && !_allCompleteDialogShown) {
      _allCompleteDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _AllCompleteDialog(
              scheme: scheme,
              isLoading: qState.isLoading,
              onViewResults: _startAnalysis,
            ),
          );
        }
      });
    }

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
            bottom: false,
            child: Column(
              children: [
                _buildCustomAppBar(scheme, responses),
                const SizedBox(height: 4),
                _buildDomainTabRow(scheme, responses),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildQuestionList(scheme, responses),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Custom app bar ─────────────────────────────────────────────────────────

  Widget _buildCustomAppBar(AppColorScheme scheme, Map<String, int> responses) {
    final domainName = QuestionBank.domainOrder[_currentTabIndex];
    final isComm = _currentTabIndex == QuestionBank.domainOrder.length - 1;
    final total = isComm ? _commSlots.length : 5;
    final answered = isComm
        ? _commSlots.where((s) => s.isComplete).length
        : QuestionBank.regularQuestions(_ageGroup, domainName)
            .where((q) => responses.containsKey(q.id))
            .length;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button — plain, no circle
            IconButton(
              onPressed: _goToPreviousTab,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: scheme.textPrimary,
              ),
              padding: const EdgeInsets.all(8),
            ),
            // Domain name
            Expanded(
              child: Text(
                domainName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Progress info
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Q $answered of $total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    'Domain ${_currentTabIndex + 1} of ${QuestionBank.domainOrder.length}',
                    style: TextStyle(fontSize: 11, color: scheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Domain tab row — pill style ────────────────────────────────────────────

  Widget _buildDomainTabRow(AppColorScheme scheme, Map<String, int> responses) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: QuestionBank.domainOrder.length,
        itemBuilder: (context, i) {
          final isActive = i == _currentTabIndex;
          final isComplete = _isTabComplete(i, responses);
          final shortName = _domainShortNames[i];

          return GestureDetector(
            onTap: () => _onTabTapped(i, responses),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              constraints: const BoxConstraints(minWidth: 48),
              decoration: BoxDecoration(
                color: isActive ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  shortName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? scheme.onPrimary
                        : isComplete
                            ? scheme.primary
                            : scheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Question list ──────────────────────────────────────────────────────────

  Widget _buildQuestionList(AppColorScheme scheme, Map<String, int> responses) {
    final isComm = _currentTabIndex == QuestionBank.domainOrder.length - 1;
    final domain = QuestionBank.domainOrder[_currentTabIndex];
    final totalAnswered = _totalAnswered(responses);
    final progressHeader = _buildProgressHeader(scheme, totalAnswered);

    if (isComm) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          progressHeader,
          ..._commSlots.asMap().entries.map((e) {
            final i = e.key;
            final slot = e.value;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, i < _commSlots.length - 1 ? 10 : 0),
              child: _CommQuestionCard(
                scheme: scheme,
                slot: slot,
                slotNumber: i + 1,
                onScore: (score) {
                  _onCommScore(i, score);
                  _checkCommDomainComplete();
                },
              ),
            );
          }),
        ],
      );
    }

    final questions = QuestionBank.regularQuestions(_ageGroup, domain);
    if (questions.isEmpty) {
      return Center(
        child: Text(
          'No questions for this age group.',
          style: TextStyle(color: scheme.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        progressHeader,
        ...questions.asMap().entries.map((e) {
          final i = e.key;
          final q = e.value;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, i < questions.length - 1 ? 10 : 0),
            child: _RegularQuestionCard(
              scheme: scheme,
              questionNumber: i + 1,
              questionText: q.questionText,
              selectedScore: responses[q.id],
              onScore: (score) {
                ref
                    .read(questionnaireNotifierProvider.notifier)
                    .answerQuestion(q.id, score);
                _checkRegularDomainComplete(q.id, score, responses);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProgressHeader(AppColorScheme scheme, int totalAnswered) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: scheme.textSecondary,
                ),
              ),
              Text(
                '$totalAnswered / 40',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (totalAnswered / 40.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: scheme.primary.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Auto-advance on domain completion ──────────────────────────────────────

  void _checkRegularDomainComplete(
      String answeredId, int score, Map<String, int> prevResponses) {
    final domain = QuestionBank.domainOrder[_currentTabIndex];
    final questions = QuestionBank.regularQuestions(_ageGroup, domain);
    // Build the updated response map (provider update is async, check locally)
    final updated = {...prevResponses, answeredId: score};
    final complete = questions.every((q) => updated.containsKey(q.id));
    if (!complete) return;
    _scheduleAdvance();
  }

  void _checkCommDomainComplete() {
    // _commSlots is updated synchronously in _onCommScore via setState,
    // so check after the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_commSlots.every((s) => s.isComplete)) {
        _scheduleAdvance();
      }
    });
  }

  void _scheduleAdvance() {
    final tabIndex = _currentTabIndex;
    final isLast = tabIndex == QuestionBank.domainOrder.length - 1;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (isLast) {
        // Last domain — show completion dialog (already handled in build)
        // Force rebuild to trigger the dialog check
        setState(() {});
      } else {
        final nextIndex = tabIndex + 1;
        _tabController.animateTo(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        // Scroll the pill tab row to show the new active tab
        final offset = nextIndex * 88.0; // approx pill width + margins
        if (_tabScrollController.hasClients) {
          _tabScrollController.animateTo(
            offset.clamp(0.0, _tabScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }
}

// ─── Shared card shell ────────────────────────────────────────────────────────

Widget _questionCardShell({
  required AppColorScheme scheme,
  required Widget child,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.isDark
              ? scheme.glassBase
              : scheme.surface.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.glassBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: child,
      ),
    ),
  );
}

// ─── Q number chip ────────────────────────────────────────────────────────────

Widget _qChip(AppColorScheme scheme, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: scheme.primary,
      ),
    ),
  );
}

// ─── Regular question card ────────────────────────────────────────────────────

class _RegularQuestionCard extends StatelessWidget {
  final AppColorScheme scheme;
  final int questionNumber;
  final String questionText;
  final int? selectedScore;
  final ValueChanged<int> onScore;

  const _RegularQuestionCard({
    required this.scheme,
    required this.questionNumber,
    required this.questionText,
    required this.selectedScore,
    required this.onScore,
  });

  @override
  Widget build(BuildContext context) {
    return _questionCardShell(
      scheme: scheme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _qChip(scheme, 'Q$questionNumber'),
                const SizedBox(height: 6),
                Text(
                  questionText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _AnswerButtons(
            scheme: scheme,
            selectedScore: selectedScore,
            onScore: onScore,
          ),
        ],
      ),
    );
  }
}

// ─── Communication question card ──────────────────────────────────────────────

class _CommQuestionCard extends StatelessWidget {
  final AppColorScheme scheme;
  final CommSlotState slot;
  final int slotNumber;
  final ValueChanged<int> onScore;

  const _CommQuestionCard({
    required this.scheme,
    required this.slot,
    required this.slotNumber,
    required this.onScore,
  });

  static String _truncate(String text, int words) {
    final parts = text.trim().split(' ');
    if (parts.length <= words) return text;
    return '${parts.take(words).join(' ')}…';
  }

  @override
  Widget build(BuildContext context) {
    final activeLevel = slot.activeLevel;
    final activeQuestion = slot.chain[activeLevel];
    final lockedIndices = slot.lockedLevelIndices;
    final selectedScore = slot.scores[activeLevel];

    return _questionCardShell(
      scheme: scheme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lockedIndices.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: lockedIndices.map((i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.textMuted.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: scheme.glassBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 10, color: scheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _truncate(slot.chain[i].text, 4),
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                _qChip(scheme, 'Q$slotNumber'),
                const SizedBox(height: 6),
                Text(
                  activeQuestion.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _AnswerButtons(
            scheme: scheme,
            selectedScore: selectedScore,
            onScore: onScore,
          ),
        ],
      ),
    );
  }
}

// ─── Answer buttons ───────────────────────────────────────────────────────────

class _AnswerButtons extends StatelessWidget {
  final AppColorScheme scheme;
  final int? selectedScore;
  final ValueChanged<int> onScore;

  const _AnswerButtons({
    required this.scheme,
    required this.selectedScore,
    required this.onScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (score) {
        final isSelected = selectedScore == score;
        return Padding(
          padding: EdgeInsets.only(left: score > 0 ? 6 : 0),
          child: GestureDetector(
            onTap: () => onScore(score),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: isSelected
                  ? BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: scheme.glassBorder,
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.06),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.03),
                          blurRadius: 1,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
              child: Center(
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? scheme.onPrimary : scheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── All-complete dialog ──────────────────────────────────────────────────────

class _AllCompleteDialog extends StatelessWidget {
  final AppColorScheme scheme;
  final bool isLoading;
  final VoidCallback onViewResults;

  const _AllCompleteDialog({
    required this.scheme,
    required this.isLoading,
    required this.onViewResults,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.08,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.glassBase,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.glassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 48,
                  color: scheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Assessment Complete!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap below to start the analysis and view your child\'s personalized growth roadmap.',
                  style: TextStyle(fontSize: 14, color: scheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    label: isLoading ? 'Analyzing…' : 'Start the Journey! 🌱',
                    onPressed: isLoading ? () {} : onViewResults,
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

// ─── Assessment intro dialog ──────────────────────────────────────────────────

class _AssessmentIntroDialog extends StatelessWidget {
  final AppColorScheme scheme;

  const _AssessmentIntroDialog({required this.scheme});

  @override
  Widget build(BuildContext context) {
    const notYetColor = AppColors.error;
    const sometimesColor = AppColors.warning;
    const yesColor = AppColors.success;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.06,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.glassBase,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.glassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment_outlined,
                      color: scheme.primary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'About This Assessment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This takes about 10–15 minutes',
                  style: TextStyle(fontSize: 12, color: scheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Divider(color: scheme.glassBorder, height: 1),
                const SizedBox(height: 16),
                _InfoRow(
                  scheme: scheme,
                  icon: Icons.grid_view_rounded,
                  text:
                      '8 developmental areas covering your child\'s key growth milestones',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  scheme: scheme,
                  icon: Icons.help_outline_rounded,
                  text:
                      '5 questions per area — all based on everyday behaviors you can observe at home',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  scheme: scheme,
                  icon: Icons.bar_chart_rounded,
                  text: 'Each question has 3 answers:',
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        _ScoreChip(label: '✗  Not Yet', color: notYetColor),
                        const SizedBox(width: 6),
                        _ScoreChip(
                            label: '−  Sometimes', color: sometimesColor),
                        const SizedBox(width: 6),
                        _ScoreChip(label: '✓  Yes!', color: yesColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    label: 'Let\'s Begin',
                    onPressed: () => Navigator.of(context).pop(),
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

class _InfoRow extends StatelessWidget {
  final AppColorScheme scheme;
  final IconData icon;
  final String text;
  final Widget? trailing;

  const _InfoRow({
    required this.scheme,
    required this.icon,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.textPrimary,
                  height: 1.4,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ScoreChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
