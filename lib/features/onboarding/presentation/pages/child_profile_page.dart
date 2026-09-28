import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/monitoring/analytics_event.dart';
import '../../../../core/monitoring/analytics_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/router/route_guards.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_components.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/cards/glass_card.dart';
import '../providers/onboarding_provider.dart';
import '../../domain/models/child_model.dart';

class ChildProfilePageNew extends ConsumerStatefulWidget {
  const ChildProfilePageNew({super.key});

  @override
  ConsumerState<ChildProfilePageNew> createState() =>
      _ChildProfilePageNewState();
}

class _ChildProfilePageNewState extends ConsumerState<ChildProfilePageNew>
    with TickerProviderStateMixin {
  // ── Form keys & controllers (preserved) ──────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthTimeController = TextEditingController();

  // ── Form state (preserved) ────────────────────────────────────────────────
  DateTime? _selectedDate;
  String _selectedGender = 'Boy';    // default: Boy per spec
  bool _isLoading = false;
  String _relationship = 'Mother';   // updated to match new options list

  // ── Age calculation (preserved) ───────────────────────────────────────────
  String? _ageGroup;
  bool _isAgeValid = true;

  // ── Animation controllers (preserved for dispose compatibility) ───────────
  late AnimationController _backgroundAnimationController;
  late AnimationController _formAnimationController;
  late Animation<double> _formAnimation;

  // ── Option lists ──────────────────────────────────────────────────────────
  final List<String> _relationshipOptions = [
    'Mother', 'Father', 'Guardian', 'Grandparent', 'Therapist', 'Other',
  ];

  // ── Form validity ─────────────────────────────────────────────────────────
  bool get _isFormValid =>
      _nameController.text.trim().isNotEmpty &&
      _selectedDate != null &&
      _isAgeValid;

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Preserved verbatim
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _formAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Set default boy theme + start entry animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeNotifierProvider.notifier).setGender('boy');
      _formAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthTimeController.dispose();
    _backgroundAnimationController.dispose();
    _formAnimationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIC — preserved verbatim
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _selectDate() async {
    final scheme = ref.read(activeColorSchemeProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: scheme.isDark ? Brightness.dark : Brightness.light,
              primary: scheme.primary,
              onPrimary: scheme.onPrimary,
              secondary: scheme.secondary,
              onSecondary: scheme.onSecondary,
              surface: scheme.surface,
              onSurface: scheme.textPrimary,
              error: AppColors.error,
              onError: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _calculateAge();
      });
    }
  }

  void _calculateAge() {
    if (_selectedDate == null) return;

    final now = DateTime.now();
    final ageInMonths = ((now.year - _selectedDate!.year) * 12) +
        (now.month - _selectedDate!.month);

    setState(() {
      if (ageInMonths >= 12 && ageInMonths < 24) {
        _ageGroup = '1-2 years';
        _isAgeValid = true;
      } else if (ageInMonths >= 24 && ageInMonths < 36) {
        _ageGroup = '2-3 years';
        _isAgeValid = true;
      } else if (ageInMonths >= 36 && ageInMonths < 48) {
        _ageGroup = '3-4 years';
        _isAgeValid = true;
      } else if (ageInMonths >= 48 && ageInMonths < 60) {
        _ageGroup = '4-5 years';
        _isAgeValid = true;
      } else {
        _ageGroup = null;
        _isAgeValid = false;
      }
    });
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your child\'s date of birth'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    if (!_isAgeValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'We currently only provide services for children aged 1-5 years'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use calculated age group (validated non-null by _isAgeValid check above)
      final ageGroup = (_ageGroup ?? '1-2').replaceAll(' years', '');

      // Read directly from Supabase to avoid race with Riverpod state
      final parentId = SupabaseService.currentUser?.id ?? '';
      if (parentId.isEmpty) {
        throw Exception('Not authenticated. Please sign in again.');
      }

      // Insert child into Supabase
      final now = DateTime.now();
      final response = await SupabaseService.client
          .from('children')
          .insert({
            'parent_id': parentId,
            'name': _nameController.text.trim(),
            'date_of_birth': _selectedDate!.toIso8601String(),
            'gender': _selectedGender,
            'age_group': ageGroup,
            'relationship': _relationship,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();

      final child = ChildModel(
        id: response['id'] as String,
        parentId: parentId,
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate!,
        gender: _selectedGender,
        ageGroup: ageGroup,
        relationship: _relationship,
        createdAt: now,
        updatedAt: now,
      );

      ref.read(childNotifierProvider.notifier).setChild(child);
      // See route_guards.dart's OnboardingCompleteCache: defensive, not a
      // fix for today's flow (this user can't have been cached "complete"
      // if they just created their first child), but keeps a future
      // add-another-child flow correct too.
      ref.read(onboardingCompleteCacheProvider.notifier).invalidate(parentId);

      // Beyond FT-008's literal "auth call sites" scope, but flagged there
      // as a real, existing screen — the practical activation signal for
      // this app (see analytics_event.dart's ChildProfileCreated doc
      // comment for the reasoning/caveat behind this interpretation).
      ref.read(analyticsServiceProvider).capture(const ChildProfileCreated());

      if (mounted) context.go(AppRoutes.onboardingAssessment);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showRelationshipSheet(BuildContext context, AppColorScheme scheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.96),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: scheme.glassBorder, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: scheme.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 24, right: 24, bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'I am the child\'s',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                ..._relationshipOptions.map((option) {
                  final isSelected = _relationship == option;
                  return InkWell(
                    onTap: () {
                      setState(() => _relationship = option);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: scheme.glassBorder,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            option,
                            style: TextStyle(
                              fontSize: 16,
                              color: scheme.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              color: scheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
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
          // ── Animated gradient background ──────────────────────────────────
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (_, __) {
              final t = _backgroundAnimationController.value;
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

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: AnimatedBuilder(
              animation: _formAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, 24 * (1 - _formAnimation.value)),
                child: Opacity(
                  opacity: _formAnimation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Header ──────────────────────────────────────
                            _buildHeader(scheme),

                            const SizedBox(height: 28),

                            // ── Avatar ───────────────────────────────────────
                            _buildAvatar(scheme),

                            const SizedBox(height: 32),

                            // ── Form card ────────────────────────────────────
                            GlassCard(
                              borderRadius: 24,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Field 1 — Name
                                  _label('Child\'s Name', scheme),
                                  const SizedBox(height: 8),
                                  GlassTextField(
                                    hint: 'Enter child\'s name',
                                    controller: _nameController,
                                    prefixIcon:
                                        Icons.sentiment_satisfied_alt_outlined,
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter your child\'s name';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 22),

                                  // Field 2 — Date of birth
                                  _label('Date of Birth', scheme),
                                  const SizedBox(height: 8),
                                  _buildDobField(scheme),
                                  if (_ageGroup != null) ...[
                                    const SizedBox(height: 10),
                                    _buildAgeChip(scheme),
                                  ],

                                  const SizedBox(height: 22),

                                  // Field 3 — Gender
                                  _label('Gender', scheme),
                                  const SizedBox(height: 10),
                                  _buildGenderCards(scheme),

                                  const SizedBox(height: 22),

                                  // Field 4 — Relationship
                                  _label('I am the child\'s', scheme),
                                  const SizedBox(height: 8),
                                  _buildRelationshipRow(scheme),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Continue button ──────────────────────────────
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isFormValid ? 1.0 : 0.4,
                              child: IgnorePointer(
                                ignoring: !_isFormValid || _isLoading,
                                child: _isLoading
                                    ? _loadingButton(scheme)
                                    : GlassButton(
                                        label: 'Continue',
                                        onPressed: _handleContinue,
                                      ),
                              ),
                            ),

                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          // Back → auth
          GestureDetector(
            onTap: () => context.go(AppRoutes.signIn),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.glassBase,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.glassBorder),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: scheme.textSecondary,
                size: 16,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Child Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: scheme.textPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 36), // balances back button
        ],
      ),
    );
  }

  Widget _buildAvatar(AppColorScheme scheme) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                // Glass circle with animated primary glow + border
                ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.glassBase,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.50),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.20),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.face_retouching_natural,
                          size: 40,
                          color: scheme.primary.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ),
                // + button — bottom-right
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.background,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: scheme.onPrimary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add photo',
            style: TextStyle(
              fontSize: 12,
              color: scheme.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDobField(AppColorScheme scheme) {
    return GestureDetector(
      onTap: _selectDate,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: scheme.glassBase,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.glassBorder, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: scheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? _formatDate(_selectedDate!)
                      : 'Select date of birth',
                  style: TextStyle(
                    fontSize: 15,
                    color: _selectedDate != null
                        ? scheme.textPrimary
                        : scheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgeChip(AppColorScheme scheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Age group: ${_ageGroup!.replaceAll(' years', '')}',
        style: TextStyle(
          fontSize: 12,
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGenderCards(AppColorScheme scheme) {
    return Row(
      children: [
        Expanded(child: _genderCard('Boy', Icons.face, scheme)),
        const SizedBox(width: 12),
        Expanded(child: _genderCard('Girl', Icons.face_3, scheme)),
      ],
    );
  }

  Widget _genderCard(String gender, IconData icon, AppColorScheme scheme) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGender = gender);
        ref
            .read(themeNotifierProvider.notifier)
            .setGender(gender.toLowerCase());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary
              : scheme.glassBase,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.glassBorder,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? scheme.onPrimary : scheme.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              gender,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? scheme.onPrimary : scheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipRow(AppColorScheme scheme) {
    return GestureDetector(
      onTap: () => _showRelationshipSheet(context, scheme),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: scheme.glassBase,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.glassBorder, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: scheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _relationship,
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingButton(AppColorScheme scheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 56,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, AppColorScheme scheme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.textSecondary,
      ),
    );
  }
}