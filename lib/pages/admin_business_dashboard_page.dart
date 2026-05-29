import 'package:flutter/material.dart';

import '../models/business_enquiry.dart';
import '../models/business_pro_request.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import 'admin_business_pro_requests_page.dart';

class AdminBusinessDashboardPage extends StatelessWidget {
  const AdminBusinessDashboardPage({super.key});

  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);
  static const Color _dangerColor = Color(0xFFFB7185);
  static const Color _warningColor = Color(0xFFFBBF24);

  String _formatDate(DateTime? value) {
    if (value == null) return '';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final service = BusinessProfileService();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Business Dashboard'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Business Pro requests',
            icon: const Icon(Icons.mark_email_unread_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminBusinessProRequestsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<bool>(
        stream: service.watchCurrentUserIsAdminOrModerator(),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _goldColor),
            );
          }

          if (adminSnapshot.data != true) {
            return const _NoDashboardAccess();
          }

          return StreamBuilder<List<BusinessProfile>>(
            stream: service.watchAllBusinessProfiles(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.hasError) {
                return _DashboardError(error: profileSnapshot.error.toString());
              }

              if (!profileSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _goldColor),
                );
              }

              final profiles =
                  profileSnapshot.data ?? const <BusinessProfile>[];

              return StreamBuilder<List<BusinessProRequest>>(
                stream: service.watchAllBusinessProRequests(),
                builder: (context, requestSnapshot) {
                  final requests =
                      requestSnapshot.data ?? const <BusinessProRequest>[];

                  return StreamBuilder<List<BusinessEnquiry>>(
                    stream: service.watchAllBusinessEnquiriesForAdmin(),
                    builder: (context, enquirySnapshot) {
                      final enquiries =
                          enquirySnapshot.data ?? const <BusinessEnquiry>[];

                      final pendingProfiles = profiles
                          .where((profile) => profile.status != 'approved')
                          .length;
                      final activePro = profiles
                          .where((profile) => profile.premiumIsActive)
                          .length;
                      final expiredPro = profiles
                          .where((profile) => profile.premiumIsExpired)
                          .length;
                      final expiringSoon = profiles
                          .where((profile) => profile.premiumExpiresSoon)
                          .length;
                      final pendingProRequests =
                          requests.where((request) => request.isPending).length;
                      final openEnquiries = enquiries
                          .where((enquiry) => enquiry.status == 'open')
                          .length;

                      final urgentTotal = pendingProfiles +
                          pendingProRequests +
                          openEnquiries +
                          expiredPro +
                          expiringSoon;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        children: [
                          _DashboardHeroCard(
                            totalBusinesses: profiles.length,
                            urgentTotal: urgentTotal,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _DashboardMetricCard(
                                icon: Icons.storefront_outlined,
                                title: 'Total businesses',
                                value: profiles.length.toString(),
                                subtitle: 'All business profiles',
                                color: _goldColor,
                              ),
                              _DashboardMetricCard(
                                icon: Icons.pending_actions_outlined,
                                title: 'Pending profiles',
                                value: pendingProfiles.toString(),
                                subtitle: 'Need approval review',
                                color: pendingProfiles > 0
                                    ? _warningColor
                                    : _softTextColor,
                              ),
                              _DashboardMetricCard(
                                icon: Icons.workspace_premium_outlined,
                                title: 'Active Pro',
                                value: activePro.toString(),
                                subtitle: 'Currently active',
                                color: _successColor,
                              ),
                              _DashboardMetricCard(
                                icon: Icons.contact_support_outlined,
                                title: 'Pro requests',
                                value: pendingProRequests.toString(),
                                subtitle: 'Pending admin response',
                                color: pendingProRequests > 0
                                    ? _goldColor
                                    : _softTextColor,
                              ),
                              _DashboardMetricCard(
                                icon: Icons.mark_email_unread_outlined,
                                title: 'Open enquiries',
                                value: openEnquiries.toString(),
                                subtitle: 'Customer messages',
                                color: openEnquiries > 0
                                    ? _goldColor
                                    : _softTextColor,
                              ),
                              _DashboardMetricCard(
                                icon: Icons.schedule_outlined,
                                title: 'Expiring soon',
                                value: expiringSoon.toString(),
                                subtitle: 'Pro expires within 14 days',
                                color: expiringSoon > 0
                                    ? _warningColor
                                    : _softTextColor,
                              ),
                              _DashboardMetricCard(
                                icon: Icons.lock_clock_outlined,
                                title: 'Expired Pro',
                                value: expiredPro.toString(),
                                subtitle: 'Needs renewal',
                                color: expiredPro > 0
                                    ? _dangerColor
                                    : _softTextColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            icon: Icons.priority_high_outlined,
                            title: 'Needs attention',
                            subtitle:
                                'Quick view of the most important admin items.',
                          ),
                          const SizedBox(height: 10),
                          _AttentionCard(
                            pendingProfiles: pendingProfiles,
                            pendingProRequests: pendingProRequests,
                            openEnquiries: openEnquiries,
                            expiringSoon: expiringSoon,
                            expiredPro: expiredPro,
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Latest Pro requests',
                            subtitle:
                                'Newest Business Pro or renewal requests from shops.',
                          ),
                          const SizedBox(height: 10),
                          _LatestRequestsList(
                            requests: requests,
                            formatDate: _formatDate,
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            icon: Icons.mail_outline,
                            title: 'Latest customer enquiries',
                            subtitle:
                                'Open customer questions sent to businesses.',
                          ),
                          const SizedBox(height: 10),
                          _LatestEnquiriesList(
                            enquiries: enquiries,
                            formatDate: _formatDate,
                          ),
                          const SizedBox(height: 18),
                          _SectionHeader(
                            icon: Icons.event_busy_outlined,
                            title: 'Pro expiry watch',
                            subtitle:
                                'Business Pro accounts that are expiring soon or expired.',
                          ),
                          const SizedBox(height: 10),
                          _ExpiryWatchList(profiles: profiles),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.totalBusinesses,
    required this.urgentTotal,
  });

  final int totalBusinesses;
  final int urgentTotal;

  @override
  Widget build(BuildContext context) {
    final hasUrgent = urgentTotal > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminBusinessDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: hasUrgent
              ? AdminBusinessDashboardPage._goldColor
              : AdminBusinessDashboardPage._borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AdminBusinessDashboardPage._fieldColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AdminBusinessDashboardPage._borderColor,
                  ),
                ),
                child: const Icon(
                  Icons.dashboard_customize_outlined,
                  color: AdminBusinessDashboardPage._goldColor,
                  size: 32,
                ),
              ),
              if (hasUrgent)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AdminBusinessDashboardPage._dangerColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      urgentTotal > 99 ? '99+' : urgentTotal.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business admin overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasUrgent
                      ? '$urgentTotal item${urgentTotal == 1 ? '' : 's'} need admin attention.'
                      : '$totalBusinesses business profile${totalBusinesses == 1 ? '' : 's'} saved. No urgent items.',
                  style: const TextStyle(
                    color: AdminBusinessDashboardPage._softTextColor,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminBusinessDashboardPage._cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color == AdminBusinessDashboardPage._softTextColor
                ? AdminBusinessDashboardPage._borderColor
                : color,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AdminBusinessDashboardPage._softTextColor,
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.pendingProfiles,
    required this.pendingProRequests,
    required this.openEnquiries,
    required this.expiringSoon,
    required this.expiredPro,
  });

  final int pendingProfiles;
  final int pendingProRequests;
  final int openEnquiries;
  final int expiringSoon;
  final int expiredPro;

  @override
  Widget build(BuildContext context) {
    final items = <_AttentionItem>[
      _AttentionItem(
        icon: Icons.pending_actions_outlined,
        label: 'Pending business profiles',
        count: pendingProfiles,
      ),
      _AttentionItem(
        icon: Icons.contact_support_outlined,
        label: 'Pending Pro requests',
        count: pendingProRequests,
      ),
      _AttentionItem(
        icon: Icons.mark_email_unread_outlined,
        label: 'Open customer enquiries',
        count: openEnquiries,
      ),
      _AttentionItem(
        icon: Icons.schedule_outlined,
        label: 'Pro expiring soon',
        count: expiringSoon,
      ),
      _AttentionItem(
        icon: Icons.lock_clock_outlined,
        label: 'Expired Pro accounts',
        count: expiredPro,
      ),
    ];

    final hasAny = items.any((item) => item.count > 0);

    if (!hasAny) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminBusinessDashboardPage._cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AdminBusinessDashboardPage._borderColor),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AdminBusinessDashboardPage._successColor,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Everything looks clear. There are no urgent business admin items.',
                style: TextStyle(
                  color: AdminBusinessDashboardPage._softTextColor,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminBusinessDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AdminBusinessDashboardPage._goldColor),
      ),
      child: Column(
        children: items
            .where((item) => item.count > 0)
            .map((item) => _AttentionRow(item: item))
            .toList(),
      ),
    );
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            item.icon,
            color: AdminBusinessDashboardPage._goldColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _SmallCountBadge(count: item.count),
        ],
      ),
    );
  }
}

