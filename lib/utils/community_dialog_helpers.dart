import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../services/community_safety_service.dart';
import '../widgets/community_rating_sheet.dart';

Future<bool> showCommunityReportSheet({
  required BuildContext context,
  required AppUserProfile currentProfile,
  required String reportedUid,
  required String reportedName,
  required String targetType,
  required String targetId,
  required String targetTitle,
}) async {
  final detailsController = TextEditingController();
  const reasons = <String>[
    'Scam or fraud',
    'Harassment or abuse',
    'Inappropriate content',
    'Spam',
    'Unsafe trade or meetup',
    'Other',
  ];
  var selectedReason = reasons.first;
  var submitting = false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF102754),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            if (submitting) return;
            setSheetState(() => submitting = true);
            try {
              await CommunitySafetyService.submitReport(
                currentProfile: currentProfile,
                reportedUid: reportedUid,
                reportedName: reportedName,
                targetType: targetType,
                targetId: targetId,
                targetTitle: targetTitle,
                reason: selectedReason,
                details: detailsController.text,
              );
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop(true);
              }
            } catch (error) {
              if (sheetContext.mounted) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                );
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => submitting = false);
              }
            }
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const Text(
                      'Report community content',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us what is wrong with “${targetTitle.trim().isEmpty ? reportedName : targetTitle}”. Reports are saved for moderation review.',
                      style: const TextStyle(
                        color: Color(0xFFC8D4F0),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      dropdownColor: const Color(0xFF16366E),
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        labelStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: reasons
                          .map(
                            (reason) => DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            ),
                          )
                          .toList(),
                      onChanged: submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setSheetState(() => selectedReason = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      minLines: 3,
                      maxLines: 5,
                      enabled: !submitting,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Details (optional)',
                        hintText: 'Add anything that helps explain the report...',
                        labelStyle: TextStyle(color: Color(0xFFAFC0E6)),
                        hintStyle: TextStyle(color: Color(0xFF8FA4D0)),
                        filled: true,
                        fillColor: Color(0xFF16366E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: submitting ? null : () => Navigator.of(sheetContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: submitting ? null : submit,
                            icon: submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.flag_outlined),
                            label: const Text('Submit report'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  detailsController.dispose();
  if (result == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted for review.')),
    );
  }
  return result == true;
}

Future<bool> confirmBlockCommunityUser({
  required BuildContext context,
  required AppUserProfile currentProfile,
  required String blockedUid,
  required String blockedName,
  String source = 'community',
}) async {
  final trimmedBlockedUid = blockedUid.trim();
  final safeName = blockedName.trim().isEmpty ? 'this member' : blockedName.trim();
  if (trimmedBlockedUid.isEmpty || trimmedBlockedUid == currentProfile.uid) {
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF102754),
        title: const Text(
          'Block member?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'You will stop seeing posts, replies and private inbox threads from $safeName. You can unblock them later from Community > Blocked users.',
          style: const TextStyle(color: Color(0xFFD8E3FB), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB13B59),
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return false;

  try {
    await CommunitySafetyService.blockUser(
      currentProfile: currentProfile,
      blockedUid: trimmedBlockedUid,
      blockedName: safeName,
      source: source,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$safeName blocked.')),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
    return false;
  }
}

Future<bool?> showCommunityRatingSheet({
  required BuildContext context,
  required AppUserProfile currentProfile,
  required String sellerId,
  required String sellerName,
  String sourcePostId = '',
  String sourcePostTitle = '',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF102754),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => CommunityRatingSheet(
      currentProfile: currentProfile,
      sellerId: sellerId,
      sellerName: sellerName,
      sourcePostId: sourcePostId,
      sourcePostTitle: sourcePostTitle,
    ),
  );
}
