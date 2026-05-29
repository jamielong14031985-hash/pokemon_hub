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
                backgroundColor: Colors.redAccent,
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
        ? 'Customer enquiries'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Customer Enquiries'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessEnquiry>>(
        stream: _service.watchBusinessEnquiries(widget.profile.id),
        builder: (context, snapshot) {
          final enquiries = snapshot.data ?? const <BusinessEnquiry>[];
          final openCount = enquiries.where((item) => item.status == 'open').length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _EnquiriesHeaderCard(
                businessName: businessName,
                enquiryCount: enquiries.length,
                openCount: openCount,
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (enquiries.isEmpty)
                const _EmptyEnquiriesCard()
              else
                ...enquiries.map(
                  (enquiry) => _EnquiryCard(
                    enquiry: enquiry,
                    formattedDate: _formatDate(enquiry.displayDate),
                    onView: () => _openEnquiryDetails(enquiry),
                    onReply: () => _replyToEnquiry(enquiry),
                    onMarkOpen: () => _updateStatus(enquiry, 'open'),
                    onMarkReplied: () => _updateStatus(enquiry, 'replied'),
                    onMarkClosed: () => _updateStatus(enquiry, 'closed'),
                    onDelete: () => _deleteEnquiry(enquiry),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EnquiriesHeaderCard extends StatelessWidget {
  const _EnquiriesHeaderCard({
    required this.businessName,
    required this.enquiryCount,
    required this.openCount,
  });

  final String businessName;
  final int enquiryCount;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _BusinessEnquiriesPageState._fieldColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: _BusinessEnquiriesPageState._goldColor,
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
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  enquiryCount == 0
                      ? 'No customer enquiries yet.'
                      : '$enquiryCount total • $openCount open',
                  style: const TextStyle(
                    color: _BusinessEnquiriesPageState._softTextColor,
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

class _EnquiryCard extends StatelessWidget {
  const _EnquiryCard({
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

  @override
  Widget build(BuildContext context) {
    final contactEmail = enquiry.senderEmail.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onView,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
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
                const SizedBox(height: 12),
                Text(
                  enquiry.subject.trim().isEmpty
                      ? 'Customer enquiry'
                      : enquiry.subject.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  enquiry.message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BusinessEnquiriesPageState._softTextColor,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _BusinessEnquiriesPageState._goldColor,
                        foregroundColor:
                            _BusinessEnquiriesPageState._backgroundColor,
                      ),
                      onPressed: onView,
                      icon: const Icon(Icons.open_in_full),
                      label: const Text('View details'),
                    ),
                    if (contactEmail.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              _BusinessEnquiriesPageState._goldColor,
                          side: const BorderSide(
                            color: _BusinessEnquiriesPageState._goldColor,
                          ),
                        ),
                        onPressed: onReply,
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text('Reply by email'),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _BusinessEnquiriesPageState._goldColor,
                        side: const BorderSide(
                          color: _BusinessEnquiriesPageState._goldColor,
                        ),
                      ),
                      onPressed: onMarkOpen,
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      label: const Text('Mark open'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _BusinessEnquiriesPageState._successColor,
                        side: const BorderSide(
                          color: _BusinessEnquiriesPageState._successColor,
                        ),
                      ),
                      onPressed: onMarkReplied,
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Mark replied'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _BusinessEnquiriesPageState._softTextColor,
                        side: const BorderSide(
                          color: _BusinessEnquiriesPageState._borderColor,
                        ),
                      ),
                      onPressed: onMarkClosed,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Close'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
