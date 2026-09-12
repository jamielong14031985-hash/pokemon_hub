import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../pages/business_enquiry_form_page.dart';

const Color _businessEnquiryBackgroundColor = Color(0xFF041B4A);
const Color _businessEnquiryGoldColor = Color(0xFFF7DE77);
const Color _businessEnquirySoftTextColor = Color(0xFFC8D4F0);

class BusinessEnquiryButton extends StatelessWidget {
  const BusinessEnquiryButton({
    super.key,
    required this.profile,
    this.compact = false,
    this.buttonLabel,
    this.initialEnquiryType,
    this.initialSubject,
    this.initialMessage,
  });

  final BusinessProfile profile;
  final bool compact;
  final String? buttonLabel;
  final String? initialEnquiryType;
  final String? initialSubject;
  final String? initialMessage;

  Future<void> _openEnquiryForm(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send an enquiry.')),
      );
      return;
    }

    if (user.uid == profile.ownerUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot send an enquiry to your own business.'),
        ),
      );
      return;
    }

    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => BusinessEnquiryFormPage(
          profile: profile,
          initialEnquiryType: initialEnquiryType,
          initialSubject: initialSubject,
          initialMessage: initialMessage,
        ),
      ),
    );

    if (!context.mounted || message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelText = buttonLabel ?? (compact ? 'Enquiry' : 'Send enquiry');

    if (compact) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _businessEnquiryGoldColor,
          side: const BorderSide(color: _businessEnquiryGoldColor),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.mail_outline),
        label: Text(
          labelText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: () => _openEnquiryForm(context),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _businessEnquiryGoldColor,
          foregroundColor: _businessEnquiryBackgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: const Icon(Icons.mail_outline),
        label: Text(
          labelText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        onPressed: () => _openEnquiryForm(context),
      ),
    );
  }
}

class BusinessEnquiryInfoCard extends StatelessWidget {
  const BusinessEnquiryInfoCard({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _businessEnquiryBackgroundColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _businessEnquiryGoldColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.mail_outline,
            color: _businessEnquiryGoldColor,
            size: 21,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Ask this business about stock, products, events, trades or general questions.',
              style: TextStyle(
                color: _businessEnquirySoftTextColor,
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
