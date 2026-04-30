// ignore_for_file: unused_element, unused_field

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/card_ownership.dart';
import '../models/card_scan_analysis.dart';
import '../models/quick_scan_variant.dart';
import '../models/tcg_card.dart';
import '../pokemon_hub_vision_client.dart';
import '../services/local_pokedex_store.dart';
import '../services/pokedex_sync_service.dart';
import '../services/pokemon_tcg_service.dart';
import '../services/wishlist_service.dart';
import '../utils/price_format_helpers.dart';
import '../widgets/custom_app_logo.dart';
import '../widgets/custom_binder_sheets.dart';
import '../widgets/scan_result_match_card.dart';
import 'card_details_page.dart';

class CardScannerPage extends StatefulWidget {
  const CardScannerPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<CardScannerPage> createState() => _CardScannerPageState();
}

class _CardScannerPageState extends State<CardScannerPage> {
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _capturedImage;
  CardScanAnalysis? _analysis;
  bool _scanning = false;
  String? _errorMessage;
  String? _confirmedMatchId;
  bool _scanSaveBusy = false;
  bool _showExtractedTextDetails = false;
  QuickScanVariant _quickScanVariant = QuickScanVariant.normal;

  static const _visionClient = PokemonHubVisionClient(
    endpoint: 'https://us-central1-cardmon-7dc24.cloudfunctions.net/identifyPokemonCardExact',
  );

  TcgCard _fallbackVisionCard(VisionResolvedCard card) {
    return TcgCard(
      id: card.id,
      name: card.name,
      setId: card.setId,
      setName: card.setName,
      number: card.number,
      types: const <String>[],
      hp: card.hp,
      imageUrl: card.imageUrl,
      largeImageUrl: card.largeImageUrl,
    );
  }

  String _formatVisionResolvedCard(VisionResolvedCard card) {
    final parts = <String>[
      card.name,
      if (card.setName.trim().isNotEmpty) card.setName,
      if (card.number.trim().isNotEmpty) '#${card.number}',
      if ((card.hp ?? '').trim().isNotEmpty) 'HP ${card.hp}',
      if ((card.supertype ?? '').trim().isNotEmpty) card.supertype!,
      if (card.score > 0) 'score ${card.score}',
    ];
    return parts.join(' | ');
  }

  String _formatTcgCard(TcgCard card) {
    final parts = <String>[
      card.name,
      if (card.setName.trim().isNotEmpty) card.setName,
      if (card.number.trim().isNotEmpty) '#${card.number}',
      if ((card.hp ?? '').trim().isNotEmpty) 'HP ${card.hp}',
    ];
    return parts.join(' | ');
  }

  TcgCard? _findConfirmedMatch(List<TcgCard> matches) {
    final confirmedId = _confirmedMatchId;
    if (confirmedId == null || confirmedId.trim().isEmpty) return null;
    for (final card in matches) {
      if (card.id == confirmedId) return card;
    }
    return null;
  }

  void _confirmMatch(TcgCard card) {
    setState(() {
      _confirmedMatchId = card.id;
      _errorMessage = null;
    });
  }

  CardOwnership get _selectedScanOwnership {
    switch (_quickScanVariant) {
      case QuickScanVariant.reverseHolo:
        return const CardOwnership(reverseHolo: true, copies: 1);
      case QuickScanVariant.holo:
        return const CardOwnership(holo: true, copies: 1);
      case QuickScanVariant.normal:
        return const CardOwnership(normal: true, copies: 1);
    }
  }

  String get _selectedScanVariantLabel {
    switch (_quickScanVariant) {
      case QuickScanVariant.reverseHolo:
        return 'Reverse Holo';
      case QuickScanVariant.holo:
        return 'Holo';
      case QuickScanVariant.normal:
        return 'Normal';
    }
  }

