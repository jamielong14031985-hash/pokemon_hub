import 'package:flutter/material.dart';

import '../models/business_analytics.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class BusinessAnalyticsPage extends StatelessWidget {
  const BusinessAnalyticsPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  String _formatUpdatedAt(BusinessAnalytics analytics) {
    final updatedAt = analytics.updatedAt?.toDate();

    if (updatedAt == null) {
      return 'No activity recorded yet';
    }

    final day = updatedAt.day.toString().padLeft(2, '0');
    final month = updatedAt.month.toString().padLeft(2, '0');
    final hour = updatedAt.hour.toString().padLeft(2, '0');
    final minute = updatedAt.minute.toString().padLeft(2, '0');

    return 'Updated $day/$month/${updatedAt.year} at $hour:$minute';
  }

  Future<void> _confirmResetAnalytics(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Reset analytics?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will reset all analytics counters for this business back to 0. This cannot be undone.',
            style: TextStyle(color: _softTextColor, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await BusinessProfileService().resetBusinessAnalytics(
        businessId: profile.id,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analytics have been reset.')),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reset analytics: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = profile.businessName.trim().isEmpty
        ? 'Business analytics'
        : profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Analytics'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<BusinessAnalytics>(
        stream: BusinessProfileService().watchBusinessAnalytics(profile.id),
        builder: (context, snapshot) {
          final analytics = snapshot.data ?? BusinessAnalytics.empty(profile.id);
          final loading = snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _AnalyticsHeroCard(
                businessName: businessName,
                analytics: analytics,
                updatedText: _formatUpdatedAt(analytics),
                loading: loading,
              ),
              const SizedBox(height: 14),
              _AnalyticsSummaryStrip(analytics: analytics),
              const SizedBox(height: 16),
              const _SectionHeader(
                icon: Icons.insights_outlined,
                title: 'Action breakdown',
                subtitle: 'See what customers are tapping on your profile.',
              ),
              const SizedBox(height: 10),
              _AnalyticsBreakdownCard(analytics: analytics),
              const SizedBox(height: 12),
              const _SmallInfoCard(),
              const SizedBox(height: 12),
              _ResetAnalyticsCard(
                onReset: () => _confirmResetAnalytics(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  const _AnalyticsHeroCard({
    required this.businessName,
    required this.analytics,
    required this.updatedText,
    required this.loading,
  });

  final String businessName;
  final BusinessAnalytics analytics;
  final String updatedText;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BusinessAnalyticsPage._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BusinessAnalyticsPage._goldColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BusinessAnalyticsPage._fieldColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: BusinessAnalyticsPage._borderColor),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BusinessAnalyticsPage._goldColor,
                    ),
                  )
                : const Icon(
                    Icons.insights_outlined,
                    color: BusinessAnalyticsPage._goldColor,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TinyPill(
                      icon: Icons.touch_app_outlined,
                      label: '${analytics.totalEngagement} total actions',
                      highlighted: true,
                    ),
                    _TinyPill(
                      icon: Icons.schedule_outlined,
                      label: updatedText,
                      highlighted: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSummaryStrip extends StatelessWidget {
  const _AnalyticsSummaryStrip({required this.analytics});

  final BusinessAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final contactActions = analytics.mapViews +
        analytics.websiteClicks +
        analytics.phoneClicks;
    final contentActions = analytics.offerViews +
        analytics.eventViews +
        analytics.productViews;

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            icon: Icons.visibility_outlined,
            title: 'Views',
            value: analytics.profileViews,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            icon: Icons.contact_phone_outlined,
            title: 'Contact',
            value: contactActions,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            icon: Icons.inventory_2_outlined,
            title: 'Content',
            value: contentActions,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BusinessAnalyticsPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessAnalyticsPage._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: BusinessAnalyticsPage._goldColor,
            size: 22,
          ),
          const Spacer(),
          Text(
            value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BusinessAnalyticsPage._softTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsBreakdownCard extends StatelessWidget {
  const _AnalyticsBreakdownCard({required this.analytics});

  final BusinessAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final rows = <_AnalyticsRowData>[
      _AnalyticsRowData(
        icon: Icons.visibility_outlined,
        title: 'Profile views',
        subtitle: 'Customers opening the public profile',
        value: analytics.profileViews,
      ),
      _AnalyticsRowData(
        icon: Icons.map_outlined,
        title: 'Map opens',
        subtitle: 'Customers opening the business location',
        value: analytics.mapViews,
      ),
      _AnalyticsRowData(
        icon: Icons.open_in_new,
        title: 'Website taps',
        subtitle: 'Customers opening the website',
        value: analytics.websiteClicks,
      ),
      _AnalyticsRowData(
        icon: Icons.phone_outlined,
        title: 'Phone taps',
        subtitle: 'Customers tapping Contact',
        value: analytics.phoneClicks,
      ),
      _AnalyticsRowData(
        icon: Icons.local_offer_outlined,
        title: 'Offer opens',
        subtitle: 'Customers viewing deals and codes',
        value: analytics.offerViews,
      ),
      _AnalyticsRowData(
        icon: Icons.event_available_outlined,
        title: 'Event opens',
        subtitle: 'Customers viewing shop events',
        value: analytics.eventViews,
      ),
      _AnalyticsRowData(
        icon: Icons.inventory_2_outlined,
        title: 'Product opens',
        subtitle: 'Customers viewing showcased products',
        value: analytics.productViews,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: BusinessAnalyticsPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BusinessAnalyticsPage._borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _AnalyticsRow(data: rows[index]),
            if (index != rows.length - 1)
              const Divider(
                height: 1,
                color: BusinessAnalyticsPage._borderColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsRowData {
  const _AnalyticsRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int value;
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({required this.data});

  final _AnalyticsRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: BusinessAnalyticsPage._fieldColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BusinessAnalyticsPage._borderColor),
            ),
            child: Icon(
              data.icon,
              color: BusinessAnalyticsPage._goldColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BusinessAnalyticsPage._softTextColor,
                    height: 1.2,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: BusinessAnalyticsPage._goldColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: BusinessAnalyticsPage._goldColor),
            ),
            child: Text(
              data.value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoCard extends StatelessWidget {
  const _SmallInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BusinessAnalyticsPage._fieldColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessAnalyticsPage._borderColor),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: BusinessAnalyticsPage._goldColor,
            size: 20,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Analytics update as customers view the profile and tap actions. New businesses may show zeros at first.',
              style: TextStyle(
                color: BusinessAnalyticsPage._softTextColor,
                height: 1.3,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetAnalyticsCard extends StatelessWidget {
  const _ResetAnalyticsCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restart_alt_outlined,
            color: Colors.redAccent,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Reset all analytics counters for this business.',
              style: TextStyle(
                color: BusinessAnalyticsPage._softTextColor,
                height: 1.3,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onReset,
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.icon,
    required this.label,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? BusinessAnalyticsPage._successColor
        : BusinessAnalyticsPage._goldColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.14)
            : BusinessAnalyticsPage._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? color : BusinessAnalyticsPage._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BusinessAnalyticsPage._goldColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BusinessAnalyticsPage._softTextColor,
                  height: 1.3,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
