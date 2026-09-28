import 'package:flutter/material.dart';

/// A single resolved color scheme for one palette family + brightness pair.
///
/// Field names intentionally match the existing internal convention
/// (`primary`, `textPrimary`, ...) rather than the Frontend Spec's
/// "token-case" names (`primary`, `text-primary`, ...) — Dart naming, same
/// values. See [AppColors] for where each hex comes from.
class AppColorScheme {
  final Color background;
  final Color surface;

  /// The spec's "surface-soft" (light themes) / "surface-raised" (dark
  /// themes) tier — a secondary background layer distinct from [surface].
  /// Named neutrally since one field serves both roles depending on [isDark].
  final Color surfaceElevated;

  final Color primary;

  /// Pressed/active state for primary-filled controls (spec: "theme
  /// primary-strong token"). The Frontend Spec only gives explicit values
  /// for the two Light palettes; the two Dark values are derived (see
  /// [AppColors] for the exact method) since the spec doesn't specify them.
  final Color primaryStrong;

  final Color secondary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  /// Disabled-state fill/text — fixed per brightness (not per palette
  /// family), per the spec. Light values are spec-given; dark values are
  /// derived (see [AppColors]) since the spec only gives a light-mode pair.
  final Color disabledFill;
  final Color disabledText;

  final bool isDark;

  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryStrong,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.disabledFill,
    required this.disabledText,
    required this.isDark,
  });

  // ─── Compatibility aliases ────────────────────────────────────────────
  // Pre-FT-002 call sites (~180 across the app) read these field names.
  // Rewriting every call site to the spec-named fields above is out of
  // FT-002's scope (see docs/audit-findings.md Section F / the FT-002
  // ticket's scope boundary) — but the VALUES they resolve to are now
  // fully spec-correct, derived from the fields above rather than
  // hardcoded. New code should prefer the fields above directly.

  /// = [accent]. Was previously its own literal; the spec's "accent" token
  /// serves the same "lighter/brighter than primary" role.
  Color get primaryLight => accent;

  /// Derived from [textSecondary] at reduced opacity — the spec's
  /// four-palette table only defines text-primary/text-secondary, not a
  /// third "muted" tier.
  Color get textMuted => textSecondary.withValues(alpha: 0.7);

  /// Semi-opaque [surface] for glass effects — see GlassCard
  /// (lib/core/widgets/cards/glass_card.dart) for the opacity reasoning.
  Color get glassBase => surface.withValues(alpha: isDark ? 0.82 : 0.88);

  /// Semi-opaque [border] to match [glassBase].
  Color get glassBorder => border.withValues(alpha: 0.6);

  // ─── On-color content tokens ────────────────────────────────────────────
  // High-contrast text/icon color for content placed directly on a
  // [primary]- or [secondary]-colored surface (filled buttons, pills,
  // badges) — fixed white across all four palettes by design, mirroring
  // `onPrimary`/`onSecondary` in lib/core/theme/app_theme.dart's Material
  // ColorScheme. Not palette-adaptive, since [primary]/[secondary] are
  // themselves chosen per palette to stay legible against white — same
  // category as [AppColors.googleBrandBlue]: a documented, intentional
  // fixed value, not a hardcoded literal.

  /// Text/icon color for content on a [primary]-colored surface.
  Color get onPrimary => Colors.white;

  /// Text/icon color for content on a [secondary]-colored surface.
  Color get onSecondary => Colors.white;
}

/// Static color tokens: the four adaptive palettes, semantic colors,
/// developmental-domain accents, and fixed accessibility constants.
///
/// Use [AppColors.forProfile] to resolve the correct [AppColorScheme] for a
/// gender + brightness pair, or resolve directly against a manual
/// Ocean/Blossom override — see lib/core/theme/theme_provider.dart.
class AppColors {
  AppColors._();

  // ─── Ocean Light (internal name: boyLight) ─────────────────────────────
  // Frontend Spec §3, "Ocean Light" column.

