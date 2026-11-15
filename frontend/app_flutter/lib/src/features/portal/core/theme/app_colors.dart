import 'package:flutter/material.dart';

/// Creo brand and interface color tokens extracted from:
/// 1. Creo Admin Mobile App PDF (Pages 1-20)
/// 2. Brand Theme CSS (--portal-amber, --app-base, --app-bento, --app-line)
/// 3. Client Portal Sidebar navigation spec
class CreoColors {
  // ── Dark Mode Tokens (Default) ──
  static const Color obsidian     = Color(0xFF0F0E0C); // Main screen canvas / background
  static const Color voidBg       = Color(0xFF090807); // Bottom navigation & deepest surface
  static const Color bentoCard    = Color(0xFF171513); // Card container surface
  static const Color surface      = Color(0xFF1B1916); // Elevated element
  static const Color line         = Color(0xFF3A342D); // Subtle borders & dividers
  static const Color lineSoft     = Color(0xFF2A2622); // Inner card borders
  static const Color unselectedPill = Color(0xFF231F1B); // Unselected sub-tab pill fill

  // ── Light Mode Tokens ──
  static const Color lightBase    = Color(0xFFF5EEE3); // Warm ivory paper canvas
  static const Color lightCard    = Color(0xFFFFFFFF); // Clean white card surface
  static const Color lightLine    = Color(0xFFE3D8C8); // Soft warm border
  static const Color lightEspresso= Color(0xFF2B1E15); // Deep espresso primary ink
  static const Color lightMist    = Color(0xFF7C6E5E); // Warm muted subtitle text
  static const Color lightPillUnselected = Color(0xFFEAE0D2); // Unselected light pill

  // ── Brand Accent & Interactive Tokens ──
  static const Color amber        = Color(0xFFD2965A); // Burnished Amber / Gold retainer card / Primary CTA
  static const Color onAmber      = Color(0xFF1A120C); // High-contrast ink on amber fills
  static const Color ivory        = Color(0xFFF5EEE3); // High-contrast heading text (Dark mode)
  static const Color mist         = Color(0xFFB9AD9C); // Secondary / muted text (Dark mode)
  static const Color mistSoft     = Color(0xFFD6CBBB); // Intermediate text
  static const Color terracotta   = Color(0xFFD98A7A); // Warnings, revisions, declined items
  static const Color badgeRed     = Color(0xFFD94532); // Notification counter pill badge
  static const Color emerald      = Color(0xFF10B981); // Success / Active badge

  // ── Deliverable Format Badges ──
  static const Color reelPurple   = Color(0xFF9333EA); // Reels (9:16)
  static const Color posterBlue   = Color(0xFF2563EB); // Static Posters (1:1 / 4:5)
  static const Color storyAmber   = Color(0xFFD97706); // Stories
  static const Color carouselGreen= Color(0xFF059669); // Carousels
}

/// AppColors provides full compatibility and alias tokens
class AppColors {
  // Dark tokens
  static const Color obsidian     = CreoColors.obsidian;
  static const Color voidBlack    = CreoColors.voidBg;
  static const Color voidBg       = CreoColors.voidBg;
  static const Color cardBg       = CreoColors.bentoCard;
  static const Color bentoCard    = CreoColors.bentoCard;
  static const Color surface      = CreoColors.surface;
  static const Color line         = CreoColors.line;
  static const Color lineSoft     = CreoColors.lineSoft;
  static const Color unselectedPill = CreoColors.unselectedPill;

  // Light tokens
  static const Color lightBase    = CreoColors.lightBase;
  static const Color lightCard    = CreoColors.lightCard;
  static const Color lightSurface = CreoColors.lightCard;
  static const Color lightLine    = CreoColors.lightLine;
  static const Color lightBorder  = CreoColors.lightLine;
  static const Color lightEspresso= CreoColors.lightEspresso;
  static const Color lightInk     = CreoColors.lightEspresso;
  static const Color lightMist    = CreoColors.lightMist;
  static const Color lightPillUnselected = CreoColors.lightPillUnselected;

  // Accents
  static const Color amber        = CreoColors.amber;
  static const Color onAmber      = CreoColors.onAmber;
  static const Color ivory        = CreoColors.ivory;
  static const Color mist         = CreoColors.mist;
  static const Color mistSoft     = CreoColors.mistSoft;
  static const Color terracotta   = CreoColors.terracotta;
  static const Color badgeRed     = CreoColors.badgeRed;
  static const Color emerald      = CreoColors.emerald;

  // Formats
  static const Color reelPurple   = CreoColors.reelPurple;
  static const Color posterBlue   = CreoColors.posterBlue;
  static const Color storyAmber   = CreoColors.storyAmber;
  static const Color carouselGreen= CreoColors.carouselGreen;
}
