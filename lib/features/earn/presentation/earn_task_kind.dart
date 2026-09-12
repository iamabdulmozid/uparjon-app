import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';

/// The earning categories (Figma "Uparjon": Ads / Quiz / Survey, plus the
/// API's campaigns). Drives the landing tiles, the list screens and the
/// `/earn/:kind` route slug.
enum EarnTaskKind {
  ads(
    slug: 'ads',
    title: 'Ads',
    noun: 'Ad',
    subtitle: 'Watch video ad and earn money',
    icon: AppAssets.iconVideo,
    color: AppColors.blue,
    tint: AppColors.blueTint,
    emptyMessage: 'No ads available right now.\nCheck back a little later.',
  ),
  quizzes(
    slug: 'quizzes',
    title: 'Quiz',
    noun: 'Quiz',
    subtitle: 'Complete Quiz and earn money',
    icon: AppAssets.iconNotebook,
    color: AppColors.green,
    tint: AppColors.greenTint,
    emptyMessage: 'No quizzes available right now.',
  ),
  surveys(
    slug: 'surveys',
    title: 'Survey',
    noun: 'Survey',
    subtitle: 'Complete survey and earn money',
    icon: AppAssets.iconClipboard,
    color: AppColors.purple,
    tint: AppColors.purpleTint,
    emptyMessage: 'No surveys available right now.',
  ),
  campaigns(
    slug: 'campaigns',
    title: 'Campaigns',
    noun: 'Campaign',
    subtitle: 'Complete campaigns and earn money',
    icon: AppAssets.iconTrophy,
    color: AppColors.amber,
    tint: AppColors.amberTint,
    emptyMessage: 'No campaigns available yet.',
  );

  const EarnTaskKind({
    required this.slug,
    required this.title,
    required this.noun,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tint,
    required this.emptyMessage,
  });

  /// Route segment, e.g. `/earn/ads`.
  final String slug;

  /// Tile and app-bar title ("Ads", "Survey").
  final String title;

  /// Singular used in "On going Ad" / "Remaining Ad".
  final String noun;
  final String subtitle;
  final String icon;
  final Color color;
  final Color tint;
  final String emptyMessage;

  static EarnTaskKind? fromSlug(String slug) =>
      values.where((kind) => kind.slug == slug).firstOrNull;
}
