import 'package:flutter/material.dart';

import '../models/community_models.dart';

String communityImageCountLabel(int count) {
  if (count <= 0) return 'No photos';
  if (count == 1) return '1 photo';
  return '$count photos';
}

const List<String> communityMarketStatuses = <String>[
  'All',
  'Available',
  'Pending',
  'Sold',
  'Traded',
  'Found',
];

const List<String> communityCardConditions = <String>[
  'Mint',
  'Near Mint',
  'Excellent',
  'Good',
  'Played',
  'Damaged',
];

const List<String> communityDeliveryMethods = <String>[
  'Post',
  'Meetup',
  'Either',
];

String normalizeCommunityMarketStatus(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'pending':
      return 'Pending';
    case 'sold':
      return 'Sold';
    case 'traded':
      return 'Traded';
    case 'found':
      return 'Found';
    case 'available':
    default:
      return 'Available';
  }
}

Color communityPostAccentColor(CommunityPost post) {
  if (post.isDiscussion) return const Color(0xFF5B3FD6);
  if (post.isForSale) return const Color(0xFF8E1E2E);
  if (post.isWanted) return const Color(0xFF2D7EF7);
  return const Color(0xFF0B6B5B);
}

Color communityMarketStatusColor(String? status) {
  switch (normalizeCommunityMarketStatus(status)) {
    case 'Pending':
      return const Color(0xFFF0A83A);
    case 'Sold':
      return const Color(0xFFB13B59);
    case 'Traded':
      return const Color(0xFF0B6B5B);
    case 'Found':
      return const Color(0xFF54D39A);
    case 'Available':
    default:
      return const Color(0xFF2D7EF7);
  }
}

IconData communityMarketStatusIcon(String? status) {
  switch (normalizeCommunityMarketStatus(status)) {
    case 'Pending':
      return Icons.schedule_outlined;
    case 'Sold':
      return Icons.check_circle_outline_rounded;
    case 'Traded':
      return Icons.swap_horiz_rounded;
    case 'Found':
      return Icons.task_alt_rounded;
    case 'Available':
    default:
      return Icons.storefront_outlined;
  }
}

String communityMarketStatusLabel(CommunityPost post) {
  return post.isDiscussion ? 'Discussion' : post.normalizedMarketStatus;
}
