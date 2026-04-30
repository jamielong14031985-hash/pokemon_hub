import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_profile.dart';
import '../models/community_models.dart';
import '../services/community_image_services.dart';
import '../services/currency_settings.dart';
import '../utils/community_market_helpers.dart';
import 'stored_image.dart';
import 'trade_safety_composer_checklist.dart';

class CreateCommunityPostSheet extends StatefulWidget {
  const CreateCommunityPostSheet({
    super.key,
    required this.profile,
    this.existingPost,
    this.initialPostType,
  });

  final AppUserProfile profile;
  final CommunityPost? existingPost;
  final String? initialPostType;

  @override
  State<CreateCommunityPostSheet> createState() =>
      _CreateCommunityPostSheetState();
}

class _CreateCommunityPostSheetState extends State<CreateCommunityPostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _wantedTradeForController =
      TextEditingController();

  String _postType = 'Swap';
  String _marketStatus = 'Available';
  String _askingCurrency = CurrencySettings.selectedCode;
  String _cardCondition = 'Near Mint';
  String _deliveryMethod = 'Post';
  bool _saving = false;
  bool _processingImages = false;
  List<String> _imageBase64List = <String>[];

  bool get _isEditing => widget.existingPost != null;
  bool get _isDiscussionPost => _postType == 'Thread';
  bool get _isMarketplacePost => !_isDiscussionPost;
  bool get _isForSale => _postType == 'For Sale';
  bool get _isSwap => _postType == 'Swap';
  bool get _isWanted => _postType == 'Wanted';

  static const List<String> _postTypeOptions = <String>[
    'Swap',
    'For Sale',
    'Wanted',
    'Thread',
  ];

  List<String> get _marketStatusOptions {
    if (_isForSale) return const <String>['Available', 'Pending', 'Sold'];
    if (_isSwap) return const <String>['Available', 'Pending', 'Traded'];
    if (_isWanted) return const <String>['Available', 'Pending', 'Found'];
    return const <String>['Available', 'Pending'];
  }

  int get _remainingImageSlots =>
      CommunityImageCodec.maxImagesPerPost - _imageBase64List.length;

  @override
  void initState() {
    super.initState();

    _askingCurrency = _safeCurrencyCode(CurrencySettings.selectedCode);
    _cardCondition = _safeCardCondition(_cardCondition);
    _deliveryMethod = _safeDeliveryMethod(_deliveryMethod);

    final existingPost = widget.existingPost;
    if (existingPost != null) {
      _postType = _safePostType(existingPost.postType);
      _titleController.text = existingPost.title;
      _descriptionController.text = existingPost.description;
      _priceController.text =
          existingPost.hasPrice ? existingPost.askingPrice!.toStringAsFixed(2) : '';
      _locationController.text = existingPost.locationText;
      _wantedTradeForController.text = existingPost.wantedTradeFor;
      _marketStatus =
          existingPost.isMarketplace ? existingPost.normalizedMarketStatus : 'Available';
      if (!_marketStatusOptions.contains(_marketStatus)) {
        _marketStatus = 'Available';
      }
      _askingCurrency = _safeCurrencyCode(existingPost.askingCurrencyCode);
      _cardCondition = _safeCardCondition(
        existingPost.cardCondition.trim().isEmpty
            ? 'Near Mint'
            : existingPost.cardCondition.trim(),
      );
      _deliveryMethod = _safeDeliveryMethod(
        existingPost.deliveryMethod.trim().isEmpty
            ? 'Post'
            : existingPost.deliveryMethod.trim(),
      );
      _imageBase64List = List<String>.from(existingPost.imageBase64List)
          .where((imageRef) => imageRef.trim().isNotEmpty)
          .take(CommunityImageCodec.maxImagesPerPost)
          .toList();
    } else if (widget.initialPostType != null &&
        widget.initialPostType!.trim().isNotEmpty) {
      _postType = _safePostType(widget.initialPostType!.trim());
      if (!_marketStatusOptions.contains(_marketStatus)) {
        _marketStatus = 'Available';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _wantedTradeForController.dispose();
    super.dispose();
  }

  String _safePostType(String value) {
    final trimmed = value.trim();
    if (_postTypeOptions.contains(trimmed)) return trimmed;
    if (trimmed.toLowerCase() == 'discussion' ||
        trimmed.toLowerCase() == 'discussion thread') {
      return 'Thread';
    }
    return 'Swap';
  }

  String _safeCurrencyCode(String value) {
    final trimmed = value.trim().toUpperCase();
    if (CurrencySettings.supportedCurrencies.containsKey(trimmed)) {
      return trimmed;
    }

    final selected = CurrencySettings.selectedCode.trim().toUpperCase();
    if (CurrencySettings.supportedCurrencies.containsKey(selected)) {
      return selected;
    }

    if (CurrencySettings.supportedCurrencies.isNotEmpty) {
      return CurrencySettings.supportedCurrencies.keys.first;
    }

    return 'GBP';
  }

  String _safeCardCondition(String value) {
    final trimmed = value.trim();
    if (communityCardConditions.contains(trimmed)) return trimmed;
    return communityCardConditions.isNotEmpty
        ? communityCardConditions.first
        : 'Near Mint';
  }

  String _safeDeliveryMethod(String value) {
    final trimmed = value.trim();
    if (communityDeliveryMethods.contains(trimmed)) return trimmed;
    return communityDeliveryMethods.isNotEmpty ? communityDeliveryMethods.first : 'Post';
  }

  OutlineInputBorder get _fieldBorder => const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF3F5C96)),
      );

  InputDecoration _inputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
      filled: true,
      fillColor: const Color(0xFF16366E),
      border: _fieldBorder,
      enabledBorder: _fieldBorder,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFFF7DE77), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      suffixIcon: suffixIcon,
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _showComposerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parsePrice() {
    final raw = _priceController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  Future<void> _addPhotoFromCamera() async {
    if (_processingImages || _remainingImageSlots <= 0) {
      _showComposerMessage(
        'You can add up to ${CommunityImageCodec.maxImagesPerPost} photos per post.',
      );
      return;
    }

    setState(() {
      _processingImages = true;
    });

    try {
      final encoded =
          await CommunityImageCodec.pickAndEncodeSingle(ImageSource.camera);
      if (encoded == null || !mounted) return;
      setState(() {
        _imageBase64List = <String>[..._imageBase64List, encoded];
      });
    } catch (error) {
      _showComposerMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _processingImages = false;
        });
      }
    }
  }

  Future<void> _addPhotosFromGallery() async {
    if (_processingImages || _remainingImageSlots <= 0) {
      _showComposerMessage(
        'You can add up to ${CommunityImageCodec.maxImagesPerPost} photos per post.',
      );
      return;
    }

    setState(() {
      _processingImages = true;
    });

    try {
      final picked = await CommunityImageCodec.pickAndEncodeMultiFromGallery(
        limit: _remainingImageSlots,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _imageBase64List = <String>[..._imageBase64List, ...picked];
      });
    } catch (error) {
      _showComposerMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _processingImages = false;
        });
      }
    }
  }

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _imageBase64List.length) return;
    setState(() {
      final updated = List<String>.from(_imageBase64List);
      updated.removeAt(index);
      _imageBase64List = updated;
    });
  }

  bool _imagesAreSafeToPublish() {
    const maxEncodedPayloadCharacters = 860 * 1024;
    final totalBase64Characters = _imageBase64List
        .where((image) => !FirebaseImageStorageService.isRemoteRef(image))
        .fold<int>(0, (total, image) => total + image.length);

    if (totalBase64Characters <= maxEncodedPayloadCharacters) {
      return true;
    }

    _showComposerMessage(
      'These photos are too large to publish together. Remove one or two photos, or crop them tighter.',
    );
    return false;
  }

  Future<void> _submit() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (!_isEditing && currentUser == null) {
      _showComposerMessage('Please sign in before creating a post.');
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    const contact = '';

    if (title.isEmpty || description.isEmpty) {
      _showComposerMessage('Add a title and description');
      return;
    }

    final askingPrice = _parsePrice();
    if (_isForSale && askingPrice == null) {
      _showComposerMessage('Add a valid asking price for sale listings');
      return;
    }

    if (!_imagesAreSafeToPublish()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final safeMarketStatus = _isMarketplacePost &&
              _marketStatusOptions.contains(_marketStatus)
          ? _marketStatus
          : 'Available';
      final safeCurrency = _safeCurrencyCode(_askingCurrency);
      final safeCondition = _safeCardCondition(_cardCondition);
      final safeDelivery = _safeDeliveryMethod(_deliveryMethod);
      final safeImages = _imageBase64List
          .map((imageRef) => imageRef.trim())
          .where((imageRef) => imageRef.isNotEmpty)
          .take(CommunityImageCodec.maxImagesPerPost)
          .toList();

      if (_isEditing) {
        final existingPost = widget.existingPost!;
        final updatedPost = CommunityPost(
          id: existingPost.id,
          authorId: existingPost.authorId,
          authorName: existingPost.authorName,
          postType: _postType,
          title: title,
          description: description,
          contact: contact,
          createdAtMs: existingPost.createdAtMs,
          updatedAtMs: now,
          marketStatus: _isMarketplacePost ? safeMarketStatus : 'Available',
          askingPrice: _isForSale ? askingPrice : null,
          askingCurrency:
              _isMarketplacePost ? safeCurrency : CurrencySettings.selectedCode,
          cardCondition: _isMarketplacePost ? safeCondition : '',
          deliveryMethod: _isMarketplacePost ? safeDelivery : '',
          locationText: _isMarketplacePost ? _locationController.text.trim() : '',
          wantedTradeFor: (_isSwap || _isWanted)
              ? _wantedTradeForController.text.trim()
              : '',
          lastBumpedAtMs: existingPost.lastBumpedAtMs,
          imageBase64List: safeImages,
          hiddenReplyIds: existingPost.hiddenReplyIds,
        );

        await FirebaseFirestore.instance
            .collection('community_posts')
            .doc(existingPost.id)
            .set(updatedPost.toJson(), SetOptions(merge: true));
      } else {
        final postDoc =
            FirebaseFirestore.instance.collection('community_posts').doc();
        final post = CommunityPost(
          id: postDoc.id,
          authorId: currentUser!.uid,
          authorName: widget.profile.displayName,
          postType: _postType,
          title: title,
          description: description,
          contact: contact,
          createdAtMs: now,
          updatedAtMs: now,
          marketStatus: _isMarketplacePost ? safeMarketStatus : 'Available',
          askingPrice: _isForSale ? askingPrice : null,
          askingCurrency:
              _isMarketplacePost ? safeCurrency : CurrencySettings.selectedCode,
          cardCondition: _isMarketplacePost ? safeCondition : '',
          deliveryMethod: _isMarketplacePost ? safeDelivery : '',
          locationText: _isMarketplacePost ? _locationController.text.trim() : '',
          wantedTradeFor: (_isSwap || _isWanted)
              ? _wantedTradeForController.text.trim()
              : '',
          imageBase64List: safeImages,
        );
        await postDoc.set(post.toJson());
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      _showComposerMessage(
        error.message ?? (_isEditing ? 'Could not update post' : 'Could not create post'),
      );
    } catch (_) {
      _showComposerMessage(_isEditing ? 'Could not update post' : 'Could not create post');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetTitle = _isEditing
        ? _isDiscussionPost
            ? 'Edit discussion thread'
            : 'Edit marketplace listing'
        : _isDiscussionPost
            ? 'Start discussion thread'
            : 'Create marketplace listing';
    final sheetSubtitle = _isDiscussionPost
        ? 'Start a conversation where collectors can talk cards, share tips, and make friends.'
        : 'Create a more professional marketplace post with status, price, condition, delivery, and location details.';
    final titleHint = _isDiscussionPost
        ? 'Favourite modern sets right now?'
        : _isForSale
            ? 'Selling Charizard ex promo'
            : _isWanted
                ? 'Wanted: 151 Charizard ex'
                : 'Looking to swap Charizard ex';
    final descriptionHint = _isDiscussionPost
        ? 'Kick off the discussion and let other collectors jump in.'
        : _isForSale
            ? 'List exactly what is included, the card condition, and any postage or meetup details.'
            : _isWanted
                ? 'Describe what you are looking for, preferred condition, and whether you can buy or swap.'
                : 'Write what you are offering, what you want back, and any condition notes.';
    final photoHelp = _isDiscussionPost
        ? 'Add up to 4 photos if you want, or leave this empty for a text-only discussion thread.'
        : 'Add up to 4 clear photos of the card, binder page, or sealed product. Camera adds one at a time and gallery can add several.';
    final submitLabel = _isEditing
        ? 'Save changes'
        : _isDiscussionPost
            ? 'Start thread'
            : 'Publish listing';

    return Material(
      color: const Color(0xFF102754),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          sheetTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          sheetSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC8D4F0),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _sectionCard(
                        title: 'Post setup',
                        children: [
                          _fieldLabel('Post type'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _postType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            iconEnabledColor: const Color(0xFFE4ECFF),
                            dropdownColor: const Color(0xFF143163),
                            decoration: _inputDecoration('Choose a post type'),
                            items: const [
                              DropdownMenuItem(
                                value: 'Swap',
                                child: Text('Swap'),
                              ),
                              DropdownMenuItem(
                                value: 'For Sale',
                                child: Text('For Sale'),
                              ),
                              DropdownMenuItem(
                                value: 'Wanted',
                                child: Text('Wanted'),
                              ),
                              DropdownMenuItem(
                                value: 'Thread',
                                child: Text('Discussion Thread'),
                              ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() {
                                        _postType = _safePostType(value);
                                        if (_postType == 'Thread') {
                                          _marketStatus = 'Available';
                                        } else if (!_marketStatusOptions
                                            .contains(_marketStatus)) {
                                          _marketStatus = 'Available';
                                        }
                                      });
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Title'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            enabled: !_saving,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                            decoration: _inputDecoration(titleHint),
                          ),
                          const SizedBox(height: 14),
                          _fieldLabel('Description'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionController,
                            enabled: !_saving,
                            maxLines: 5,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.35,
                            ),
                            decoration: _inputDecoration(descriptionHint),
                          ),
                        ],
                      ),
                      if (_isMarketplacePost) ...[
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Marketplace details',
                          children: [
                            _fieldLabel('Listing status'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _marketStatusOptions.contains(_marketStatus)
                                  ? _marketStatus
                                  : 'Available',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              iconEnabledColor: const Color(0xFFE4ECFF),
                              dropdownColor: const Color(0xFF143163),
                              decoration: _inputDecoration('Status'),
                              items: _marketStatusOptions
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() {
                                          _marketStatus = value;
                                        });
                                      }
                                    },
                            ),
                            if (_isForSale) ...[
                              const SizedBox(height: 14),
                              _fieldLabel('Asking price'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _priceController,
                                      enabled: !_saving,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                      ),
                                      decoration: _inputDecoration('25.00'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue:
                                          _safeCurrencyCode(_askingCurrency),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      iconEnabledColor: const Color(0xFFE4ECFF),
                                      dropdownColor: const Color(0xFF143163),
                                      decoration:
                                          _inputDecoration('Currency'),
                                      items: CurrencySettings
                                          .supportedCurrencies.values
                                          .map(
                                            (currency) => DropdownMenuItem(
                                              value: currency.code,
                                              child: Text(currency.code),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _saving
                                          ? null
                                          : (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _askingCurrency =
                                                      _safeCurrencyCode(value);
                                                });
                                              }
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            _fieldLabel('Card condition'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _safeCardCondition(_cardCondition),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              iconEnabledColor: const Color(0xFFE4ECFF),
                              dropdownColor: const Color(0xFF143163),
                              decoration: _inputDecoration('Condition'),
                              items: communityCardConditions
                                  .map(
                                    (condition) => DropdownMenuItem(
                                      value: condition,
                                      child: Text(condition),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() {
                                          _cardCondition =
                                              _safeCardCondition(value);
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Delivery method'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _safeDeliveryMethod(_deliveryMethod),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              iconEnabledColor: const Color(0xFFE4ECFF),
                              dropdownColor: const Color(0xFF143163),
                              decoration: _inputDecoration('Delivery method'),
                              items: communityDeliveryMethods
                                  .map(
                                    (delivery) => DropdownMenuItem(
                                      value: delivery,
                                      child: Text(delivery),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() {
                                          _deliveryMethod =
                                              _safeDeliveryMethod(value);
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 14),
                            _fieldLabel('Location'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _locationController,
                              enabled: !_saving,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                              ),
                              decoration: _inputDecoration(
                                'Manchester, collection point, or general area',
                              ),
                            ),
                            if (_isSwap || _isWanted) ...[
                              const SizedBox(height: 14),
                              _fieldLabel(
                                _isWanted ? 'Looking for' : 'Wanted in trade',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _wantedTradeForController,
                                enabled: !_saving,
                                maxLines: 3,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.35,
                                ),
                                decoration: _inputDecoration(
                                  _isWanted
                                      ? 'Specific cards, sets, condition, and whether you can buy or swap'
                                      : '151 hits, sealed product, vintage holos, or specific cards',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (_isMarketplacePost) ...[
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Trade safety',
                          children: const [
                            TradeSafetyComposerChecklist(),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      _sectionCard(
                        title: 'Photos',
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_imageBase64List.length}/${CommunityImageCodec.maxImagesPerPost}',
                                style: const TextStyle(
                                  color: Color(0xFFF7DE77),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _processingImages ? 'Processing...' : 'Ready',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_imageBase64List.isNotEmpty)
                            SizedBox(
                              height: 126,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imageBase64List.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 92,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16366E),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.10),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: StoredImage(
                                          imageRef: _imageBase64List[index],
                                          fit: BoxFit.cover,
                                          width: 92,
                                          height: 126,
                                        ),
                                      ),
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: InkWell(
                                          onTap: _saving || _processingImages
                                              ? null
                                              : () => _removePhotoAt(index),
                                          borderRadius: BorderRadius.circular(999),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.62),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16366E),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                photoHelp,
                                style: const TextStyle(
                                  color: Color(0xFFC8D4F0),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: (_processingImages || _saving)
                                      ? null
                                      : _addPhotoFromCamera,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: _processingImages
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Camera'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: (_processingImages || _saving)
                                      ? null
                                      : _addPhotosFromGallery,
                                  style: FilledButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: _processingImages
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.photo_library_outlined),
                                  label: const Text('Gallery'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isDiscussionPost
                                ? 'Photos are optional for discussion threads and are stored directly in Firestore, so you do not need Firebase Storage.'
                                : 'Photos are compressed and stored directly in Firestore, so your marketplace listing works without Firebase Storage.',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_saving || _processingImages) ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            submitLabel,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
