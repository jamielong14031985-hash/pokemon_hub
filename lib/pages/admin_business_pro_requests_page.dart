import 'package:flutter/material.dart';

import '../models/business_pro_request.dart';
import '../services/business_profile_service.dart';

class AdminBusinessProRequestsPage extends StatefulWidget {
  const AdminBusinessProRequestsPage({super.key});

  @override
  State<AdminBusinessProRequestsPage> createState() =>
      _AdminBusinessProRequestsPageState();
}

class _AdminBusinessProRequestsPageState
    extends State<AdminBusinessProRequestsPage> {
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

  Color _statusColor(BusinessProRequest request) {
    if (request.isApproved) return _successColor;
    if (request.isRejected) return _dangerColor;
    return _goldColor;
  }

  Future<void> _updateRequestStatus(
    BusinessProRequest request,
    String status,
  ) async {
    final responseController = TextEditingController(
      text: request.adminResponse,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final title = switch (status) {
          'approved' => 'Approve request?',
          'rejected' => 'Reject request?',
          _ => 'Mark as pending?',
        };

        return AlertDialog(
          backgroundColor: _cardColor,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          contentTextStyle: const TextStyle(
            color: _softTextColor,
            height: 1.35,
          ),
          title: Text(title),
          content: TextField(
            controller: responseController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            cursorColor: _goldColor,
            decoration: InputDecoration(
              labelText: 'Admin response',
              hintText: 'Optional message for the business',
              labelStyle: const TextStyle(color: _softTextColor),
              hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
              filled: true,
              fillColor: _fieldColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _goldColor, width: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: status == 'rejected'
                    ? _dangerColor
                    : status == 'approved'
                        ? _successColor
                        : _goldColor,
                foregroundColor: _backgroundColor,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final adminResponse = responseController.text.trim();
    responseController.dispose();

    if (confirmed != true) return;

    try {
      await _service.adminUpdateBusinessProRequestStatus(
        requestId: request.id,
        status: status,
        adminResponse: adminResponse,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request updated.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $error')),
      );
    }
  }

  Future<void> _deleteRequest(BusinessProRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete request?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete the request from ${request.businessName}.',
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
      await _service.adminDeleteBusinessProRequest(request.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request deleted.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete request: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Business Pro Requests'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<BusinessProRequest>>(
        stream: _service.watchAllBusinessProRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load requests: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _softTextColor,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          final requests = snapshot.data ?? const <BusinessProRequest>[];
          final pendingCount = requests.where((item) => item.isPending).length;

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
                        Icons.mark_email_unread_outlined,
                        color: _goldColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Business Pro Requests',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            requests.isEmpty
                                ? 'No requests yet.'
                                : '${requests.length} total • $pendingCount pending',
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
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _goldColor),
                  ),
                )
              else if (requests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _borderColor),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        color: _goldColor,
                        size: 44,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No Pro requests yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'When businesses request Pro or renewal, they will appear here.',
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
                  (request) => _AdminRequestCard(
                    request: request,
                    formattedDate: _formatDate(request.displayDate),
                    statusColor: _statusColor(request),
                    onPending: () => _updateRequestStatus(request, 'pending'),
                    onApprove: () => _updateRequestStatus(request, 'approved'),
                    onReject: () => _updateRequestStatus(request, 'rejected'),
                    onDelete: () => _deleteRequest(request),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminRequestCard extends StatelessWidget {
  const _AdminRequestCard({
    required this.request,
    required this.formattedDate,
    required this.statusColor,
    required this.onPending,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final BusinessProRequest request;
  final String formattedDate;
  final Color statusColor;
  final VoidCallback onPending;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ownerEmail = request.ownerEmail.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _AdminBusinessProRequestsPageState._cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: request.isPending
              ? _AdminBusinessProRequestsPageState._goldColor
              : _AdminBusinessProRequestsPageState._borderColor,
        ),
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
                color: _AdminBusinessProRequestsPageState._goldColor,
              ),
              _RequestBadge(
                icon: Icons.circle,
                label: request.statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            request.businessName.trim().isEmpty
                ? 'Business'
                : request.businessName.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (ownerEmail.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              ownerEmail,
              style: const TextStyle(
                color: _AdminBusinessProRequestsPageState._softTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SelectableText(
            request.message,
            style: const TextStyle(
              color: _AdminBusinessProRequestsPageState._softTextColor,
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
                color: _AdminBusinessProRequestsPageState._fieldColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _AdminBusinessProRequestsPageState._borderColor,
                ),
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
          if (formattedDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: const TextStyle(
                color: _AdminBusinessProRequestsPageState._softTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _AdminBusinessProRequestsPageState._goldColor,
                  side: const BorderSide(
                    color: _AdminBusinessProRequestsPageState._goldColor,
                  ),
                ),
                onPressed: onPending,
                icon: const Icon(Icons.pending_actions_outlined),
                label: const Text('Pending'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _AdminBusinessProRequestsPageState._successColor,
                  side: const BorderSide(
                    color: _AdminBusinessProRequestsPageState._successColor,
                  ),
                ),
                onPressed: onApprove,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _AdminBusinessProRequestsPageState._dangerColor,
                  side: const BorderSide(
                    color: _AdminBusinessProRequestsPageState._dangerColor,
                  ),
                ),
                onPressed: onReject,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject'),
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
        color: _AdminBusinessProRequestsPageState._fieldColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _AdminBusinessProRequestsPageState._borderColor),
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
