import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminFeedbackReportsPage extends StatelessWidget {
  const AdminFeedbackReportsPage({super.key});

  static const Color backgroundColor = Color(0xFF041B4A);
  static const Color cardColor = Color(0xFF102754);
  static const Color fieldColor = Color(0xFF16366E);
  static const Color borderColor = Color(0xFF3F5C96);
  static const Color goldColor = Color(0xFFF7DE77);
  static const Color softTextColor = Color(0xFFC8D4F0);
  static const Color successColor = Color(0xFF4ADE80);

  Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream() {
    return FirebaseFirestore.instance
        .collection('feedback_reports')
        .orderBy('createdAtMs', descending: true)
        .limit(150)
        .snapshots();
  }

  String _text(Map<String, dynamic> data, String key, {String fallback = ''}) {
    final value = data[key];
    if (value == null) return fallback;
    final clean = value.toString().trim();
    return clean.isEmpty ? fallback : clean;
  }

  DateTime? _createdAt(Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    final createdAtMs = data['createdAtMs'];
    if (timestamp is Timestamp) return timestamp.toDate();
    if (createdAtMs is int && createdAtMs > 0) {
      return DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    }
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Date unknown';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} at $hour:$minute';
  }

  List<String> _imageUrls(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is! List) return const <String>[];
    return raw.whereType<String>().map((url) => url.trim()).where((url) => url.isNotEmpty).toList();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'reviewed':
        return successColor;
      case 'closed':
        return Colors.white54;
      case 'in_progress':
      case 'in progress':
        return Colors.orangeAccent;
      case 'new':
      default:
        return goldColor;
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
    String status,
  ) async {
    try {
      await reference.update(<String, Object?>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report marked as $status.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update report: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Feedback Reports'),
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _reportsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminErrorState(error: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: goldColor));
          }
          final reports = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          if (reports.isEmpty) return const _EmptyFeedbackReportsState();
          final newCount = reports.where((doc) => _text(doc.data(), 'status', fallback: 'new').toLowerCase() == 'new').length;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: reports.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ReportsHeaderCard(totalCount: reports.length, newCount: newCount);
              }
              final report = reports[index - 1];
              final data = report.data();
              final images = _imageUrls(data);
              final status = _text(data, 'status', fallback: 'new');
              return _ReportCard(
                reportId: report.id,
                data: data,
                imageUrls: images,
                createdAtLabel: _formatDate(_createdAt(data)),
                statusColor: _statusColor(status),
                onOpen: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FeedbackReportDetailsPage(
                        reportId: report.id,
                        reportReference: report.reference,
                        data: data,
                      ),
                    ),
                  );
                },
                onReviewed: () => _updateStatus(context, report.reference, 'reviewed'),
              );
            },
          );
        },
      ),
    );
  }
}

class FeedbackReportDetailsPage extends StatelessWidget {
  const FeedbackReportDetailsPage({
    super.key,
    required this.reportId,
    required this.reportReference,
    required this.data,
  });

  final String reportId;
  final DocumentReference<Map<String, dynamic>> reportReference;
  final Map<String, dynamic> data;

  String _text(String key, {String fallback = 'Not added'}) {
    final value = data[key];
    if (value == null) return fallback;
    final clean = value.toString().trim();
    return clean.isEmpty ? fallback : clean;
  }

  List<String> _imageUrls() {
    final raw = data['imageUrls'];
    if (raw is! List) return const <String>[];
    return raw.whereType<String>().map((url) => url.trim()).where((url) => url.isNotEmpty).toList();
  }

  DateTime? _createdAt() {
    final timestamp = data['createdAt'];
    final createdAtMs = data['createdAtMs'];
    if (timestamp is Timestamp) return timestamp.toDate();
    if (createdAtMs is int && createdAtMs > 0) return DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Date unknown';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} at $hour:$minute';
  }