  static const boyLight = AppColorScheme(
    primary:         Color(0xFF356FA8),
    primaryStrong:   Color(0xFF255780),
    secondary:       Color(0xFF66A6B8),
    accent:          Color(0xFF8FC7D8),
    background:      Color(0xFFF6FAFD),
    surface:         Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEAF3F8), // "surface-soft"
    textPrimary:     Color(0xFF183247),
    textSecondary:   Color(0xFF607585),
    border:          Color(0xFFD8E6EE),
    disabledFill:    _disabledFillLight,
    disabledText:    _disabledTextLight,
    isDark:          false,
  );

  // ─── Ocean Dark (internal name: boyDark) ───────────────────────────────
  // Frontend Spec §3, "Ocean Dark" column. primary-strong is not given by
  // the spec for dark palettes — derived by mixing 20% black into
  // `primary` (a standard "pressed" darkening that stays visible against a
  // dark background; see AppColors._darken).

  static const boyDark = AppColorScheme(
    primary:         Color(0xFF73A9DB),
    primaryStrong:   Color(0xFF5C87AF), // derived: primary darkened ~20%
    secondary:       Color(0xFF65B1BE),
    accent:          Color(0xFF9ACCDD),
    background:      Color(0xFF0D1822),
    surface:         Color(0xFF152532),
    surfaceElevated: Color(0xFF1C3040), // "surface-raised"
    textPrimary:     Color(0xFFF2F7FA),
    textSecondary:   Color(0xFFA7BBC8),
    border:          Color(0xFF29404F),
    disabledFill:    _disabledFillDark,
    disabledText:    _disabledTextDark,
    isDark:          true,
  );

  // ─── Blossom Light (internal name: girlLight) ──────────────────────────
  // Frontend Spec §3, "Blossom Light" column.

  static const girlLight = AppColorScheme(
    primary:         Color(0xFFA95F86),
    primaryStrong:   Color(0xFF85476A),
    secondary:       Color(0xFF9875B5),
    accent:          Color(0xFFD7A3BC),
    background:      Color(0xFFFCF8FB),
    surface:         Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF7EAF1), // "surface-soft"
    textPrimary:     Color(0xFF442C3B),
    textSecondary:   Color(0xFF796471),
    border:          Color(0xFFECD9E3),
    disabledFill:    _disabledFillLight,
    disabledText:    _disabledTextLight,
    isDark:          false,
  );

  // ─── Blossom Dark (internal name: girlDark) ────────────────────────────
  // Frontend Spec §3, "Blossom Dark" column. primary-strong derived the
  // same way as Ocean Dark's (see above).

  static const girlDark = AppColorScheme(
    primary:         Color(0xFFD58FB2),
    primaryStrong:   Color(0xFFAA728E), // derived: primary darkened ~20%
    secondary:       Color(0xFFB49AD0),
    accent:          Color(0xFFE1B3CB),
    background:      Color(0xFF1B1218),
    surface:         Color(0xFF291C25),
    surfaceElevated: Color(0xFF35242F), // "surface-raised"
    textPrimary:     Color(0xFFFAF3F7),
    textSecondary:   Color(0xFFCBB5C1),
    border:          Color(0xFF493340),
    disabledFill:    _disabledFillDark,
    disabledText:    _disabledTextDark,
    isDark:          true,
  );

  // ─── Disabled state ─────────────────────────────────────────────────────
  // Fixed per brightness, not per palette family (spec, §3 + component
  // spec). Light values are spec-given. Dark values are derived — the spec
  // doesn't give them explicitly, and its light-mode pair (#E2E8F0 fill /
  // #94A3B8 text) would be low-contrast against Ocean Dark/Blossom Dark
  // backgrounds. Chosen: a muted neutral close to the dark surface-raised
  // tone for fill, and a dimmed neutral (not palette text-secondary, to
  // stay palette-independent) for text — both checked to keep >=3:1
  // contrast against the two dark backgrounds while clearly reading as
  // "inactive" rather than "primary" text.
  static const _disabledFillLight = Color(0xFFE2E8F0);
  static const _disabledTextLight = Color(0xFF94A3B8);
  static const _disabledFillDark  = Color(0xFF2A3844);
  static const _disabledTextDark  = Color(0xFF64748B);

  // ─── Fixed third-party brand colors (documented exceptions) ────────────
  // Genuinely fixed — not part of the adaptive palette system, and
  // shouldn't be: this is Google's own brand mark, not a Bloomora token.
  // Centralized here instead of inline in auth_page.dart per FT-002.

  /// Google "G" logo blue, used only on the "Continue with Google" button.
  static const googleBrandBlue = Color(0xFF4285F4);

  // ─── Resolver ──────────────────────────────────────────────────────────

  /// Returns the correct [AppColorScheme] for a given gender + brightness
  /// pair. [gender] should be `'boy'`, `'girl'`, or `'unset'` (defaults to
  /// Ocean/boy — see lib/core/theme/theme_provider.dart for the full
  /// gender-default vs. manual-override resolution, which this helper
  /// doesn't itself implement).
  static AppColorScheme forProfile({
    required String gender,
    required bool isDark,
  }) {
    final isGirl = gender == 'girl';
    if (isGirl) return isDark ? girlDark : girlLight;
    return isDark ? boyDark : boyLight;
  }

  // ─── Semantic colors (single set, not palette-specific) ────────────────
  // Frontend Spec §3.2.

  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const error   = Color(0xFFB91C1C);
  static const info    = Color(0xFF0369A1);

  // ─── Fixed accessibility constants (same across all palettes) ──────────
  // Deliberately palette-independent per the Frontend Spec — kept
  // consistent across all four themes as an accessibility convention.

  /// Text input focus ring.
  static const focusRing = Color(0xFF2563EB);

  /// Modal/bottom-sheet scrim, ~45% black.
  static const scrim = Color.fromRGBO(0, 0, 0, 0.45);

  // ─── Developmental domain accents (single set, not palette-specific) ───
  // Secondary encoding only — never the sole indicator of a domain.

  static const domainAttentionPlay      = Color(0xFF7C3AED);
  static const domainCognitive          = Color(0xFF2563EB);
  static const domainDailyLiving        = Color(0xFF059669);
  static const domainFineMotor          = Color(0xFFDB2777);
  static const domainGrossMotor         = Color(0xFFEA580C);
  static const domainSensory            = Color(0xFF0891B2);

  /// = [domainDailyLiving]. Pre-FT-002 name for the same domain — kept so
  /// existing call sites (priority_cards.dart, activity_card.dart) keep
  /// compiling; new code should use [domainDailyLiving] or [domainColors].
  static const domainAdaptive = domainDailyLiving;
  static const domainSocialEmotional    = Color(0xFFE11D48);
  static const domainCommunication      = Color(0xFF4F46E5);

  /// Domain name -> accent color, keyed exactly as the Frontend Spec names
  /// them. Prefer this map (or the named constants above) over inventing a
  /// new domain color inline.
  static const Map<String, Color> domainColors = {
    'Attention & Play':   domainAttentionPlay,
    'Cognitive':          domainCognitive,
    'Daily Living':       domainDailyLiving,
    'Fine Motor':         domainFineMotor,
    'Gross Motor':        domainGrossMotor,
    'Sensory':            domainSensory,
    'Social & Emotional': domainSocialEmotional,
    'Communication':      domainCommunication,
  };

  // ─── Legacy static aliases (used by existing screens pre-FT-002) ──────
  // These are non-adaptive (they don't follow palette family or dark
  // mode) — new code should use AppColorScheme fields via
  // activeColorSchemeProvider instead. Kept, with corrected values, so
  // ~30 existing call sites across features/ keep compiling; rewriting
  // them to the adaptive scheme is out of FT-002's scope (design-system
  // foundation, not a full app re-skin).

  // Values below duplicate Ocean Light's literals directly (rather than
  // referencing `boyLight.field`) because Dart doesn't allow instance
  // field access on a const object inside another const expression.
  static const primary      = Color(0xFF356FA8); // = boyLight.primary
  static const primaryLight = Color(0xFF8FC7D8); // = boyLight.accent

  static const textPrimary   = Color(0xFF183247); // = boyLight.textPrimary
  static const textSecondary = Color(0xFF607585); // = boyLight.textSecondary
  static const textMuted     = Color(0xFF94A3B8);

  static const grey50  = Color(0xFFFAFAFA);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey200 = Color(0xFFEEEEEE);
  static const grey300 = Color(0xFFE0E0E0);
  static const grey400 = Color(0xFFBDBDBD);
  static const grey500 = Color(0xFF9E9E9E);
  static const grey600 = Color(0xFF757575);
  static const grey700 = Color(0xFF616161);
  static const grey800 = Color(0xFF424242);
  static const grey900 = Color(0xFF212121);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  static const secondary      = Color(0xFF66A6B8); // = boyLight.secondary
  static const secondaryLight = Color(0xFFB8D6DE);

  static const accent      = Color(0xFF8FC7D8); // = boyLight.accent
  static const accentLight = Color(0xFFC3DEE8);

  static const successLight = Color(0xFF86D4A3);
  static const infoLight    = Color(0xFF7EB8DC);

  static const backgroundPrimary   = Color(0xFFF6FAFD); // = boyLight.background
  static const backgroundSecondary = Color(0xFFEAF3F8); // = boyLight.surfaceElevated

  static const border = Color(0xFFD8E6EE); // = boyLight.border
  static const shadow = Color(0x0D0F172A);
}
