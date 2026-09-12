import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  String _safeIdPart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  String _conversationIdForEnquiry({
    required String businessId,
    required String enquiryId,
    required String userAId,
    required String userBId,
  }) {
    final participants = <String>[
      _safeIdPart(userAId),
      _safeIdPart(userBId),
    ]..sort();

    return 'business_enquiry_${_safeIdPart(businessId)}_${_safeIdPart(enquiryId)}_${participants[0]}_${participants[1]}';
  }

  String _relatedTitleForEnquiry(BusinessEnquiry enquiry) {
    final subject = enquiry.subject.trim();
    if (subject.isNotEmpty) {
      return '${enquiry.enquiryTypeLabel}: $subject';
    }
    return '${enquiry.enquiryTypeLabel} with ${widget.profile.businessName.trim().isEmpty ? 'this business' : widget.profile.businessName.trim()}';
  }

  Future<void> _openEnquiryDetails(BusinessEnquiry enquiry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _BusinessEnquiryDetailsPage(
          enquiry: enquiry,
          formattedDate: _formatDate(enquiry.displayDate),
          onMessage: () => _openInAppMessage(enquiry),
        ),
      ),
    );
  }

  Future<void> _openInAppMessage(BusinessEnquiry enquiry) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showMessage('You must be signed in to message this customer.');
      return;
    }

    final customerUid = enquiry.senderUid.trim();
    if (customerUid.isEmpty) {
      _showMessage('This enquiry is missing the customer app account, so it cannot be messaged in app.');
      return;
    }

    if (customerUid == currentUser.uid) {
      _showMessage('You cannot message yourself about this enquiry.');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'PocketChase Business'
        : widget.profile.businessName.trim();
    final customerName = enquiry.displaySenderName.trim().isEmpty
        ? 'PocketChase user'
        : enquiry.displaySenderName.trim();
    final relatedTitle = _relatedTitleForEnquiry(enquiry);
    final relatedId =
        'business_enquiry_${_safeIdPart(widget.profile.id)}_${_safeIdPart(enquiry.id)}';
    final conversationId = _conversationIdForEnquiry(
      businessId: widget.profile.id,
      enquiryId: enquiry.id,
      userAId: currentUser.uid,
      userBId: customerUid,
    );

    final conversationData = <String, Object?>{
      'participants': <String>[currentUser.uid, customerUid],
      'participantNames': <String, String>{
        currentUser.uid: businessName,
        customerUid: customerName,
      },
      'relatedPostId': relatedId,
      'relatedPostTitle': relatedTitle,
      'businessId': widget.profile.id,
      'businessName': businessName,
      'businessEnquiryId': enquiry.id,
      'businessEnquiryType': enquiry.enquiryType,
      'createdAtMs': now,
      'updatedAtMs': now,
      'lastMessage': '',
      'lastSenderId': '',
    };

    try {
      await FirebaseFirestore.instance
          .collection('community_private_conversations')
          .doc(conversationId)
          .set(conversationData, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Could not open in-app messages. The customer may need to complete their profile/community access.',
      );
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _BusinessEnquiryChatPage(
          conversationId: conversationId,
          currentUserId: currentUser.uid,
          currentUserName: businessName,
          otherUserId: customerUid,
          otherUserName: customerName,
          relatedPostId: relatedId,
          relatedPostTitle: relatedTitle,
        ),
      ),
    );
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          final repliedCount =
              enquiries.where((item) => item.status == 'replied').length;
          final closedCount =
              enquiries.where((item) => item.status == 'closed').length;

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingList();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _PageHeroCard(
                businessName: businessName,
                totalCount: enquiries.length,
                openCount: openCount,
                repliedCount: repliedCount,
                closedCount: closedCount,
              ),
              const SizedBox(height: 16),
              const _SectionHeader(
                icon: Icons.forum_outlined,
                title: 'Current enquiries',
                subtitle:
                    'View customer messages, reply inside PocketChase, and update enquiry status.',
              ),
              const SizedBox(height: 10),
              if (enquiries.isEmpty)
                const _EmptyEnquiriesCard()
              else
                ...enquiries.map(
                  (enquiry) {
                    return _EnquiryListCard(
                      enquiry: enquiry,
                      formattedDate: _formatDate(enquiry.displayDate),
                      onView: () => _openEnquiryDetails(enquiry),
                      onMessage: () => _openInAppMessage(enquiry),
                      onMarkOpen: () => _updateStatus(enquiry, 'open'),
                      onMarkReplied: () => _updateStatus(enquiry, 'replied'),
                      onMarkClosed: () => _updateStatus(enquiry, 'closed'),
                      onDelete: () => _deleteEnquiry(enquiry),
                    );
                  },
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
    required this.businessName,
    required this.totalCount,
    required this.openCount,
    required this.repliedCount,
    required this.closedCount,
  });

  final String businessName;
  final int totalCount;
  final int openCount;
  final int repliedCount;
  final int closedCount;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _BusinessEnquiriesPageState._fieldColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _BusinessEnquiriesPageState._borderColor,
                  ),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: _BusinessEnquiriesPageState._goldColor,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enquiries',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BusinessEnquiriesPageState._softTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyPill(
                icon: Icons.mark_email_unread_outlined,
                label: '$openCount open',
                color: openCount > 0
                    ? _BusinessEnquiriesPageState._successColor
                    : _BusinessEnquiriesPageState._goldColor,
                highlighted: openCount > 0,
              ),
              _TinyPill(
                icon: Icons.reply_outlined,
                label: '$repliedCount replied',
                color: _BusinessEnquiriesPageState._successColor,
                highlighted: false,
              ),
              _TinyPill(
                icon: Icons.check_circle_outline,
                label: '$closedCount closed',
                color: _BusinessEnquiriesPageState._softTextColor,
                highlighted: false,
              ),
              _TinyPill(
                icon: Icons.list_alt_outlined,
                label: '$totalCount total',
                color: _BusinessEnquiriesPageState._goldColor,
                highlighted: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnquiryListCard extends StatelessWidget {
  const _EnquiryListCard({
    required this.enquiry,
    required this.formattedDate,
    required this.onView,
    required this.onMessage,
    required this.onMarkOpen,
    required this.onMarkReplied,
    required this.onMarkClosed,
    required this.onDelete,
  });

  final BusinessEnquiry enquiry;
  final String formattedDate;
  final VoidCallback onView;
  final VoidCallback onMessage;
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
    final message = enquiry.message.trim();
    final canMessageInApp = enquiry.senderUid.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: enquiry.status == 'open'
                    ? _BusinessEnquiriesPageState._goldColor
                    : _BusinessEnquiriesPageState._borderColor,
                width: enquiry.status == 'open' ? 1.4 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    color: _BusinessEnquiriesPageState._fieldColor,
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _BusinessEnquiriesPageState._goldColor
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _statusIcon(),
                            color: _BusinessEnquiriesPageState._goldColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TinyPill(
                                icon: _statusIcon(),
                                label: enquiry.statusLabel,
                                color: _statusColor(),
                                highlighted: enquiry.status != 'closed',
                              ),
                              _TinyPill(
                                icon: Icons.help_outline,
                                label: enquiry.enquiryTypeLabel,
                                color: _BusinessEnquiriesPageState._goldColor,
                                highlighted: false,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More options',
                          color: _BusinessEnquiriesPageState._cardColor,
                          iconColor: _BusinessEnquiriesPageState._goldColor,
                          onSelected: (value) {
                            switch (value) {
                              case 'open':
                                onMarkOpen();
                                break;
                              case 'replied':
                                onMarkReplied();
                                break;
                              case 'closed':
                                onMarkClosed();
                                break;
                              case 'delete':
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'open',
                              child: _MenuText('Mark open'),
                            ),
                            PopupMenuItem<String>(
                              value: 'replied',
                              child: _MenuText('Mark replied'),
                            ),
                            PopupMenuItem<String>(
                              value: 'closed',
                              child: _MenuText('Mark closed'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: _MenuText('Delete enquiry', danger: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _InfoRow(
                          icon: Icons.person_outline,
                          text: senderName,
                          dense: true,
                        ),
                        if (hasDate)
                          _InfoRow(
                            icon: Icons.schedule_outlined,
                            text: formattedDate,
                            dense: true,
                          ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(
                            message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _BusinessEnquiriesPageState._softTextColor,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      _BusinessEnquiriesPageState._goldColor,
                                  foregroundColor:
                                      _BusinessEnquiriesPageState
                                          ._backgroundColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: canMessageInApp ? onMessage : null,
                                icon: const Icon(Icons.forum_outlined),
                                label: const Text(
                                  'Message',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: onView,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      _BusinessEnquiriesPageState._goldColor,
                                  side: const BorderSide(
                                    color: _BusinessEnquiriesPageState._goldColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text(
                                  'Open',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!canMessageInApp) ...[
                          const SizedBox(height: 9),
                          const _SmallNotice(
                            text:
                                'This enquiry was saved without an app user id, so in-app messaging is not available for it.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
    required this.onMessage,
  });

  final BusinessEnquiry enquiry;
  final String formattedDate;
  final VoidCallback onMessage;

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
    final canMessageInApp = enquiry.senderUid.trim().isNotEmpty;

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
              decoration: BoxDecoration(
                color: _BusinessEnquiriesPageState._cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: enquiry.status == 'open'
                      ? _BusinessEnquiriesPageState._goldColor
                      : _BusinessEnquiriesPageState._borderColor,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      color: _BusinessEnquiriesPageState._fieldColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TinyPill(
                                icon: _statusIcon(),
                                label: enquiry.statusLabel,
                                color: _statusColor(),
                                highlighted: enquiry.status != 'closed',
                              ),
                              _TinyPill(
                                icon: Icons.help_outline,
                                label: enquiry.enquiryTypeLabel,
                                color: _BusinessEnquiriesPageState._goldColor,
                                highlighted: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            subject,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Message',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            enquiry.message.trim().isEmpty
                                ? 'No message included.'
                                : enquiry.message.trim(),
                            style: const TextStyle(
                              color: _BusinessEnquiriesPageState._softTextColor,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _InfoRow(
                            icon: Icons.person_outline,
                            text: enquiry.displaySenderName,
                          ),
                          if (formattedDate.isNotEmpty)
                            _InfoRow(
                              icon: Icons.schedule_outlined,
                              text: formattedDate,
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    _BusinessEnquiriesPageState._goldColor,
                                foregroundColor:
                                    _BusinessEnquiriesPageState._backgroundColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: canMessageInApp ? onMessage : null,
                              icon: const Icon(Icons.forum_outlined),
                              label: const Text(
                                'Message in app',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          if (!canMessageInApp) ...[
                            const SizedBox(height: 12),
                            const _SmallNotice(
                              text:
                                  'This enquiry was saved without an app user id, so in-app messaging is not available for it.',
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            const _SmallNotice(
                              text:
                                  'Messages will stay inside PocketChase instead of opening email.',
                            ),
                          ],
                        ],
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


class _BusinessEnquiryChatPage extends StatefulWidget {
  const _BusinessEnquiryChatPage({
    required this.conversationId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserId,
    required this.otherUserName,
    required this.relatedPostId,
    required this.relatedPostTitle,
  });

  final String conversationId;
  final String currentUserId;
  final String currentUserName;
  final String otherUserId;
  final String otherUserName;
  final String relatedPostId;
  final String relatedPostTitle;

  @override
  State<_BusinessEnquiryChatPage> createState() => _BusinessEnquiryChatPageState();
}

class _BusinessEnquiryChatPageState extends State<_BusinessEnquiryChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _conversationCollection {
    return FirebaseFirestore.instance.collection('community_private_conversations');
  }

  DocumentReference<Map<String, dynamic>> get _conversationRef {
    return _conversationCollection.doc(widget.conversationId);
  }

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    return _conversationRef.collection('messages');
  }

  @override
  void initState() {
    super.initState();
    _ensureConversationExists();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureConversationExists() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await _conversationRef.set(
        <String, Object?>{
          'participants': <String>[widget.currentUserId, widget.otherUserId],
          'participantNames': <String, String>{
            widget.currentUserId: widget.currentUserName,
            widget.otherUserId: widget.otherUserName,
          },
          'relatedPostId': widget.relatedPostId,
          'relatedPostTitle': widget.relatedPostTitle,
          'createdAtMs': now,
          'updatedAtMs': now,
          'lastMessage': '',
          'lastSenderId': '',
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Sending a message will show the user-facing error if permissions fail.
    }
  }

  String _formatMessageTime(int createdAtMs) {
    if (createdAtMs <= 0) return '';

    final value = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final doc = _messagesRef.doc();

      await doc.set(<String, Object?>{
        'id': doc.id,
        'authorId': widget.currentUserId,
        'authorName': widget.currentUserName,
        'message': message,
        'createdAtMs': now,
      });

      await _conversationRef.set(
        <String, Object?>{
          'participants': <String>[widget.currentUserId, widget.otherUserId],
          'participantNames': <String, String>{
            widget.currentUserId: widget.currentUserName,
            widget.otherUserId: widget.otherUserName,
          },
          'relatedPostId': widget.relatedPostId,
          'relatedPostTitle': widget.relatedPostTitle,
          'updatedAtMs': now,
          'lastMessage': message,
          'lastSenderId': widget.currentUserId,
        },
        SetOptions(merge: true),
      );

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 160,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _BusinessEnquiriesPageState._backgroundColor,
      appBar: AppBar(
        title: const Text('Message customer'),
        backgroundColor: _BusinessEnquiriesPageState._backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesRef.orderBy('createdAtMs').snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _BusinessEnquiriesPageState._goldColor,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not load this conversation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _BusinessEnquiriesPageState._softTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    itemCount: docs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ChatIntroCard(
                          otherUserName: widget.otherUserName,
                          relatedPostTitle: widget.relatedPostTitle,
                        );
                      }

                      final data = docs[index - 1].data();
                      final authorId = (data['authorId'] ?? '').toString();
                      final authorName = (data['authorName'] ?? '').toString();
                      final message = (data['message'] ?? '').toString();
                      final createdAtMsRaw = data['createdAtMs'];
                      final createdAtMs = createdAtMsRaw is int
                          ? createdAtMsRaw
                          : int.tryParse((createdAtMsRaw ?? '').toString()) ?? 0;
                      final isMe = authorId == widget.currentUserId;

                      return _ChatBubble(
                        isMe: isMe,
                        authorName: authorName.trim().isEmpty
                            ? (isMe ? widget.currentUserName : widget.otherUserName)
                            : authorName.trim(),
                        message: message,
                        timeText: _formatMessageTime(createdAtMs),
                      );
                    },
                  );
                },
              ),
            ),
            _ChatComposer(
              controller: _messageController,
              sending: _sending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatIntroCard extends StatelessWidget {
  const _ChatIntroCard({
    required this.otherUserName,
    required this.relatedPostTitle,
  });

  final String otherUserName;
  final String relatedPostTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _BusinessEnquiriesPageState._fieldColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: _BusinessEnquiriesPageState._goldColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'In-app conversation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Messaging $otherUserName inside PocketChase.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BusinessEnquiriesPageState._softTextColor,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _BusinessEnquiriesPageState._fieldColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
            ),
            child: Text(
              relatedPostTitle,
              style: const TextStyle(
                color: _BusinessEnquiriesPageState._goldColor,
                height: 1.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.isMe,
    required this.authorName,
    required this.message,
    required this.timeText,
  });

  final bool isMe;
  final String authorName;
  final String message;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? _BusinessEnquiriesPageState._goldColor
              : _BusinessEnquiriesPageState._cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: Border.all(
            color: isMe
                ? _BusinessEnquiriesPageState._goldColor
                : _BusinessEnquiriesPageState._borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authorName,
              style: TextStyle(
                color: isMe
                    ? _BusinessEnquiriesPageState._backgroundColor
                    : _BusinessEnquiriesPageState._goldColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              message,
              style: TextStyle(
                color: isMe
                    ? _BusinessEnquiriesPageState._backgroundColor
                    : Colors.white,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                timeText,
                style: TextStyle(
                  color: isMe
                      ? _BusinessEnquiriesPageState._backgroundColor.withValues(alpha: 0.7)
                      : _BusinessEnquiriesPageState._softTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: _BusinessEnquiriesPageState._backgroundColor,
        border: Border(
          top: BorderSide(color: _BusinessEnquiriesPageState._borderColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _BusinessEnquiriesPageState._goldColor,
              decoration: InputDecoration(
                hintText: 'Write a message...',
                hintStyle: const TextStyle(
                  color: _BusinessEnquiriesPageState._softTextColor,
                ),
                filled: true,
                fillColor: _BusinessEnquiriesPageState._fieldColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: _BusinessEnquiriesPageState._borderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: _BusinessEnquiriesPageState._borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: _BusinessEnquiriesPageState._goldColor,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) {
                if (!sending) {
                  onSend();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _BusinessEnquiriesPageState._goldColor,
                foregroundColor: _BusinessEnquiriesPageState._backgroundColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: sending ? null : onSend,
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
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
        Icon(icon, color: _BusinessEnquiriesPageState._goldColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.dense = false,
  });

  final IconData icon;
  final String text;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 5 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _BusinessEnquiriesPageState._goldColor,
            size: dense ? 18 : 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              cleanText,
              style: TextStyle(
                color: _BusinessEnquiriesPageState._softTextColor,
                fontSize: dense ? 13 : 16,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuText extends StatelessWidget {
  const _MenuText(this.text, {this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: danger
            ? _BusinessEnquiriesPageState._dangerColor
            : Colors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SmallNotice extends StatelessWidget {
  const _SmallNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _BusinessEnquiriesPageState._fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _BusinessEnquiriesPageState._borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: _BusinessEnquiriesPageState._goldColor,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _BusinessEnquiriesPageState._softTextColor,
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
            Icons.forum_outlined,
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
            'New customer product and business messages will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _BusinessEnquiriesPageState._softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
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
      child: CircularProgressIndicator(
        color: _BusinessEnquiriesPageState._goldColor,
      ),
    );
  }
}