class _LatestRequestsList extends StatelessWidget {
  const _LatestRequestsList({
    required this.requests,
    required this.formatDate,
  });

  final List<BusinessProRequest> requests;
  final String Function(DateTime? value) formatDate;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyMiniState(
        icon: Icons.workspace_premium_outlined,
        message: 'No Business Pro requests yet.',
      );
    }

    final latest = requests.take(5).toList();

    return Column(
      children: latest
          .map(
            (request) => _MiniInfoCard(
              icon: Icons.workspace_premium_outlined,
              iconColor: request.isPending
                  ? AdminBusinessDashboardPage._goldColor
                  : request.isApproved
                      ? AdminBusinessDashboardPage._successColor
                      : AdminBusinessDashboardPage._dangerColor,
              title: request.businessName.trim().isEmpty
                  ? 'Business Pro request'
                  : request.businessName.trim(),
              subtitle:
                  '${request.requestTypeLabel} • ${request.statusLabel}${formatDate(request.displayDate).isEmpty ? '' : ' • ${formatDate(request.displayDate)}'}',
              body: request.message,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminBusinessProRequestsPage(),
                  ),
                );
              },
            ),
          )
          .toList(),
    );
  }
}

class _LatestEnquiriesList extends StatelessWidget {
  const _LatestEnquiriesList({
    required this.enquiries,
    required this.formatDate,
  });

