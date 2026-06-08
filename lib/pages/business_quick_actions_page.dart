import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';
import 'business_analytics_page.dart';
import 'business_enquiries_page.dart';
import 'business_events_page.dart';
import 'business_offers_page.dart';
import 'business_products_page.dart';
import 'business_pro_plan_page.dart';
import 'business_profile_editor_page.dart';
import 'public_business_profile_page.dart';

class BusinessQuickActionsPage extends StatefulWidget {
  const BusinessQuickActionsPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessQuickActionsPage> createState() =>
      _BusinessQuickActionsPageState();
}

class _BusinessQuickActionsPageState extends State<BusinessQuickActionsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);
  static const Color _dangerColor = Color(0xFFFB7185);

  final BusinessProfileService _service = BusinessProfileService();

  bool _updatingOpenStatus = false;

  Future<void> _updateOpenStatus(bool open) async {
    if (_updatingOpenStatus) return;

    setState(() => _updatingOpenStatus = true);

    try {
      await _service.updateMyBusinessOpeningStatus(open ? 'open' : 'closed');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            open
                ? 'Your business is now showing as open.'
                : 'Your business is now showing as closed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingOpenStatus = false);
      }
    }
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BusinessProfile?>(
      stream: _service.watchMyBusinessProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? widget.profile;

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: const Text('Business Quick Actions'),
            backgroundColor: _backgroundColor,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _QuickActionsHero(profile: profile),
              const SizedBox(height: 14),
              _OpenClosedCard(
                profile: profile,
                updating: _updatingOpenStatus,
                onChanged: _updateOpenStatus,
              ),
              const SizedBox(height: 16),
              const _SectionHeader(
                icon: Icons.flash_on_outlined,
                title: 'Quick actions',
                subtitle: 'Fast access to the tools you use most.',
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.52,
                children: [
                  _QuickActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit profile',
                    subtitle: 'Details, images, hours',
                    color: _goldColor,
                    onTap: () {
                      _openPage(BusinessProfileEditorPage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.visibility_outlined,
                    title: 'Public profile',
                    subtitle: 'Preview customer view',
                    color: _goldColor,
                    onTap: () {
                      _openPage(PublicBusinessProfilePage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.insights_outlined,
                    title: 'Analytics',
                    subtitle: 'Views and taps',
                    color: _goldColor,
                    locked: !profile.premiumIsActive,
                    onTap: () {
                      _openPage(BusinessAnalyticsPage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Business Pro',
                    subtitle: 'Plan and renewal',
                    color: _goldColor,
                    onTap: () {
                      _openPage(BusinessProPlanPage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.local_offer_outlined,
                    title: 'Add offer',
                    subtitle: 'Deals and discounts',
                    color: _goldColor,
                    locked: !profile.premiumIsActive,
                    onTap: () {
                      _openPage(BusinessOffersPage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.event_outlined,
                    title: 'Add event',
                    subtitle: 'Tournaments and nights',
                    color: _goldColor,
                    locked: !profile.premiumIsActive,
                    onTap: () {
                      _openPage(BusinessEventsPage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Add product',
                    subtitle: 'Showcase stock',
                    color: _goldColor,
                    locked: !profile.premiumIsActive,
                    onTap: () {
                      _openPage(BusinessProductsPage(profile: profile));
                    },
                  ),
                  _QuickActionTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Enquiries',
                    subtitle: 'Customer messages',
                    color: _goldColor,
                    onTap: () {
                      _openPage(BusinessEnquiriesPage(profile: profile));
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionsHero extends StatelessWidget {
  const _QuickActionsHero({required this.profile});

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    final businessName = profile.businessName.trim().isEmpty
        ? 'Your business'
        : profile.businessName.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessQuickActionsPageState._cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: profile.setupIsComplete
              ? _BusinessQuickActionsPageState._successColor
              : _BusinessQuickActionsPageState._goldColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _BusinessQuickActionsPageState._fieldColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _BusinessQuickActionsPageState._borderColor,
              ),
            ),
            child: const Icon(
              Icons.flash_on_outlined,
              color: _BusinessQuickActionsPageState._goldColor,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
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
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.setupIsComplete
                      ? 'Quickly manage the business from one place.'
                      : 'Finish setup, then manage business tools from one place.',
                  style: const TextStyle(
                    color: _BusinessQuickActionsPageState._softTextColor,
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

class _OpenClosedCard extends StatelessWidget {
  const _OpenClosedCard({
    required this.profile,
    required this.updating,
    required this.onChanged,
  });

  final BusinessProfile profile;
  final bool updating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isOpen = profile.isOpenNow ?? profile.openingStatus == 'open';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _BusinessQuickActionsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOpen
              ? _BusinessQuickActionsPageState._successColor
              : _BusinessQuickActionsPageState._dangerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.lock_open_outlined : Icons.lock_outline,
            color: isOpen
                ? _BusinessQuickActionsPageState._successColor
                : _BusinessQuickActionsPageState._dangerColor,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open / closed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOpen
                      ? 'Your business is showing as open.'
                      : 'Your business is showing as closed.',
                  style: const TextStyle(
                    color: _BusinessQuickActionsPageState._softTextColor,
                    height: 1.35,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (updating)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _BusinessQuickActionsPageState._goldColor,
              ),
            )
          else
            Switch.adaptive(
              value: isOpen,
              activeThumbColor: _BusinessQuickActionsPageState._successColor,
              activeTrackColor:
                  _BusinessQuickActionsPageState._successColor.withValues(
                alpha: 0.45,
              ),
              inactiveThumbColor: _BusinessQuickActionsPageState._dangerColor,
              inactiveTrackColor:
                  _BusinessQuickActionsPageState._dangerColor.withValues(
                alpha: 0.35,
              ),
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final borderColor = locked
        ? _BusinessQuickActionsPageState._borderColor
        : color.withValues(alpha: 0.9);
    final iconColor = locked
        ? _BusinessQuickActionsPageState._softTextColor
        : color;

    return Material(
      color: _BusinessQuickActionsPageState._cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _BusinessQuickActionsPageState._fieldColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _BusinessQuickActionsPageState._borderColor,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      locked ? '$subtitle • Pro' : subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BusinessQuickActionsPageState._softTextColor,
                        height: 1.18,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: locked
                    ? _BusinessQuickActionsPageState._softTextColor
                    : _BusinessQuickActionsPageState._goldColor,
                size: 18,
              ),
            ],
          ),
        ),
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
        Icon(icon, color: _BusinessQuickActionsPageState._goldColor, size: 22),
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
                  color: _BusinessQuickActionsPageState._softTextColor,
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
