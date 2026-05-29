import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessEnquiry {
  const BusinessEnquiry({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.businessOwnerUid,
    required this.senderUid,
    required this.senderName,
    required this.senderEmail,
    required this.enquiryType,
    required this.subject,
    required this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String businessOwnerUid;
  final String senderUid;
  final String senderName;
  final String senderEmail;
  final String enquiryType;
  final String subject;
  final String message;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? closedAt;

  static String cleanString(dynamic value) => (value ?? '').toString().trim();

  static Timestamp? cleanTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  factory BusinessEnquiry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return BusinessEnquiry(
      id: doc.id,
      businessId: cleanString(data['businessId']),
      businessName: cleanString(data['businessName']),
      businessOwnerUid: cleanString(data['businessOwnerUid']),
      senderUid: cleanString(data['senderUid']),
      senderName: cleanString(data['senderName']),
      senderEmail: cleanString(data['senderEmail']),
      enquiryType: cleanString(data['enquiryType']),
      subject: cleanString(data['subject']),
      message: cleanString(data['message']),
      status: cleanString(data['status']),
      createdAt: cleanTimestamp(data['createdAt']),
      updatedAt: cleanTimestamp(data['updatedAt']),
      closedAt: cleanTimestamp(data['closedAt']),
    );
  }

  String get enquiryTypeLabel {
    return switch (enquiryType) {
      'stock' => 'Stock enquiry',
      'event' => 'Event enquiry',
      'product' => 'Product enquiry',
      'trade' => 'Trade / sell enquiry',
      'general' => 'General enquiry',
      _ => 'Enquiry',
    };
  }

  String get statusLabel {
    return switch (status) {
      'open' => 'Open',
      'replied' => 'Replied',
      'closed' => 'Closed',
      _ => 'Open',
    };
  }

  bool get isOpen => status == 'open';

  bool get isClosed => status == 'closed';

  String get displaySenderName {
    return senderName.trim().isEmpty ? 'PocketChase user' : senderName.trim();
  }

  DateTime? get displayDate {
    final timestamp = updatedAt ?? createdAt;
    return timestamp?.toDate();
  }
}
