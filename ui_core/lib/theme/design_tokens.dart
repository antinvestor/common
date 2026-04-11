import 'package:flutter/material.dart';

/// Design tokens from the Stitch design system.
///
/// These constants encode the "Architectural Fintech Standard" design language:
/// tonal layering, gradient CTAs, ambient shadows, and ghost borders.
abstract final class DesignTokens {
  // ── Primary CTA gradient (135deg, "metallic" weight) ──────────────────────
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF031632), Color(0xFF1A2B48)],
  );

  // ── Ambient shadow for floating elements ──────────────────────────────────
  static const ambientShadow = BoxShadow(
    color: Color(0x0F081B38),
    blurRadius: 40,
    offset: Offset(0, 20),
  );

  // ── Subtle shadow for cards ───────────────────────────────────────────────
  static const cardShadow = BoxShadow(
    color: Color(0x08081B38),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  // ── Ghost border (15% opacity outline_variant — "felt, not seen") ─────────
  static Color ghostBorder(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant.withAlpha(38);

  // ── Sidebar accent bar width ──────────────────────────────────────────────
  static const accentBarWidth = 4.0;

  // ── Trust Standard radius ─────────────────────────────────────────────────
  static const borderRadius = 8.0;
  static final borderRadiusAll = BorderRadius.circular(borderRadius);
}
