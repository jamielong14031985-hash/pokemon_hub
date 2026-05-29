import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessProRequest {
  const BusinessProRequest({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerUid,
    required this.ownerEmail,
    required this.requestType,
    required this.message,
    required this.status,
    required this.adminResponse,
    required this.reviewedBy,
    this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String ownerUid;
  final String ownerEmail;
  final String requestType;
  final String message;
  final String status;
  final String adminResponse;
  final String reviewedBy;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? reviewedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory BusinessProRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessProRequest(
      id: doc.id,
      businessId: cleanString(data['businessId']),
      businessName: cleanString(data['businessName']),
      ownerUid: cleanString(data['ownerUid']),
      ownerEmail: cleanString(data['ownerEmail']),
      requestType: cleanString(data['requestType']),
      message: cleanString(data['message']),
      status: cleanString(data['status']),
      adminResponse: cleanString(data['adminResponse']),
      reviewedBy: cleanString(data['reviewedBy']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
      reviewedAt: cleanTimestamp(data['reviewedAt']),
    );
  }

  String get requestTypeLabel {
    return switch (requestType) {
      'new' => 'New Business Pro request',
      'renewal' => 'Renewal request',
      'upgrade' => 'Upgrade request',
      'question' => 'Question for admin',
      _ => 'Business Pro request',
    };
  }

  String get statusLabel {
    return switch (status) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
  }

  bool get isPending => status == 'pending';

  bool get isApproved => status == 'approved';

  bool get isRejected => status == 'rejected';

  DateTime? get displayDate {
    final timestamp = updatedAt ?? createdAt;
    return timestamp?.toDate();
  }
}
