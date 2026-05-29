import 'package:flutter/material.dart';

import '../models/business_pro_request.dart';
import '../models/business_profile.dart';
import '../services/business_profile_service.dart';

class BusinessProRequestPage extends StatefulWidget {
  const BusinessProRequestPage({
    super.key,
    required this.profile,
  });

  final BusinessProfile profile;

  @override
  State<BusinessProRequestPage> createState() => _BusinessProRequestPageState();
}

class _BusinessProRequestPageState extends State<BusinessProRequestPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);
  static const Color _dangerColor = Color(0xFFFB7185);

  static const Map<String, String> _requestTypeLabels = <String, String>{
    'new': 'Request Business Pro',
    'renewal': 'Request renewal',
    'upgrade': 'Ask about upgrade',
    'question': 'Contact admin about Pro',
  };

  final BusinessProfileService _service = BusinessProfileService();
  late final TextEditingController _messageController;

  late String _requestType;
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _requestType = widget.profile.premiumActive ? 'renewal' : 'new';
    _messageController = TextEditingController(
      text: widget.profile.premiumActive
          ? 'Hi, I would like to renew Business Pro for ${widget.profile.businessName}.'
          : 'Hi, I would like to request Business Pro for ${widget.profile.businessName}.',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
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

  Future<void> _submitRequest() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short message.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _service.submitBusinessProRequest(
        profile: widget.profile,
        requestType: _requestType,
        message: message,
      );

      if (!mounted) return;

      setState(() => _sending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business Pro request sent.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _sending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $error')),
      );
    }
  }

  Color _statusColor(BusinessProRequest request) {
    if (request.isApproved) return _successColor;
    if (request.isRejected) return _dangerColor;
    return _goldColor;
  }

  @override
  Widget build(BuildContext context) {
    final businessName = widget.profile.businessName.trim().isEmpty
        ? 'Business Pro'
        : widget.profile.businessName.trim();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Pro Request'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessProRequest>>(
        stream: _service.watchBusinessProRequestsForBusiness(widget.profile.id),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <BusinessProRequest>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
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
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _fieldColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_outlined,
                        color: _goldColor,
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
                            widget.profile.premiumStatusLabel,
                            style: const TextStyle(
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Send a Pro request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ask the app admin to activate, renew or discuss Business Pro for this business.',
                      style: TextStyle(
                        color: _softTextColor,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _requestType,
                      dropdownColor: _fieldColor,
                      iconEnabledColor: _softTextColor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _inputDecoration('Request type'),
                      items: _requestTypeLabels.entries
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
                              setState(() => _requestType = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      enabled: !_sending,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 800,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: _goldColor,
                      decoration: _inputDecoration(
                        'Message',
                        hintText: 'Tell the admin what you need...',
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        _sending ? 'Sending...' : 'Send request',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: _sending ? null : _submitRequest,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Request history',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (requests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _borderColor),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.history_outlined,
                        color: _goldColor,
                        size: 42,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No requests yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your Business Pro requests will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _softTextColor,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...requests.map(
                  (request) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _RequestBadge(
                              icon: Icons.workspace_premium_outlined,
                              label: request.requestTypeLabel,
                              color: _goldColor,
                            ),
                            _RequestBadge(
                              icon: Icons.circle,
                              label: request.statusLabel,
                              color: _statusColor(request),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          request.message,
                          style: const TextStyle(
                            color: _softTextColor,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (request.adminResponse.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _fieldColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Text(
                              'Admin response: ${request.adminResponse.trim()}',
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (_formatDate(request.displayDate).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(request.displayDate),
                            style: const TextStyle(
                              color: _softTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestBadge extends StatelessWidget {
  const _RequestBadge({
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
        color: _BusinessProRequestPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _BusinessProRequestPageState._borderColor),
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