  Future<void> _copyReport(BuildContext context) async {
    final buffer = StringBuffer()
      ..writeln('PocketChase feedback report')
      ..writeln('')
      ..writeln('Report ID: $reportId')
      ..writeln('Status: ${_text('status')}')
      ..writeln('Type: ${_text('type')}')
      ..writeln('Impact: ${_text('impact')}')
      ..writeln('Screen: ${_text('screen')}')
      ..writeln('Device: ${_text('deviceUsed')}')
      ..writeln('Version: ${_text('versionInfo')}')
      ..writeln('Platform: ${_text('devicePlatform')}')
      ..writeln('Created: ${_formatDate(_createdAt())}')
      ..writeln('')
      ..writeln('User: ${_text('username')} / ${_text('userEmail')}')
      ..writeln('UID: ${_text('userId')}')
      ..writeln('')
      ..writeln('Trying to do:')
      ..writeln(_text('tryingToDo'))
      ..writeln('')
      ..writeln('What happened:')
      ..writeln(_text('whatHappened'))
      ..writeln('')
      ..writeln('Expected:')
      ..writeln(_text('expectedResult'))
      ..writeln('')
      ..writeln('Steps:')
      ..writeln(_text('stepsToReproduce'));
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied.')));
  }

  Future<void> _updateStatus(BuildContext context, String status) async {
    try {
      await reportReference.update(<String, Object?>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report marked as $status.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update report: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _imageUrls();
    return Scaffold(
      backgroundColor: AdminFeedbackReportsPage.backgroundColor,
      appBar: AppBar(
        title: const Text('Report details'),
        backgroundColor: AdminFeedbackReportsPage.backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy report',
            icon: const Icon(Icons.copy),
            onPressed: () => _copyReport(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _DetailHeader(reportId: reportId, type: _text('type'), status: _text('status', fallback: 'new'), createdAt: _formatDate(_createdAt())),
          const SizedBox(height: 12),
          _DetailSection(title: 'Where it happened', children: [
            _DetailRow(icon: Icons.screenshot_monitor_outlined, label: 'Screen/page', value: _text('screen')),
            _DetailRow(icon: Icons.phone_android_outlined, label: 'Device', value: _text('deviceUsed')),
            _DetailRow(icon: Icons.info_outline, label: 'Version', value: _text('versionInfo')),
            _DetailRow(icon: Icons.devices_outlined, label: 'Platform', value: _text('devicePlatform')),
          ]),
          const SizedBox(height: 12),
          _DetailSection(title: 'Problem details', children: [
            _TextBlock(label: 'What they were trying to do', value: _text('tryingToDo')),
            _TextBlock(label: 'What happened', value: _text('whatHappened')),
            _TextBlock(label: 'What should have happened', value: _text('expectedResult')),
            _TextBlock(label: 'Steps to repeat', value: _text('stepsToReproduce')),
          ]),
          const SizedBox(height: 12),
          _DetailSection(title: 'User', children: [
            _DetailRow(icon: Icons.person_outline, label: 'Username', value: _text('username')),
            _DetailRow(icon: Icons.alternate_email, label: 'Email', value: _text('userEmail')),
            _DetailRow(icon: Icons.badge_outlined, label: 'UID', value: _text('userId')),
            _DetailRow(icon: Icons.contact_mail_outlined, label: 'Contact', value: _text('contactEmail')),
          ]),
          const SizedBox(height: 12),
          _ScreenshotsSection(imageUrls: images),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AdminFeedbackReportsPage.goldColor, side: const BorderSide(color: AdminFeedbackReportsPage.goldColor), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Reviewed', style: TextStyle(fontWeight: FontWeight.w900)),
              onPressed: () => _updateStatus(context, 'reviewed'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AdminFeedbackReportsPage.goldColor, foregroundColor: AdminFeedbackReportsPage.backgroundColor, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              icon: const Icon(Icons.done_all_outlined),
              label: const Text('Close', style: TextStyle(fontWeight: FontWeight.w900)),
              onPressed: () => _updateStatus(context, 'closed'),
            )),
          ]),
        ],
      ),
    );
  }
}

