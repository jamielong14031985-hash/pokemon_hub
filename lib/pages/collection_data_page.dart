import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/collection_backup_service.dart';
import '../widgets/glass_page_header.dart';

class CollectionDataPage extends StatefulWidget {
  const CollectionDataPage({super.key});

  @override
  State<CollectionDataPage> createState() => _CollectionDataPageState();
}

class _CollectionDataPageState extends State<CollectionDataPage> {
  bool _busy = false;
  List<CollectionBackupInfo> _backups = const <CollectionBackupInfo>[];

  @override
  void initState() {
    super.initState();
    _refreshBackups();
  }

  Future<void> _refreshBackups() async {
    final backups = await CollectionBackupService.listLocalBackups();
    if (mounted) setState(() => _backups = backups);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('FormatException: ', '').trim();
    return message.isEmpty ? 'That action could not be completed.' : message;
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFF9F2945) : const Color(0xFF237255),
      ),
    );
  }

  Future<void> _showHowItWorks() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102754),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'How collection backups work',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _helpItem(
                Icons.shield_outlined,
                'Back up now',
                'Saves a recovery copy of your complete card collection on this device.',
              ),
              _helpItem(
                Icons.restore_page_outlined,
                'Export restorable backup',
                'Creates a complete copy that can restore cards, variants, quantities, conditions and grading details.',
              ),
              _helpItem(
                Icons.table_view_outlined,
                'Export spreadsheet',
                'Creates a CSV list for Excel or Google Sheets. The spreadsheet is for viewing and is not used to restore your collection.',
              ),
              _helpItem(
                Icons.add_circle_outline,
                'Merge safely',
                'Keeps your current collection and adds missing information. Importing the same backup twice will not double your quantities.',
              ),
              _helpItem(
                Icons.find_replace_outlined,
                'Replace collection',
                'Restores the backup exactly. Your current collection is replaced, but PocketChase creates a recovery backup first.',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7DE77).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF7DE77).withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF7DE77)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Local backups are stored on this device. They may be lost if PocketChase is uninstalled or the phone is reset, so export a restorable backup occasionally.',
                        style: TextStyle(color: Color(0xFFF5E8AF), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String explanation) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFFF7DE77), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  explanation,
                  style: const TextStyle(color: Color(0xFFB9C9E8), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() => _run(() async {
        final backup = await CollectionBackupService.createLocalBackup();
        await _refreshBackups();
        if (mounted) {
          _message('Backup saved: ${backup.cardCount} cards, ${backup.copyCount} copies.');
        }
      });

  Future<void> _exportJson() => _run(() async {
        final file = await CollectionBackupService.exportJson();
        final text = await file.readAsString();
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) _showExported(file, 'Restorable backup created');
      });

  Future<void> _exportCsv() => _run(() async {
        final file = await CollectionBackupService.exportCsv();
        final text = await file.readAsString();
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) _showExported(file, 'Spreadsheet export created');
      });

  void _showExported(File file, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SelectableText(
          'A copy is ready to paste and a file was also saved here:\n\n${file.path}',
          style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final controller = TextEditingController(text: clipboard?.text ?? '');
    if (!mounted) return;
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text('Paste collection backup', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 6,
            maxLines: 12,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste a PocketChase restorable backup here',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF071D47),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (source == null || source.isEmpty || !mounted) return;
    final mode = await _chooseImportMode();
    if (mode == null) return;
    await _run(() async {
      final result = await CollectionBackupService.importJson(source, mode: mode);
      await _refreshBackups();
      if (mounted) {
        _message('Import complete: ${result.cardCount} cards, ${result.copyCount} copies.');
      }
    });
  }

  Future<CollectionImportMode?> _chooseImportMode() {
    return showDialog<CollectionImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text('How should this import work?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Merge safely keeps existing cards and uses the highest saved quantity. '
          'Replace removes the current collection first. PocketChase automatically '
          'creates a recovery backup before replacing.',
          style: TextStyle(color: Color(0xFFD8E3FB), height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, CollectionImportMode.replace),
            child: const Text('Replace'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, CollectionImportMode.merge),
            child: const Text('Merge safely'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(CollectionBackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text('Restore this backup?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Your current collection will be replaced by ${backup.cardCount} cards '
          '(${backup.copyCount} copies). A recovery backup is made first.',
          style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await CollectionBackupService.restoreLocalBackup(backup.file);
      await _refreshBackups();
      if (mounted) _message('Restored ${result.cardCount} cards successfully.');
    });
  }

  String _date(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: const GlassPageAppBar(
        title: 'Collection data',
        subtitle: 'Import, export and backups',
        icon: Icons.cloud_done_outlined,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showHowItWorks,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.help_outline_rounded, color: Color(0xFFF7DE77)),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'How does this work?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _section(
                icon: Icons.shield_outlined,
                title: 'Local backups',
                subtitle: 'PocketChase keeps the five newest snapshots on this device.',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.add_to_drive_outlined),
                        label: const Text('Back up now'),
                      ),
                    ),
                    if (_backups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('No local backups yet.', style: TextStyle(color: Colors.white54)),
                      )
                    else
                      ..._backups.take(5).map(
                            (backup) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(_date(backup.createdAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              subtitle: Text('${backup.setCount} sets • ${backup.cardCount} cards • ${backup.copyCount} copies', style: const TextStyle(color: Color(0xFFB9C9E8))),
                              trailing: TextButton(onPressed: _busy ? null : () => _restore(backup), child: const Text('Restore')),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                icon: Icons.ios_share_outlined,
                title: 'Export collection',
                subtitle: 'Create a restorable copy or a spreadsheet you can view elsewhere.',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _exportJson,
                        icon: const Icon(Icons.restore_page_outlined),
                        label: const Text('Export restorable backup'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _exportCsv,
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Export spreadsheet'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _section(
                icon: Icons.file_download_outlined,
                title: 'Import collection',
                subtitle: 'Paste a PocketChase restorable backup. Invalid information is rejected before anything changes.',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _importFromClipboard,
                    icon: const Icon(Icons.content_paste_go_outlined),
                    label: const Text('Import backup'),
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66041B4A),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFF7DE77), size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 7),
          Text(subtitle, style: const TextStyle(color: Color(0xFFB9C9E8), height: 1.4)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