  Future<void> _saveConfirmedMatchToPokedex(TcgCard card) async {
    if (_scanSaveBusy) return;

    setState(() {
      _scanSaveBusy = true;
    });

    try {
      final ownershipByCardId = await PokedexSyncService.loadCurrentUserSetOwnership(card.setId);
      final existing = ownershipByCardId[card.id] ?? const CardOwnership();
      final selected = _selectedScanOwnership;

      ownershipByCardId[card.id] = existing.copyWith(
        normal: existing.normal || selected.normal,
        reverseHolo: existing.reverseHolo || selected.reverseHolo,
        holo: existing.holo || selected.holo,
        copies: existing.effectiveCopies + 1,
      );

      await LocalPokedexStore.saveSetOwnershipMap(card.setId, ownershipByCardId);
      await PokedexSyncService.syncCurrentSetForCurrentUser(card.setId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to Set Pokédex as $_selectedScanVariantLabel '
            '(x${ownershipByCardId[card.id]!.effectiveCopies} total)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this card right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _scanSaveBusy = false;
        });
      }
    }
  }

  Future<void> _toggleScanResultWishlist(TcgCard card, bool isInWishlist) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownerUid == null || _scanSaveBusy) return;

    setState(() {
      _scanSaveBusy = true;
    });

    try {
      if (isInWishlist) {
        await WishlistService.removeCard(ownerUid: ownerUid, cardId: card.id);
      } else {
        await WishlistService.addCard(ownerUid: ownerUid, card: card);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isInWishlist ? 'Removed from wishlist' : 'Added to wishlist'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not update wishlist right now')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist right now')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _scanSaveBusy = false;
        });
      }
    }
  }

  Future<CardScanAnalysis> _buildVisionAnalysis(String imagePath) async {
    final vision = await _visionClient.scanImage(imagePath);

    final orderedResolved = <VisionResolvedCard>[];
    final seenIds = <String>{};

    void addResolved(VisionResolvedCard? card) {
      if (card == null) return;
      final id = card.id.trim();
      if (id.isEmpty) return;
      if (seenIds.add(id)) orderedResolved.add(card);
    }

    addResolved(vision.bestMatch);
    for (final card in vision.possibleMatches.take(7)) {
      addResolved(card);
    }

    Future<TcgCard> resolveCard(VisionResolvedCard card) async {
      try {
        return await PokemonTcgService.fetchCardById(card.id);
      } catch (_) {
        return _fallbackVisionCard(card);
      }
    }

    List<TcgCard> matches = <TcgCard>[];
    if (vision.exactConfirmed && vision.bestMatch != null) {
      matches = <TcgCard>[await resolveCard(vision.bestMatch!)];
    } else if (orderedResolved.isNotEmpty) {
      matches = await Future.wait<TcgCard>(orderedResolved.take(4).map(resolveCard));
    }

    final candidateNames = <String>{
      if ((vision.extraction.cardName ?? '').trim().isNotEmpty)
        vision.extraction.cardName!.trim(),
      if ((vision.extraction.pokemonName ?? '').trim().isNotEmpty)
        vision.extraction.pokemonName!.trim(),
    }.toList();

    final candidateNumbers = <String>{
      if ((vision.extraction.collectorNumber ?? '').trim().isNotEmpty)
        vision.extraction.collectorNumber!.trim(),
      if ((vision.extraction.collectorNumber ?? '').trim().isNotEmpty &&
          (vision.extraction.printedTotal ?? '').trim().isNotEmpty)
        '${vision.extraction.collectorNumber!.trim()}/${vision.extraction.printedTotal!.trim()}',
    }.toList();

    final extractedLines = <String>[
      if ((vision.extraction.cardName ?? '').trim().isNotEmpty)
        'Card: ${vision.extraction.cardName}',
      if ((vision.extraction.pokemonName ?? '').trim().isNotEmpty)
        'Pokémon: ${vision.extraction.pokemonName}',
      if ((vision.extraction.collectorNumber ?? '').trim().isNotEmpty)
        'Number: ${vision.extraction.collectorNumber}'
            '${(vision.extraction.printedTotal ?? '').trim().isNotEmpty ? '/${vision.extraction.printedTotal}' : ''}',
      if ((vision.extraction.setCode ?? '').trim().isNotEmpty)
        'Set code: ${vision.extraction.setCode}',
      if ((vision.extraction.setName ?? '').trim().isNotEmpty)
        'Set: ${vision.extraction.setName}',
      if (vision.extraction.hp != null) 'HP: ${vision.extraction.hp}',
      if ((vision.extraction.supertype ?? '').trim().isNotEmpty)
        'Supertype: ${vision.extraction.supertype}',
      if (vision.extraction.subtypes.isNotEmpty)
        'Subtypes: ${vision.extraction.subtypes.join(', ')}',
      if (vision.extraction.attacks.isNotEmpty)
        'Attacks: ${vision.extraction.attacks.join(', ')}',
      if (vision.extraction.abilities.isNotEmpty)
        'Abilities: ${vision.extraction.abilities.join(', ')}',
      if (vision.extraction.rulesText.isNotEmpty)
        'Rules: ${vision.extraction.rulesText.join(' • ')}',
      if ((vision.extraction.rarityHint ?? '').trim().isNotEmpty)
        'Rarity hint: ${vision.extraction.rarityHint}',
      'Exact confirmed: ${vision.exactConfirmed ? 'yes' : 'no'}',
      'Vision exact confidence: ${vision.extraction.exactCardConfidence.toStringAsFixed(2)}',
      if (vision.candidateSetIds.isNotEmpty)
        'Candidate set ids: ${vision.candidateSetIds.join(', ')}',
      if (vision.extraction.notes.isNotEmpty)
        'Notes: ${vision.extraction.notes.join(' • ')}',
      if (vision.bestMatch != null) '',
      if (vision.bestMatch != null) 'Backend best match:',
      if (vision.bestMatch != null) '- ${_formatVisionResolvedCard(vision.bestMatch!)}',
      if (vision.debug.initialBestMatch != null) '',
      if (vision.debug.initialBestMatch != null) 'Initial backend best match:',
      if (vision.debug.initialBestMatch != null)
        '- ${_formatVisionResolvedCard(vision.debug.initialBestMatch!)}',
      if (vision.debug.initialPossibleMatches.isNotEmpty) '',
      if (vision.debug.initialPossibleMatches.isNotEmpty) 'Initial backend shortlist:',
      ...vision.debug.initialPossibleMatches
          .take(8)
          .map((card) => '- ${_formatVisionResolvedCard(card)}'),
      if (vision.possibleMatches.isNotEmpty) '',
      if (vision.possibleMatches.isNotEmpty) 'Reranked backend matches:',
      ...vision.possibleMatches.take(8).map((card) => '- ${_formatVisionResolvedCard(card)}'),
      if (matches.isNotEmpty) '',
      if (matches.isNotEmpty) 'Rendered app matches:',
      ...matches.take(8).map((card) => '- ${_formatTcgCard(card)}'),
    ];

    return CardScanAnalysis(
      extractedText: extractedLines.join('\n'),
      candidateNames: candidateNames,
      candidateNumbers: candidateNumbers,
      matches: matches,
      exactConfirmed: vision.exactConfirmed,
    );
  }

  Future<String?> _prepareScannerAnalysisImage(String imagePath) async {
    try {
      final sourceFile = File(imagePath);
      final sourceBytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return null;

      var oriented = img.bakeOrientation(decoded);
      final longestSide = math.max(oriented.width, oriented.height);
      final shouldResize = longestSide > 1600;
      final shouldCompress = sourceBytes.lengthInBytes > 700 * 1024;

      if (!shouldResize && !shouldCompress) return null;

      if (shouldResize) {
        oriented = oriented.width >= oriented.height
            ? img.copyResize(oriented, width: 1600)
            : img.copyResize(oriented, height: 1600);
      }

      final outputBytes = img.encodeJpg(oriented, quality: 86);
      if (!shouldResize && outputBytes.length >= sourceBytes.lengthInBytes) return null;

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/scan_analysis_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputBytes, flush: true);
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  Future<CardScanAnalysis> _buildPreparedVisionAnalysis(String imagePath) async {
    final preparedPath = await _prepareScannerAnalysisImage(imagePath);
    final analysisPath = preparedPath ?? imagePath;

    try {
      return await _buildVisionAnalysis(analysisPath);
    } finally {
      if (preparedPath != null) {
        try {
          final file = File(preparedPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _captureAndScanFromLivePreview() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked == null) return;
      await _scanPickedImage(picked);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = 'Could not take a photo: $error';
      });
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (picked == null) return;
      await _scanPickedImage(picked);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = 'Could not open the gallery: $error';
      });
    }
  }

  Future<void> _scanPickedImage(XFile picked) async {
    if (!mounted) return;

    setState(() {
      _capturedImage = picked;
      _analysis = null;
      _errorMessage = null;
      _confirmedMatchId = null;
      _quickScanVariant = QuickScanVariant.normal;
      _scanSaveBusy = false;
      _showExtractedTextDetails = false;
      _scanning = true;
    });

    try {
      final analysis = await _buildPreparedVisionAnalysis(picked.path);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _scanning = false;
        if (analysis.exactConfirmed && analysis.matches.isNotEmpty) {
          _confirmedMatchId = analysis.matches.first.id;
        }
        if (analysis.matches.isEmpty) {
          _errorMessage =
              'No likely matches yet. Try one full card with less glare and a clearer photo.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMessage = 'Could not scan this card: $error';
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _capturedImage = null;
      _analysis = null;
      _errorMessage = null;
      _confirmedMatchId = null;
      _scanSaveBusy = false;
      _showExtractedTextDetails = false;
      _quickScanVariant = QuickScanVariant.normal;
    });
  }

  Widget _buildScannerHeader() {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF102754),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 108,
              height: 108,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.09),
                      Colors.white.withValues(alpha: 0.025),
                      Colors.transparent,
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.55),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.24),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.08),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      kCustomAppLogoAsset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.style,
                            color: Color(0xFFF7DE77),
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Scan cards fast',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Take one clear photo or choose a saved card image from your gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final previewFile = _capturedImage != null ? File(_capturedImage!.path) : null;

    return RepaintBoundary(
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 0.82,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF122D63), Color(0xFF0A1E47)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Photo-only mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Take one steady photo of the full card, or choose a clear saved image. This is more reliable than live scanning.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: previewFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.photo_camera_back_outlined,
                                  size: 54,
                                  color: Color(0xFFF7DE77),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No photo selected yet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 22),
                                  child: Text(
                                    'Use Take Photo or Gallery below to scan a card.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                previewFile,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.low,
                              ),
                            ),
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

  Widget _buildScannerActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _scanning ? null : _captureAndScanFromLivePreview,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF7DE77),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scanFromGallery,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  backgroundColor: const Color(0xFF102754),
                ),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16366E),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_outlined, color: Color(0xFFF7DE77)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Photo-only scanning',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_capturedImage != null || _analysis != null || _errorMessage != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning ? null : _resetScanner,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: const Color(0xFF102754),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLastCaptureCard() {
    if (_capturedImage == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Card(
        color: const Color(0xFF102754),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Image.file(
              File(_capturedImage!.path),
              width: 96,
              height: 132,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last capture',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _scanning
                          ? 'Scanning this image now...'
                          : 'You can scan again or choose a different photo from your gallery.',
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
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

  Widget _buildScanningCard() {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Reading the card and finding the best match...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: const Color(0xFF5B1D28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildScanSummaryCard({
    required TcgCard card,
    required String eyebrow,
    required String message,
    bool confirmed = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF102754),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF7DE77).withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFF7DE77),
                shape: BoxShape.circle,
              ),
              child: Icon(
                confirmed ? Icons.verified_rounded : Icons.touch_app_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xFFF7DE77),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${card.setName} • #${card.number}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFD8E3FB),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Raw price',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCardPrice(card.rawPrice, fromCurrency: card.rawPriceCurrency),
                  style: const TextStyle(
                    color: Color(0xFFF7DE77),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSaveFlowCard(TcgCard card) {
    Widget buildVariantChip({
      required QuickScanVariant value,
      required String label,
    }) {
      final selected = _quickScanVariant == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: _scanSaveBusy
            ? null
            : (_) {
                setState(() {
                  _quickScanVariant = value;
                });
              },
        backgroundColor: const Color(0xFF16366E),
        selectedColor: const Color(0xFFF7DE77),
        side: BorderSide(
          color: selected ? const Color(0xFFF7DE77) : Colors.white.withValues(alpha: 0.10),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<bool>(
          stream: WishlistService.cardInWishlistStream(
            FirebaseAuth.instance.currentUser?.uid ?? '',
            card.id,
          ),
          builder: (context, snapshot) {
            final isInWishlist = snapshot.data ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick save this scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose the finish, then save it straight to your collection or wishlist.',
                  style: TextStyle(
                    color: Color(0xFFD8E3FB),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Card finish',
                  style: TextStyle(
                    color: Color(0xFFF7DE77),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    buildVariantChip(
                      value: QuickScanVariant.normal,
                      label: 'Normal',
                    ),
                    buildVariantChip(
                      value: QuickScanVariant.reverseHolo,
                      label: 'Reverse Holo',
                    ),
                    buildVariantChip(
                      value: QuickScanVariant.holo,
                      label: 'Holo',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _scanSaveBusy ? null : () => _saveConfirmedMatchToPokedex(card),
                    icon: _scanSaveBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('Add to Set Pokédex'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DE77),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanSaveBusy ? null : () => addCardToCustomBinderFlow(context, card),
                    icon: const Icon(Icons.photo_album_outlined),
                    label: const Text('Add to Custom Binder'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanSaveBusy
                            ? null
                            : () => _toggleScanResultWishlist(card, isInWishlist),
                        icon: Icon(
                          isInWishlist ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        ),
                        label: Text(
                          isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF16366E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanSaveBusy ? null : _resetScanner,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Scan another'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF16366E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _scanSaveBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CardDetailsPage(card: card),
                              ),
                            );
                          },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open full card details'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChooseMatchCard(int count) {
    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Possible matches',
              style: TextStyle(
                color: Color(0xFFF7DE77),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the correct card below.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Review the ranked matches below. The best visual match is shown first, but you can open details or choose the correct card before saving.',
              style: TextStyle(
                color: Color(0xFFD8E3FB),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Showing top ${count.clamp(1, 4)} likely matches with quick select buttons.',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedTextCard() {
    final hasNumberHints = _analysis?.candidateNumbers.isNotEmpty ?? false;
    final hasNameHints = _analysis?.candidateNames.isNotEmpty ?? false;

    return Card(
      color: const Color(0xFF102754),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            _showExtractedTextDetails = !_showExtractedTextDetails;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7DE77).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFF7DE77).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Color(0xFFF7DE77),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What the scanner read',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _showExtractedTextDetails
                              ? 'Tap to hide the full scanner text.'
                              : 'Tap to view the scanner text and hints.',
                          style: const TextStyle(
                            color: Color(0xFFD8E3FB),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _showExtractedTextDetails ? 0.5 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 30,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Divider(color: Colors.white.withValues(alpha: 0.12)),
                    const SizedBox(height: 10),
                    if (hasNumberHints)
                      Text(
                        'Card number hints: ${_analysis!.candidateNumbers.join(', ')}',
                        style: const TextStyle(
                          color: Color(0xFFF7DE77),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (hasNameHints) ...[
                      if (hasNumberHints) const SizedBox(height: 8),
                      Text(
                        'Name hints: ${_analysis!.candidateNames.take(3).join(' • ')}',
                        style: const TextStyle(
                          color: Color(0xFFD8E3FB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (hasNumberHints || hasNameHints) const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF071B3F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        _analysis!.extractedText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                crossFadeState: _showExtractedTextDetails
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableContent(List<Widget> children) {
    return SafeArea(
      top: !widget.showAppBar,
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - 32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autoBestMatch = _analysis?.bestMatch;
    final matches = _analysis?.matches ?? const <TcgCard>[];
    final confirmedMatch = _findConfirmedMatch(matches);
    final primaryMatch = confirmedMatch ?? autoBestMatch;
    final requiresConfirmation =
        !_scanning && _errorMessage == null && primaryMatch == null && matches.isNotEmpty;
    final extractedText = _analysis?.extractedText.trim() ?? '';

    final children = <Widget>[
      _buildScannerHeader(),
      const SizedBox(height: 14),
      _buildPreviewCard(),
      const SizedBox(height: 12),
      _buildScannerActions(),
    ];

    if (_capturedImage != null) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildLastCaptureCard(),
      ]);
    }

    if (_scanning) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildScanningCard(),
      ]);
    }

    if (_errorMessage != null && !_scanning) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildErrorCard(),
      ]);
    }

    if (primaryMatch != null) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildScanSummaryCard(
          card: primaryMatch,
          eyebrow: _analysis?.exactConfirmed == true ? 'Exact card confirmed' : 'Card selected',
          message: _analysis?.exactConfirmed == true
              ? 'The scanner found a strong enough match to confirm this exact print automatically.'
              : 'You selected this card from the likely matches below.',
          confirmed: true,
        ),
        const SizedBox(height: 18),
        Text(
          _analysis?.exactConfirmed == true ? 'Confirmed match' : 'Selected card',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: ScanResultMatchCard(
            card: primaryMatch,
            highlight: true,
            rank: 1,
            confidenceLabel: _analysis?.exactConfirmed == true ? 'Exact scanner match' : 'Selected by you',
            actionLabel: 'View details',
            onActionTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CardDetailsPage(card: primaryMatch),
                ),
              );
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CardDetailsPage(card: primaryMatch),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickSaveFlowCard(primaryMatch),
      ]);
    }

    if (requiresConfirmation) {
      children.addAll(<Widget>[
        const SizedBox(height: 14),
        _buildChooseMatchCard(matches.length),
        const SizedBox(height: 18),
        const Text(
          'Choose the correct card',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
      ]);

      final rankedMatches = matches.take(4).toList();
      for (var index = 0; index < rankedMatches.length; index++) {
        final card = rankedMatches[index];
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RepaintBoundary(
              child: ScanResultMatchCard(
                card: card,
                rank: index + 1,
                confidenceLabel: index == 0 ? 'Best visual match' : 'Possible match',
                actionLabel: 'This is my card',
                onActionTap: () => _confirmMatch(card),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CardDetailsPage(card: card),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }
    }

    final alternativeMatches = primaryMatch == null
        ? matches.skip(4).take(5)
        : matches.where((card) => card.id != primaryMatch.id).take(7);

    if (alternativeMatches.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        Text(
          requiresConfirmation ? 'More likely matches' : 'Other likely matches',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
      ]);

      var alternativeRank = primaryMatch == null ? 5 : 2;
      for (final card in alternativeMatches) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RepaintBoundary(
              child: ScanResultMatchCard(
                card: card,
                rank: alternativeRank++,
                confidenceLabel: primaryMatch == null ? 'Possible match' : 'Alternative match',
                actionLabel: 'This is my card',
                onActionTap: () => _confirmMatch(card),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CardDetailsPage(card: card),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }
    }

    if (extractedText.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: 18),
        _buildExtractedTextCard(),
      ]);
    }

    final content = _buildScrollableContent(children);

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF041B4A),
      appBar: AppBar(
        title: const Text('Scan Card'),
        backgroundColor: const Color(0xFF041B4A),
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }
}