  final List<BusinessEnquiry> enquiries;
  final String Function(DateTime? value) formatDate;

  @override
  Widget build(BuildContext context) {
    final open = enquiries
        .where((enquiry) => enquiry.status == 'open')
        .take(5)
        .toList();

    if (open.isEmpty) {
      return const _EmptyMiniState(
        icon: Icons.mail_outline,
        message: 'No open customer enquiries.',
      );
    }

    return Column(
      children: open
          .map(
            (enquiry) => _MiniInfoCard(
              icon: Icons.mail_outline,
              iconColor: AdminBusinessDashboardPage._goldColor,
              title: enquiry.businessName.trim().isEmpty
                  ? 'Customer enquiry'
                  : enquiry.businessName.trim(),
              subtitle:
                  '${enquiry.enquiryTypeLabel}${formatDate(enquiry.displayDate).isEmpty ? '' : ' • ${formatDate(enquiry.displayDate)}'}',
              body: enquiry.subject.trim().isEmpty
                  ? enquiry.message
                  : enquiry.subject.trim(),
            ),
          )
          .toList(),
    );
  }
}

class _ExpiryWatchList extends StatelessWidget {
  const _ExpiryWatchList({required this.profiles});

  final List<BusinessProfile> profiles;

  @override
  Widget build(BuildContext context) {
    final watchedProfiles = profiles
        .where(
          (profile) => profile.premiumIsExpired || profile.premiumExpiresSoon,
        )
        .toList();

    watchedProfiles.sort((a, b) {
      final aTime = a.premiumExpiresAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.premiumExpiresAt?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });

    if (watchedProfiles.isEmpty) {
      return const _EmptyMiniState(
        icon: Icons.check_circle_outline,
        message: 'No Pro accounts are expiring soon or expired.',
      );
    }

    return Column(
      children: watchedProfiles.take(6).map((profile) {
        return _MiniInfoCard(
          icon: profile.premiumIsExpired
              ? Icons.lock_clock_outlined
              : Icons.schedule_outlined,
          iconColor: profile.premiumIsExpired
              ? AdminBusinessDashboardPage._dangerColor
              : AdminBusinessDashboardPage._warningColor,
          title: profile.businessName.trim().isEmpty
              ? 'Business'
              : profile.businessName.trim(),
          subtitle: profile.premiumStatusLabel,
          body: profile.displayLocation.isEmpty
              ? 'No location saved'
              : profile.displayLocation,
        );
      }).toList(),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminBusinessDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminBusinessDashboardPage._borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AdminBusinessDashboardPage._softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    body.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AdminBusinessDashboardPage._softTextColor,
                      height: 1.3,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: AdminBusinessDashboardPage._goldColor,
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _SmallCountBadge extends StatelessWidget {
  const _SmallCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AdminBusinessDashboardPage._dangerColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyMiniState extends StatelessWidget {
  const _EmptyMiniState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminBusinessDashboardPage._cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminBusinessDashboardPage._borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminBusinessDashboardPage._goldColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AdminBusinessDashboardPage._softTextColor,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
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
        Icon(icon, color: AdminBusinessDashboardPage._goldColor, size: 22),
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
                  color: AdminBusinessDashboardPage._softTextColor,
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

class _NoDashboardAccess extends StatelessWidget {
  const _NoDashboardAccess();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Text(
          'Only admins and moderators can view the business dashboard.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AdminBusinessDashboardPage._softTextColor,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          'Could not load dashboard: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AdminBusinessDashboardPage._softTextColor,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
