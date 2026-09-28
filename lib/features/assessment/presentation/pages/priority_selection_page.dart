import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../data/question_bank.dart';

class PrioritySelectionPage extends ConsumerStatefulWidget {
  const PrioritySelectionPage({super.key});

  @override
  ConsumerState<PrioritySelectionPage> createState() =>
      _PrioritySelectionPageState();
}

class _PrioritySelectionPageState extends ConsumerState<PrioritySelectionPage> {

  // ── Domain scores (loaded from Supabase) ──────────────────────────────────
  Map<String, double> _domainScores = {};
  bool _isLoading = true;

  // ── Domain icons ───────────────────────────────────────────────────────────
  static const Map<String, IconData> _domainIcons = {
    'Attention & Play':   Icons.sports_esports_outlined,
    'Cognitive':          Icons.psychology_outlined,
    'Daily Living':       Icons.home_outlined,
    'Fine Motor':         Icons.back_hand_outlined,
    'Gross Motor':        Icons.directions_run_outlined,
    'Sensory':            Icons.sensors_outlined,
    'Social & Emotional': Icons.favorite_outline,
    'Communication':      Icons.chat_bubble_outline,
  };

  // ── Selection state ────────────────────────────────────────────────────────
  List<String> _selectedDomains = [];

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDomainScores();
  }

  void _initializeSelections() {
    // Pre-select the 3 lowest-scoring domains
    final sorted = _domainScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    _selectedDomains = sorted.take(3).map((e) => e.key).toList();
  }

  Future<void> _loadDomainScores() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      // Get child
      final childResponse = await SupabaseService.client
          .from('children')
          .select('id')
          .eq('parent_id', userId)
          .single();
      final childId = childResponse['id'] as String;

      // Get latest completed assessment
      final assessmentResponse = await SupabaseService.client
          .from('assessments')
          .select('id')
          .eq('child_id', childId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      final assessmentId = assessmentResponse['id'] as String;

      // Get domain results
      final domainResults = await SupabaseService.client
          .from('domain_results')
          .select('domain, percentage')
          .eq('assessment_id', assessmentId);

      final scores = <String, double>{};
      for (final row in domainResults) {
        final domain = row['domain'] as String;
        final percentage = (row['percentage'] as num).toDouble();
        scores[domain] = percentage / 100.0;
      }

      setState(() {
        _domainScores = scores;
        _isLoading = false;
        _initializeSelections();
      });
    } catch (e) {
      // Fallback to even scores if DB fails
      setState(() {
        _domainScores = {
          for (final domain in QuestionBank.domainOrder) domain: 0.5,
        };
        _isLoading = false;
        _initializeSelections();
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS (untouched)
  // ─────────────────────────────────────────────────────────────────────────

  String _skillLevelLabel(double score) {
    if (score < 0.40) return 'Needs Support';
    if (score < 0.70) return 'Developing';
    return 'On Track';
  }

  Color _skillLevelColor(double score) {
    if (score < 0.40) return AppColors.error;
    if (score < 0.70) return AppColors.warning;
    return AppColors.success;
  }

  void _onTapDomain(String domainName) {
    final isSelected = _selectedDomains.contains(domainName);

    if (isSelected) {
      // Deselecting — auto-select 4th weakest not already selected
      _selectedDomains.remove(domainName);
      final sorted = _domainScores.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final next = sorted.firstWhere(
        (e) => !_selectedDomains.contains(e.key),
        orElse: () => sorted.first,
      );
      _selectedDomains.add(next.key);
    } else if (_selectedDomains.length < 3) {
      _selectedDomains.add(domainName);
    } else {
      // Swap: remove last, add tapped
      _selectedDomains.removeAt(_selectedDomains.length - 1);
      _selectedDomains.add(domainName);
    }

    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = ref.watch(activeColorSchemeProvider);

    final domains = _isLoading
        ? <MapEntry<String, double>>[]
        : (_domainScores.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value)));

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.onboardingAssessmentAnalyzing),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: scheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Title + counter ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Focus Areas',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: scheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select 3 domains to focus on. We\'ll personalize '
                      'your daily activities around these areas.',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 13, color: scheme.primary),
                          const SizedBox(width: 5),
                          Text(
                            '${_selectedDomains.length} of 3 selected',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Domain grid ──────────────────────────────────────────────
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.primary),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.88,
                    ),
                    itemCount: domains.length,
                    itemBuilder: (context, index) {
                      final entry = domains[index];
                      return _buildDomainCard(scheme, entry.key, entry.value);
                    },
                  ),
                ),

              // ── Selected chips + CTA ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _selectedDomains
                          .map((domain) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  domain,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 54,
                      margin: const EdgeInsets.only(bottom: 32),
                      decoration: BoxDecoration(
                        color: _selectedDomains.length == 3
                            ? scheme.primary
                            : scheme.disabledFill,
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: _selectedDomains.length == 3
                            ? [
                                BoxShadow(
                                  color:
                                      scheme.primary.withValues(alpha: 0.30),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: TextButton(
                        onPressed: _selectedDomains.length == 3
                            ? () => context.go(AppRoutes.home)
                            : null,
                        child: Text(
                          'Start My Plan →',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOMAIN CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDomainCard(
      AppColorScheme scheme, String domainName, double score) {
    final isSelected = _selectedDomains.contains(domainName);
    final icon = _domainIcons[domainName] ?? Icons.circle_outlined;

    return GestureDetector(
      onTap: () => _onTapDomain(domainName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: scheme.isDark ? 0.20 : 0.08)
              : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.25)
                : scheme.border,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.textPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? scheme.primary : scheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                domainName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _skillLevelColor(score).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _skillLevelLabel(score),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _skillLevelColor(score),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected ? scheme.primary : scheme.border,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded,
                        size: 13, color: scheme.onPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}