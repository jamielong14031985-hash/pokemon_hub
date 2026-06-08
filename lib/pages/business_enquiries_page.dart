import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/business_enquiry.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class BusinessEnquiriesPage extends StatefulWidget {
  const BusinessEnquiriesPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessEnquiriesPage> createState() => _BusinessEnquiriesPageState();
}

class _BusinessEnquiriesPageState extends State<BusinessEnquiriesPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);
  static const Color _dangerColor = Color(0xFFFB7185);

  final BusinessProfileService _service = BusinessProfileService();

  String _formatDate(DateTime? value) {
    if (value == null) return '';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }

  Future<void> _openEnquiryDetails(BusinessEnquiry enquiry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _BusinessEnquiryDetailsPage(
          enquiry: enquiry,
          formattedDate: _formatDate(enquiry.displayDate),
          onReply: () => _replyToEnquiry(enquiry),
        ),
      ),
    );
  }

  Future<void> _replyToEnquiry(BusinessEnquiry enquiry) async {
    final email = enquiry.senderEmail.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This enquiry does not include a contact email.'),
        ),
      );
      return;
    }

    final subject = enquiry.subject.trim().isEmpty
        ? 'Re: Customer enquiry'
        : 'Re: ${enquiry.subject.trim()}';

    final body = [
      '',
      '',
      '--- Original enquiry ---',
      enquiry.message.trim(),
    ].join('\n');

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        'subject': subject,
        'body': body,
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your email app.')),
      );
      return;
    }

    try {
      await _service.updateBusinessEnquiryStatus(
        businessId: widget.profile.id,
        enquiryId: enquiry.id,
        status: 'replied',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email opened. Enquiry marked as replied.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email opened, but status was not updated: $error'),
        ),
      );
    }
  }

  Future<void> _updateStatus(BusinessEnquiry enquiry, String status) async {
    try {
      await _service.updateBusinessEnquiryStatus(
        businessId: widget.profile.id,
        enquiryId: enquiry.id,
        status: status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as ${status.toLowerCase()}.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update enquiry: $error')),
      );
    }
  }

  Future<void> _deleteEnquiry(BusinessEnquiry enquiry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete enquiry?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete "${enquiry.subject}".',
            style: const TextStyle(
              color: _softTextColor,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _dangerColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _service.deleteBusinessEnquiry(
        businessId: widget.profile.id,
        enquiryId: enquiry.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry deleted.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete enquiry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'Your business'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Enquiries'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessEnquiry>>(
        stream: _service.watchBusinessEnquiries(widget.profile.id),
        builder: (context, snapshot) {
          final enquiries = snapshot.data ?? const <BusinessEnquiry>[];
          final openCount =
              enquiries.where((item) => item.status == 'open').length;

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingList();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _PageHeroCard(
                icon: Icons.mark_email_unread_outlined,
                title: 'Enquiries',
                subtitle: businessName,
                totalCount: enquiries.length,
                activeCount: openCount,
                activeLabel: 'open',
                totalLabel: 'total',
              ),
              const SizedBox(height: 16),
              const _SectionHeader(
                icon: Icons.tune_outlined,
                title: 'Current enquiries',
                subtitle: 'View and manage customer messages from your public profile.',
              ),
              const SizedBox(height: 10),
              if (enquiries.isEmpty)
                const _EmptyEnquiriesCard()
              else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 0.72,
                  children: enquiries.map(
                    (enquiry) {
                      return _EnquiryGridCard(
                        enquiry: enquiry,
                        formattedDate: _formatDate(enquiry.displayDate),
                        onView: () => _openEnquiryDetails(enquiry),
                        onReply: () => _replyToEnquiry(enquiry),
                        onMarkOpen: () => _updateStatus(enquiry, 'open'),
                        onMarkReplied: () =>
                            _updateStatus(enquiry, 'replied'),
                        onMarkClosed: () => _updateStatus(enquiry, 'closed'),
                        onDelete: () => _deleteEnquiry(enquiry),
                      );
                    },
                  ).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PageHeroCard extends StatelessWidget {
  const _PageHeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.totalCount,
    required this.activeCount,
    required this.activeLabel,
    required this.totalLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int totalCount;
  final int activeCount;
  final String activeLabel;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BusinessEnquiriesPageState._goldColor),
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
          Icon(icon, color: _BusinessEnquiriesPageState._goldColor, size: 31),
          const SizedBox(width: 12),
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
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BusinessEnquiriesPageState._softTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TinyPill(
                      icon: Icons.mark_email_unread_outlined,
                      label: '$activeCount $activeLabel',
                      color: activeCount > 0
                          ? _BusinessEnquiriesPageState._successColor
                          : _BusinessEnquiriesPageState._goldColor,
                      highlighted: activeCount > 0,
                    ),
                    _TinyPill(
                      icon: Icons.list_alt_outlined,
                      label: '$totalCount $totalLabel',
                      color: _BusinessEnquiriesPageState._goldColor,
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

class _EnquiryGridCard extends StatelessWidget {
  const _EnquiryGridCard({
    required this.enquiry,
    required this.formattedDate,
    required this.onView,
    required this.onReply,
    required this.onMarkOpen,
    required this.onMarkReplied,
    required this.onMarkClosed,
    required this.onDelete,
  });

  final BusinessEnquiry enquiry;
  final String formattedDate;
  final VoidCallback onView;
  final VoidCallback onReply;
  final VoidCallback onMarkOpen;
  final VoidCallback onMarkReplied;
  final VoidCallback onMarkClosed;
  final VoidCallback onDelete;

  Color _statusColor() {
    return switch (enquiry.status) {
      'open' => _BusinessEnquiriesPageState._goldColor,
      'replied' => _BusinessEnquiriesPageState._successColor,
      'closed' => _BusinessEnquiriesPageState._softTextColor,
      _ => _BusinessEnquiriesPageState._goldColor,
    };
  }

  IconData _statusIcon() {
    return switch (enquiry.status) {
      'open' => Icons.mark_email_unread_outlined,
      'replied' => Icons.reply_outlined,
      'closed' => Icons.check_circle_outline,
      _ => Icons.mark_email_unread_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final subject = enquiry.subject.trim().isEmpty
        ? 'Customer enquiry'
        : enquiry.subject.trim();
    final senderName = enquiry.displaySenderName.trim();
    final hasDate = formattedDate.trim().isNotEmpty;
    final hasMessage = enquiry.message.trim().isNotEmpty;
    final hasEmail = enquiry.senderEmail.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enquiry.status == 'open'
              ? _BusinessEnquiriesPageState._goldColor
              : _BusinessEnquiriesPageState._borderColor,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 82,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: _BusinessEnquiriesPageState._fieldColor,
                    child: const Center(
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        color: _BusinessEnquiriesPageState._goldColor,
                        size: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7,
                    bottom: 7,
                    child: _TinyPill(
                      icon: _statusIcon(),
                      label: enquiry.statusLabel,
                      color: _statusColor(),
                      highlighted: enquiry.status != 'closed',
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: _EnquiryMenuButton(
                      hasEmail: hasEmail,
                      onReply: onReply,
                      onMarkOpen: onMarkOpen,
                      onMarkReplied: onMarkReplied,
                      onMarkClosed: onMarkClosed,
                      onDelete: onDelete,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BusinessEnquiriesPageState._goldColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _TinyPill(
                          icon: Icons.help_outline,
                          label: enquiry.enquiryTypeLabel,
                          color: _BusinessEnquiriesPageState._goldColor,
                          highlighted: false,
                        ),
                        if (hasDate)
                          _TinyPill(
                            icon: Icons.schedule_outlined,
                            label: formattedDate,
                            color: _BusinessEnquiriesPageState._goldColor,
                            highlighted: false,
                          ),
                      ],
                    ),
                    if (hasMessage) ...[
                      const SizedBox(height: 6),
                      Text(
                        enquiry.message.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BusinessEnquiriesPageState._softTextColor,
                          height: 1.25,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: _SmallActionButton(
                        icon: Icons.open_in_full,
                        label: 'Open',
                        onPressed: onView,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnquiryMenuButton extends StatelessWidget {
  const _EnquiryMenuButton({
    required this.hasEmail,
    required this.onReply,
    required this.onMarkOpen,
    required this.onMarkReplied,
    required this.onMarkClosed,
    required this.onDelete,
  });

  final bool hasEmail;
  final VoidCallback onReply;
  final VoidCallback onMarkOpen;
  final VoidCallback onMarkReplied;
  final VoidCallback onMarkClosed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Enquiry options',
      padding: EdgeInsets.zero,
      color: _BusinessEnquiriesPageState._cardColor,
      iconColor: _BusinessEnquiriesPageState._goldColor,
      iconSize: 20,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _BusinessEnquiriesPageState._borderColor),
      ),
      onSelected: (value) {
        if (value == 'reply') {
          onReply();
        } else if (value == 'open') {
          onMarkOpen();
        } else if (value == 'replied') {
          onMarkReplied();
        } else if (value == 'closed') {
          onMarkClosed();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) {
        return [
          if (hasEmail)
            const PopupMenuItem<String>(
              value: 'reply',
              child: _MenuItemRow(
                icon: Icons.reply_outlined,
                label: 'Reply',
                color: _BusinessEnquiriesPageState._goldColor,
              ),
            ),
          const PopupMenuItem<String>(
            value: 'open',
            child: _MenuItemRow(
              icon: Icons.mark_email_unread_outlined,
              label: 'Mark open',
              color: _BusinessEnquiriesPageState._goldColor,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'replied',
            child: _MenuItemRow(
              icon: Icons.reply_outlined,
              label: 'Mark replied',
              color: _BusinessEnquiriesPageState._successColor,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'closed',
            child: _MenuItemRow(
              icon: Icons.check_circle_outline,
              label: 'Close',
              color: _BusinessEnquiriesPageState._softTextColor,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: _MenuItemRow(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: _BusinessEnquiriesPageState._dangerColor,
            ),
          ),
        ];
      },
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: color == _BusinessEnquiriesPageState._softTextColor
                ? Colors.white
                : color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _BusinessEnquiriesPageState._goldColor,
        side: const BorderSide(color: _BusinessEnquiriesPageState._goldColor),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      onPressed: onPressed,
    );
  }
}

class _BusinessEnquiryDetailsPage extends StatelessWidget {
  const _BusinessEnquiryDetailsPage({
    required this.enquiry,
    required this.formattedDate,
    required this.onReply,
  });

  final BusinessEnquiry enquiry;
  final String formattedDate;
  final VoidCallback onReply;

  Color _statusColor() {
    return switch (enquiry.status) {
      'open' => _BusinessEnquiriesPageState._goldColor,
      'replied' => _BusinessEnquiriesPageState._successColor,
      'closed' => _BusinessEnquiriesPageState._softTextColor,
      _ => _BusinessEnquiriesPageState._goldColor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final contactEmail = enquiry.senderEmail.trim();

    return Scaffold(
      backgroundColor: _BusinessEnquiriesPageState._backgroundColor,
      appBar: AppBar(
        title: const Text('Enquiry details'),
        backgroundColor: _BusinessEnquiriesPageState._backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _BusinessEnquiriesPageState._cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _BusinessEnquiriesPageState._borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _EnquiryBadge(
                        icon: Icons.help_outline,
                        label: enquiry.enquiryTypeLabel,
                        color: _BusinessEnquiriesPageState._goldColor,
                      ),
                      _EnquiryBadge(
                        icon: Icons.circle,
                        label: enquiry.statusLabel,
                        color: _statusColor(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    enquiry.subject.trim().isEmpty
                        ? 'Customer enquiry'
                        : enquiry.subject.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    enquiry.message.trim(),
                    style: const TextStyle(
                      color: _BusinessEnquiriesPageState._softTextColor,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.person_outline,
                    text: enquiry.displaySenderName,
                  ),
                  if (contactEmail.isNotEmpty)
                    _InfoRow(
                      icon: Icons.alternate_email,
                      text: contactEmail,
                    ),
                  if (formattedDate.isNotEmpty)
                    _InfoRow(
                      icon: Icons.schedule_outlined,
                      text: formattedDate,
                    ),
                  const SizedBox(height: 18),
                  if (contactEmail.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _BusinessEnquiriesPageState._goldColor,
                          foregroundColor:
                              _BusinessEnquiriesPageState._backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: onReply,
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text(
                          'Reply by email',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _BusinessEnquiriesPageState._fieldColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _BusinessEnquiriesPageState._borderColor,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: _BusinessEnquiriesPageState._goldColor,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'This enquiry does not include a contact email, so you cannot reply by email from the app.',
                              style: TextStyle(
                                color:
                                    _BusinessEnquiriesPageState._softTextColor,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEnquiriesCard extends StatelessWidget {
  const _EmptyEnquiriesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.mail_outline,
            color: _BusinessEnquiriesPageState._goldColor,
            size: 46,
          ),
          SizedBox(height: 12),
          Text(
            'No enquiries yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When users contact this business from the app, their enquiries will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _BusinessEnquiriesPageState._softTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:
          CircularProgressIndicator(color: _BusinessEnquiriesPageState._goldColor),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _BusinessEnquiriesPageState._goldColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(
                color: _BusinessEnquiriesPageState._softTextColor,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnquiryBadge extends StatelessWidget {
  const _EnquiryBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
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
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
    required this.color,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.14)
            : _BusinessEnquiriesPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? color : _BusinessEnquiriesPageState._borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
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
        Icon(icon, color: _BusinessEnquiriesPageState._goldColor, size: 22),
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
                  color: _BusinessEnquiriesPageState._softTextColor,
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
