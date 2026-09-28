import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/monitoring/analytics_event.dart';
import '../../../../core/monitoring/analytics_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/cards/glass_card.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends ConsumerState<EmailVerificationPage>
    with SingleTickerProviderStateMixin {

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _bgCtrl;

  // ── OTP state ──────────────────────────────────────────────────────────────
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;

  // ── Resend countdown ───────────────────────────────────────────────────────
  int _resendSeconds = 0;
  Timer? _countdownTimer;

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
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _countdownTimer?.cancel();
    for (final c in _otpControllers) { c.dispose(); }
    for (final n in _otpFocusNodes) { n.dispose(); }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OTP LOGIC
  // ─────────────────────────────────────────────────────────────────────────

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onOtpKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  bool get _isOtpComplete =>
      _otpControllers.every((c) => c.text.isNotEmpty);

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) return;

    setState(() => _isLoading = true);
    try {
      await SupabaseService.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.signup,
      );

      if (!mounted) return;
      // The true completion moment for the OTP-required signup path —
      // auth_page.dart's _handleSignUp() only fires signup_completed for
      // the immediately-confirmed (no-OTP) branch.
      ref.read(analyticsServiceProvider).capture(const SignupCompleted(method: 'email'));
      final user = SupabaseService.currentUser;
      if (user != null) {
        ref.read(analyticsServiceProvider).identify(user.id);
      }
      await NavigationService.loadActiveChildIfAny(ref);
      if (!mounted) return; // guard after second await
      context.go(AppRoutes.home); // ignore: use_build_context_synchronously
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid code. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        for (final c in _otpControllers) { c.clear(); }
        _otpFocusNodes.first.requestFocus();
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (_resendSeconds > 0) return;
    try {
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      setState(() => _resendSeconds = 60);
      _startCountdown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend. Try again.')),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendSeconds <= 1) {
        _countdownTimer?.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
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
          // ── Animated gradient background ─────────────────────────────────
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

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.signUp),
                    child: GlassCard(
                      borderRadius: 18,
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: scheme.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Icon + title + subtitle
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color:
                                scheme.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mark_email_unread_outlined,
                            color: scheme.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Check Your Email',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: scheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We sent a 6-digit code to\n${widget.email}',
                          style: TextStyle(
                            fontSize: 14,
                            color: scheme.textMuted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // OTP boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                        6, (i) => _buildOtpBox(i, scheme)),
                  ),

                  const SizedBox(height: 32),

                  // Verify button
                  GestureDetector(
                    onTap:
                        (_isOtpComplete && !_isLoading) ? _verifyOTP : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: _isOtpComplete
                            ? scheme.primary
                            : scheme.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: _isOtpComplete
                            ? [
                                BoxShadow(
                                  color: scheme.primary
                                      .withValues(alpha: 0.30),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Text(
                                'Verify Email',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend link
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Didn\'t receive the code? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.textMuted,
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              _resendSeconds == 0 ? _resendOTP : null,
                          child: Text(
                            _resendSeconds > 0
                                ? 'Resend (${_resendSeconds}s)'
                                : 'Resend',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _resendSeconds > 0
                                  ? scheme.textMuted
                                  : scheme.primary,
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
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index, AppColorScheme scheme) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) => _onOtpKeyEvent(index, event),
      child: SizedBox(
        width: 46,
        height: 56,
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: scheme.glassBase,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.primary, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) => _onOtpChanged(index, value),
        ),
      ),
    );
  }
}