class _ReportsHeaderCard extends StatelessWidget {
  const _ReportsHeaderCard({required this.totalCount, required this.newCount});
  final int totalCount;
  final int newCount;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AdminFeedbackReportsPage.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: AdminFeedbackReportsPage.goldColor)),
      child: Row(children: [
        const Icon(Icons.feedback_outlined, color: AdminFeedbackReportsPage.goldColor, size: 42),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Feedback reports', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.05, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text('$totalCount total • $newCount new', style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.reportId, required this.data, required this.imageUrls, required this.createdAtLabel, required this.statusColor, required this.onOpen, required this.onReviewed});
  final String reportId;
  final Map<String, dynamic> data;
  final List<String> imageUrls;
  final String createdAtLabel;
  final Color statusColor;
  final VoidCallback onOpen;
  final VoidCallback onReviewed;
  String _text(String key, {String fallback = 'Not added'}) {
    final value = data[key];
    if (value == null) return fallback;
    final clean = value.toString().trim();
    return clean.isEmpty ? fallback : clean;
  }
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AdminFeedbackReportsPage.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: AdminFeedbackReportsPage.borderColor)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _StatusBadge(label: _text('status', fallback: 'new'), color: statusColor),
              _StatusBadge(label: _text('type'), color: AdminFeedbackReportsPage.goldColor),
              if (imageUrls.isNotEmpty) _StatusBadge(label: '${imageUrls.length} screenshot${imageUrls.length == 1 ? '' : 's'}', color: Colors.lightBlueAccent),
            ]),
            const SizedBox(height: 10),
            Text(_text('screen'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(_text('whatHappened'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, height: 1.35, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.schedule_outlined, color: AdminFeedbackReportsPage.goldColor, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(createdAtLabel, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontSize: 12, fontWeight: FontWeight.w700))),
              Flexible(child: Text(_text('deviceUsed'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: onReviewed, style: OutlinedButton.styleFrom(foregroundColor: AdminFeedbackReportsPage.goldColor, side: const BorderSide(color: AdminFeedbackReportsPage.goldColor)), icon: const Icon(Icons.task_alt_outlined, size: 18), label: const Text('Reviewed', style: TextStyle(fontWeight: FontWeight.w900)))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: onOpen, style: FilledButton.styleFrom(backgroundColor: AdminFeedbackReportsPage.goldColor, foregroundColor: AdminFeedbackReportsPage.backgroundColor), icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Open', style: TextStyle(fontWeight: FontWeight.w900)))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.reportId, required this.type, required this.status, required this.createdAt});
  final String reportId;
  final String type;
  final String status;
  final String createdAt;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AdminFeedbackReportsPage.cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: AdminFeedbackReportsPage.goldColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Feedback report', style: TextStyle(color: Colors.white, fontSize: 24, height: 1.05, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [_StatusBadge(label: status, color: AdminFeedbackReportsPage.goldColor), _StatusBadge(label: type, color: Colors.lightBlueAccent)]),
        const SizedBox(height: 12),
        SelectableText('ID: $reportId', style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(createdAt, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AdminFeedbackReportsPage.cardColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: AdminFeedbackReportsPage.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AdminFeedbackReportsPage.goldColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(color: Colors.white, height: 1.3, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        SelectableText(value, style: const TextStyle(color: Colors.white, height: 1.35, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ScreenshotsSection extends StatelessWidget {
  const _ScreenshotsSection({required this.imageUrls});
  final List<String> imageUrls;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AdminFeedbackReportsPage.cardColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: AdminFeedbackReportsPage.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Screenshots', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (imageUrls.isEmpty)
          const Text('No screenshots were added.', style: TextStyle(color: AdminFeedbackReportsPage.softTextColor, fontWeight: FontWeight.w700))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: imageUrls.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72),
            itemBuilder: (context, index) => _ScreenshotThumb(imageUrl: imageUrls[index]),
          ),
      ]),
    );
  }
}

class _ScreenshotThumb extends StatelessWidget {
  const _ScreenshotThumb({required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ScreenshotViewerPage(imageUrl: imageUrl))),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: AdminFeedbackReportsPage.fieldColor,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined, color: AdminFeedbackReportsPage.softTextColor)),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotViewerPage extends StatelessWidget {
  const _ScreenshotViewerPage({required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Screenshot')),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 42),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.8))),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyFeedbackReportsState extends StatelessWidget {
  const _EmptyFeedbackReportsState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.feedback_outlined, color: AdminFeedbackReportsPage.goldColor, size: 48),
          SizedBox(height: 12),
          Text('No reports yet', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('Tester feedback reports will appear here after they are submitted.', textAlign: TextAlign.center, style: TextStyle(color: AdminFeedbackReportsPage.softTextColor, height: 1.35)),
        ]),
      ),
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load reports: $error', textAlign: TextAlign.center, style: const TextStyle(color: AdminFeedbackReportsPage.softTextColor, height: 1.35)),
      ),
    );
  }
}
