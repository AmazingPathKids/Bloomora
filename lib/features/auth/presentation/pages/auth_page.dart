import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_components.dart';
import '../../../../core/theme/theme_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/monitoring/analytics_event.dart';
import '../../../../core/monitoring/analytics_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/navigation_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthPage — unified Sign Up / Sign In screen
// Default tab: Sign Up (initialIsSignUp: true)
// ─────────────────────────────────────────────────────────────────────────────

class AuthPage extends ConsumerStatefulWidget {
  final String? email;
  final bool initialIsSignUp;

  const AuthPage({
    super.key,
    this.email,
    this.initialIsSignUp = true,
  });

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with TickerProviderStateMixin {
  // ── Form keys ────────────────────────────────────────────────────────────
  final _signUpFormKey = GlobalKey<FormState>();
  final _signInFormKey = GlobalKey<FormState>();

  // ── Sign-up controllers ───────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ── Sign-in controllers ───────────────────────────────────────────────────
  final _siEmailController = TextEditingController();
  final _siPasswordController = TextEditingController();

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _isSignUp = true;
  bool _isLoading = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeCtrl);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.email != null && widget.email!.isNotEmpty) {
      _emailController.text = widget.email!;
      _siEmailController.text = widget.email!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _entryCtrl.forward());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _siEmailController.dispose();
    _siPasswordController.dispose();
    _bgCtrl.dispose();
    _shakeCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _setTab(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    setState(() => _isSignUp = isSignUp);
    _entryCtrl.forward(from: 0);
  }

  // ── Sign Up — Supabase logic untouched ────────────────────────────────────
  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() => _isLoading = true);
    ref.read(analyticsServiceProvider).capture(const SignupStarted());
    try {
      await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      if (mounted) {
        // Check if user is immediately authenticated
        // (email confirmation is disabled in Supabase)
        final user = SupabaseService.currentUser;
        if (user != null && user.emailConfirmedAt != null) {
          // Confirmed immediately (no OTP step) — this is the actual
          // completion moment for this path. The OTP-required path's
          // completion is wired at email_verification_page.dart's
          // successful _verifyOTP() instead, not here.
          ref.read(analyticsServiceProvider).capture(const SignupCompleted(method: 'email'));
          ref.read(analyticsServiceProvider).identify(user.id);
          // User is confirmed — load their child (if any) for theme/state,
          // then go to /home; route_guards.dart redirects to the right
          // onboarding step if one isn't finished yet.
          await NavigationService.loadActiveChildIfAny(ref);
          if (mounted) context.go(AppRoutes.home); // ignore: use_build_context_synchronously
        } else {
          // User needs email confirmation
          context.go(
            '/verify-email?email=${Uri.encodeComponent(
              _emailController.text.trim())}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _shakeCtrl.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref.read(authProvider).error ?? e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Sign In — Supabase logic untouched ────────────────────────────────────
  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signIn(
            email: _siEmailController.text.trim(),
            password: _siPasswordController.text,
          );
      if (!mounted) return;
      ref.read(analyticsServiceProvider).capture(const SigninCompleted(method: 'email'));
      final user = SupabaseService.currentUser;
      if (user != null) {
        ref.read(analyticsServiceProvider).identify(user.id);
      }
      await NavigationService.loadActiveChildIfAny(ref);
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        _shakeCtrl.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref.read(authProvider).error ?? e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Forgot Password — logic untouched ─────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _siEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first')),
      );
      return;
    }
    try {
      await ref.read(authProvider.notifier).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ── Google Sign-In handler ────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: AppConfig.googleIosClientId,
        serverClientId: AppConfig.googleWebClientId,
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (!mounted) return;
      // Supabase's signInWithIdToken() both signs up a new user and signs
      // in a returning one — there's no separate "was this a new account"
      // signal available here to distinguish signup vs signin, so this is
      // recorded as signin_completed either way (a reasonable
      // simplification, flagged rather than silently picked).
      ref.read(analyticsServiceProvider).capture(const SigninCompleted(method: 'google'));
      final user = SupabaseService.currentUser;
      if (user != null) {
        ref.read(analyticsServiceProvider).identify(user.id);
      }
      await NavigationService.loadActiveChildIfAny(ref);
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Google Sign-In failed. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Apple Sign-In handler ─────────────────────────────────────────────────
  Future<void> _handleAppleSignIn() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Apple Sign-In coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ── Field stagger helper ──────────────────────────────────────────────────
  Widget _fieldWrap(int i, Widget child) {
    const stagger = 50.0 / 600.0;
    const dur = 320.0 / 600.0;
    final start = (i * stagger).clamp(0.0, 1.0);
    final end = (start + dur).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (_, __) {
        final t = CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ).value;
        return Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      },
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

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  _buildLogo(scheme),
                  const SizedBox(height: 32),
                  // Shake wrapper around the glass card
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(
                        6 * math.sin(_shakeAnim.value * math.pi * 5),
                        0,
                      ),
                      child: child,
                    ),
                    child: _buildCard(scheme),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo + wordmark ────────────────────────────────────────────────────────
  Widget _buildLogo(AppColorScheme scheme) {
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 6; i++)
                Transform.translate(
                  offset: Offset(
                    12 * math.cos((i * 60 - 90) * math.pi / 180),
                    12 * math.sin((i * 60 - 90) * math.pi / 180),
                  ),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Bloomora',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.textPrimary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ── Glass card ─────────────────────────────────────────────────────────────
  Widget _buildCard(AppColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.glassBase,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.glassBorder, width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 32,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTabControl(scheme),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        );
                      },
                      child: _isSignUp
                          ? _buildSignUpFields(scheme, key: const ValueKey('signup'))
                          : _buildSignInFields(scheme, key: const ValueKey('signin')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildDivider(scheme),
              const SizedBox(height: 18),
              _buildGoogleButton(scheme),
              const SizedBox(height: 12),
              _buildAppleButton(scheme),
              const SizedBox(height: 20),
              _buildBottomLink(scheme),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab control ────────────────────────────────────────────────────────────
  Widget _buildTabControl(AppColorScheme scheme) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Animated sliding pill
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment:
                _isSignUp ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setTab(true),
                  child: Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isSignUp ? scheme.onPrimary : scheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setTab(false),
                  child: Center(
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_isSignUp ? scheme.onPrimary : scheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sign Up form ───────────────────────────────────────────────────────────
  Widget _buildSignUpFields(AppColorScheme scheme, {Key? key}) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldWrap(0, GlassTextField(
            hint: 'Full name',
            controller: _nameController,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your full name';
              if (v.trim().length < 2) return 'Name must be at least 2 characters';
              return null;
            },
          )),
          const SizedBox(height: 14),
          _fieldWrap(1, GlassTextField(
            hint: 'Email address',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          )),
          const SizedBox(height: 14),
          _fieldWrap(2, GlassTextField(
            hint: 'Password',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscure: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          )),
          const SizedBox(height: 14),
          _fieldWrap(3, GlassTextField(
            hint: 'Confirm password',
            controller: _confirmController,
            prefixIcon: Icons.lock_outline_rounded,
            obscure: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          )),
          const SizedBox(height: 20),
          _fieldWrap(4, _buildCTAButton(
            scheme: scheme,
            label: 'Create Account',
            onTap: _isLoading ? null : _handleSignUp,
          )),
        ],
      ),
    );
  }

  // ── Sign In form ───────────────────────────────────────────────────────────
  Widget _buildSignInFields(AppColorScheme scheme, {Key? key}) {
    return Form(
      key: _signInFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldWrap(0, GlassTextField(
            hint: 'Email address',
            controller: _siEmailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          )),
          const SizedBox(height: 14),
          _fieldWrap(1, GlassTextField(
            hint: 'Password',
            controller: _siPasswordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscure: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          )),
          const SizedBox(height: 8),
          _fieldWrap(2, Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _forgotPassword,
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.primaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )),
          const SizedBox(height: 20),
          _fieldWrap(3, _buildCTAButton(
            scheme: scheme,
            label: 'Sign In',
            onTap: _isLoading ? null : _signIn,
          )),
        ],
      ),
    );
  }

  // ── CTA button ─────────────────────────────────────────────────────────────
  Widget _buildCTAButton({
    required AppColorScheme scheme,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.primary,
          borderRadius: BorderRadius.circular(32),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Divider ────────────────────────────────────────────────────────────────
  Widget _buildDivider(AppColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: scheme.textMuted.withValues(alpha: 0.25),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontSize: 13,
              color: scheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: scheme.textMuted.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }

  // ── Google button ──────────────────────────────────────────────────────────
  Widget _buildGoogleButton(AppColorScheme scheme) {
    return GestureDetector(
      onTap: _handleGoogleSignIn,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: scheme.glassBase,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: scheme.glassBorder, width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    // Exception: Google's own brand color, not an adaptive
                    // theme token — see AppColors.googleBrandBlue.
                    color: AppColors.googleBrandBlue,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Apple button ───────────────────────────────────────────────────────────
  Widget _buildAppleButton(AppColorScheme scheme) {
    return GestureDetector(
      onTap: _handleAppleSignIn,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: scheme.textPrimary.withValues(alpha: scheme.isDark ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: scheme.textPrimary.withValues(alpha: scheme.isDark ? 0.20 : 0.12),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.apple_rounded,
                  size: 22,
                  color: scheme.textPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Continue with Apple',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom link ────────────────────────────────────────────────────────────
  Widget _buildBottomLink(AppColorScheme scheme) {
    return GestureDetector(
      onTap: () => _setTab(!_isSignUp),
      child: Center(
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _isSignUp
                    ? 'Already have an account? '
                    : "Don't have an account? ",
                style: TextStyle(fontSize: 13, color: scheme.textMuted),
              ),
              TextSpan(
                text: _isSignUp ? 'Sign In' : 'Create one',
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
    );
  }
}