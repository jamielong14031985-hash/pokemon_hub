import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/card_ownership.dart';
import 'local_pokedex_store.dart';
import 'pokedex_sync_service.dart';

enum CollectionImportMode { merge, replace }

class CollectionBackupInfo {
  const CollectionBackupInfo({
    required this.file,
    required this.createdAt,
    required this.setCount,
    required this.cardCount,
    required this.copyCount,
  });

  final File file;
  final DateTime createdAt;
  final int setCount;
  final int cardCount;
  final int copyCount;
}

class CollectionImportResult {
  const CollectionImportResult({
    required this.setCount,
    required this.cardCount,
    required this.copyCount,
  });

  final int setCount;
  final int cardCount;
  final int copyCount;
}

class CollectionBackupService {
  static const String _format = 'pocketchase_collection_backup';
  static const int _version = 1;
  static const int _maximumLocalBackups = 5;

  static Future<Directory> _backupDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/PocketChase/backups');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<Directory> _exportDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/PocketChase/exports');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static String _timestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }

  static Future<Map<String, dynamic>> _createDocument() async {
    await PokedexSyncService.ensureCurrentUserPokedexReady();
    final collection = await LocalPokedexStore.loadAllOwnershipBySet();
    var cardCount = 0;
    var copyCount = 0;

    final sets = <String, dynamic>{};
    for (final setEntry in collection.entries) {
      final cards = <String, dynamic>{};
      for (final cardEntry in setEntry.value.entries) {
        cards[cardEntry.key] = cardEntry.value.toJson();
        cardCount++;
        copyCount += cardEntry.value.collectionCount;
      }
      sets[setEntry.key] = cards;
    }

    return <String, dynamic>{
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'summary': <String, int>{
        'sets': sets.length,
        'cards': cardCount,
        'copies': copyCount,
      },
      'sets': sets,
    };
  }

  static Future<String> createJsonText() async {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(await _createDocument());
  }

  static Future<File> exportJson() async {
    final now = DateTime.now();
    final directory = await _exportDirectory();
    final file = File('${directory.path}/PocketChase_${_timestamp(now)}.json');
    return file.writeAsString(await createJsonText(), flush: true);
  }

  static Future<File> exportCsv() async {
    await PokedexSyncService.ensureCurrentUserPokedexReady();
    final collection = await LocalPokedexStore.loadAllOwnershipBySet();
    final buffer = StringBuffer()
      ..writeln(
        'set_id,card_id,total_copies,normal,reverse_holo,holo,'
        'poke_ball_reverse,master_ball_reverse,extra_variants,condition,'
        'grading_company,grade,notes',
      );

    String cell(Object? value) {
      final text = (value ?? '').toString();
      return '"${text.replaceAll('"', '""')}"';
    }

    final setIds = collection.keys.toList()..sort();
    for (final setId in setIds) {
      final cards = collection[setId]!;
      final cardIds = cards.keys.toList()..sort();
      for (final cardId in cardIds) {
        final ownership = cards[cardId]!;
        buffer.writeln(<Object?>[
          setId,
          cardId,
          ownership.collectionCount,
          ownership.normalCount,
          ownership.reverseHoloCount,
          ownership.holoCount,
          ownership.pokeBallReverseCount,
          ownership.masterBallReverseCount,
          jsonEncode(ownership.extraVariantCopies),
          ownership.condition,
          ownership.gradingCompany,
          ownership.grade ?? '',
          ownership.conditionNotes,
        ].map(cell).join(','));
      }
    }

    final now = DateTime.now();
    final directory = await _exportDirectory();
    final file = File('${directory.path}/PocketChase_${_timestamp(now)}.csv');
    return file.writeAsString(buffer.toString(), flush: true);
  }

  static Future<CollectionBackupInfo> createLocalBackup() async {
    final now = DateTime.now();
    final document = await _createDocument();
    final directory = await _backupDirectory();
    final file = File('${directory.path}/backup_${_timestamp(now)}.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(document), flush: true);
    await _trimBackups();
    return _infoFromDocument(file, document);
  }

  static Future<List<CollectionBackupInfo>> listLocalBackups() async {
    final directory = await _backupDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final backups = <CollectionBackupInfo>[];
    for (final file in files) {
      try {
        final document = _decodeDocument(await file.readAsString());
        backups.add(_infoFromDocument(file, document));
      } catch (_) {
        // A damaged backup is ignored rather than blocking valid snapshots.
      }
    }
    return backups;
  }

  static Future<CollectionImportResult> restoreLocalBackup(File file) async {
    return importJson(await file.readAsString(), mode: CollectionImportMode.replace);
  }

  static Future<CollectionImportResult> importJson(
    String source, {
    required CollectionImportMode mode,
  }) async {
    final document = _decodeDocument(source);
    final imported = _ownershipFromDocument(document);
    final previousSetIds = await LocalPokedexStore.allTrackedSetIds();

    // Every potentially destructive operation receives its own recovery point.
    if (mode == CollectionImportMode.replace) await createLocalBackup();

    Map<String, Map<String, CardOwnership>> result;
    if (mode == CollectionImportMode.replace) {
      result = imported;
    } else {
      final current = await LocalPokedexStore.loadAllOwnershipBySet();
      result = _mergeCollections(current, imported);
    }

    await LocalPokedexStore.replaceAllOwnershipBySet(result);

    final affectedSetIds = <String>{...previousSetIds, ...result.keys};
    for (final setId in affectedSetIds) {
      await PokedexSyncService.syncCurrentSetForCurrentUser(setId);
    }

    var cardCount = 0;
    var copyCount = 0;
    for (final cards in result.values) {
      cardCount += cards.length;
      for (final ownership in cards.values) {
        copyCount += ownership.collectionCount;
      }
    }
    return CollectionImportResult(
      setCount: result.length,
      cardCount: cardCount,
      copyCount: copyCount,
    );
  }

  static Map<String, dynamic> _decodeDocument(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Backup must be a JSON object.');
    final document = Map<String, dynamic>.from(decoded);
    if (document['format'] != _format) {
      throw const FormatException('This is not a PocketChase collection backup.');
    }
    final version = (document['version'] as num?)?.toInt();
    if (version != _version) {
      throw FormatException('Backup version ${version ?? 'unknown'} is not supported.');
    }
    if (document['sets'] is! Map) {
      throw const FormatException('The backup does not contain any set data.');
    }
    return document;
  }

  static Map<String, Map<String, CardOwnership>> _ownershipFromDocument(
    Map<String, dynamic> document,
  ) {
    final result = <String, Map<String, CardOwnership>>{};
    final rawSets = Map<Object?, Object?>.from(document['sets'] as Map);
    for (final setEntry in rawSets.entries) {
      final setId = setEntry.key.toString().trim();
      if (setId.isEmpty || setEntry.value is! Map) continue;
      final cards = <String, CardOwnership>{};
      for (final cardEntry in (setEntry.value as Map).entries) {
        final cardId = cardEntry.key.toString().trim();
        if (cardId.isEmpty || cardEntry.value is! Map) continue;
        final ownership = CardOwnership.fromJson(
          Map<String, dynamic>.from(cardEntry.value as Map),
        );
        if (LocalPokedexStore.hasSavedCopies(ownership)) cards[cardId] = ownership;
      }
      if (cards.isNotEmpty) result[setId] = cards;
    }
    return result;
  }

  static Map<String, Map<String, CardOwnership>> _mergeCollections(
    Map<String, Map<String, CardOwnership>> current,
    Map<String, Map<String, CardOwnership>> imported,
  ) {
    final merged = <String, Map<String, CardOwnership>>{
      for (final entry in current.entries) entry.key: Map<String, CardOwnership>.from(entry.value),
    };
    for (final setEntry in imported.entries) {
      final cards = merged.putIfAbsent(setEntry.key, () => <String, CardOwnership>{});
      for (final cardEntry in setEntry.value.entries) {
        final existing = cards[cardEntry.key];
        cards[cardEntry.key] = existing == null
            ? cardEntry.value
            : _mergeOwnership(existing, cardEntry.value);
      }
    }
    return merged;
  }

  static CardOwnership _mergeOwnership(CardOwnership a, CardOwnership b) {
    final extras = <String, int>{...a.extraVariantCopies};
    for (final entry in b.extraVariantCopies.entries) {
      final old = extras[entry.key] ?? 0;
      if (entry.value > old) extras[entry.key] = entry.value;
    }
    final preferBDetails = !a.hasConditionDetails && b.hasConditionDetails;
    return CardOwnership(
      normalCopies: a.normalCount > b.normalCount ? a.normalCount : b.normalCount,
      reverseHoloCopies: a.reverseHoloCount > b.reverseHoloCount
          ? a.reverseHoloCount
          : b.reverseHoloCount,
      holoCopies: a.holoCount > b.holoCount ? a.holoCount : b.holoCount,
      pokeBallReverseCopies: a.pokeBallReverseCount > b.pokeBallReverseCount
          ? a.pokeBallReverseCount
          : b.pokeBallReverseCount,
      masterBallReverseCopies: a.masterBallReverseCount > b.masterBallReverseCount
          ? a.masterBallReverseCount
          : b.masterBallReverseCount,
      extraVariantCopies: Map<String, int>.unmodifiable(extras),
      condition: preferBDetails ? b.condition : a.condition,
      gradingCompany: preferBDetails ? b.gradingCompany : a.gradingCompany,
      grade: preferBDetails ? b.grade : a.grade,
      conditionNotes: preferBDetails ? b.conditionNotes : a.conditionNotes,
    );
  }

  static CollectionBackupInfo _infoFromDocument(
    File file,
    Map<String, dynamic> document,
  ) {
    final summary = document['summary'] is Map
        ? Map<Object?, Object?>.from(document['summary'] as Map)
        : const <Object?, Object?>{};
    final exportedAt = DateTime.tryParse((document['exportedAt'] ?? '').toString());
    int read(String key) => (summary[key] as num?)?.toInt() ?? 0;
    return CollectionBackupInfo(
      file: file,
      createdAt: exportedAt?.toLocal() ?? file.lastModifiedSync(),
      setCount: read('sets'),
      cardCount: read('cards'),
      copyCount: read('copies'),
    );
  }

  static Future<void> _trimBackups() async {
    final directory = await _backupDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final oldFile in files.skip(_maximumLocalBackups)) {
      await oldFile.delete();
    }
  }
}
