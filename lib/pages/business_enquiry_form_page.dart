import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class BusinessEnquiryFormPage extends StatefulWidget {
  const BusinessEnquiryFormPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessEnquiryFormPage> createState() =>
      _BusinessEnquiryFormPageState();
}

class _BusinessEnquiryFormPageState extends State<BusinessEnquiryFormPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);

  static const Map<String, String> _enquiryTypeLabels = <String, String>{
    'stock': 'Ask about stock',
    'event': 'Ask about an event',
    'product': 'Ask about a product',
    'trade': 'Trade / sell enquiry',
    'general': 'General enquiry',
  };

  final BusinessProfileService _service = BusinessProfileService();
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;
  late final TextEditingController _contactEmailController;

  String _selectedType = 'general';
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    _subjectController = TextEditingController();
    _messageController = TextEditingController();
    _contactEmailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      floatingLabelStyle: const TextStyle(
        color: _goldColor,
        fontWeight: FontWeight.w900,
      ),
      filled: true,
      fillColor: _fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _goldColor, width: 1.6),
      ),
    );
  }

  Future<void> _sendEnquiry() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    final contactEmail = _contactEmailController.text.trim();

    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject is required.')),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is required.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _service.submitBusinessEnquiry(
        profile: widget.profile,
        enquiryType: _selectedType,
        subject: subject,
        message: message,
        contactEmail: contactEmail,
      );

      if (!mounted) return;

      Navigator.of(context).pop('Enquiry sent.');
    } catch (error) {
      if (!mounted) return;

      setState(() => _sending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send enquiry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'Business'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Send enquiry'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _fieldColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      color: _goldColor,
                      size: 28,
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Send a direct enquiry to this business.',
                          style: TextStyle(
                            color: _softTextColor,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              dropdownColor: _fieldColor,
              iconEnabledColor: _softTextColor,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDecoration('Enquiry type'),
              items: _enquiryTypeLabels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedType = value);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              enabled: !_sending,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                'Subject',
                hintText: 'Example: Do you have 151 booster bundles?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              enabled: !_sending,
              minLines: 5,
              maxLines: 8,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                'Message',
                hintText: 'Write your question here...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactEmailController,
              enabled: !_sending,
              maxLength: 200,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              cursorColor: _goldColor,
              decoration: _inputDecoration(
                'Contact email',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _goldColor,
                foregroundColor: _backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _backgroundColor,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _sending ? 'Sending...' : 'Send enquiry',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: _sending ? null : _sendEnquiry,
            ),
          ],
        ),
      ),
    );
  }
}
