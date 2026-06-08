// ignore_for_file: unused_element, unused_field, unused_element_parameter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key});

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  static const Color _backgroundColor = Color(0xFF041B4A);
  static const Color _cardColor = Color(0xFF102754);
  static const Color _fieldColor = Color(0xFF16366E);
  static const Color _borderColor = Color(0xFF3F5C96);
  static const Color _goldColor = Color(0xFFF7DE77);
  static const Color _softTextColor = Color(0xFFC8D4F0);
  static const Color _successColor = Color(0xFF4ADE80);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Stream<int> _countStream(String collection, {String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Stream<int> countStream,
    required String countLabel,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: _borderColor),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _goldColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _goldColor.withValues(alpha: 0.32)),
                    ),
                    child: Icon(icon, color: _goldColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _softTextColor,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? _goldColor.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: count > 0 ? _goldColor : Colors.white24,
                            ),
                          ),
                          child: Text(
                            '$count $countLabel',
                            style: TextStyle(
                              color: count > 0 ? _goldColor : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Tools'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _goldColor),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: _goldColor, size: 42),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Manage PocketChase',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _toolCard(
            icon: Icons.feedback_outlined,
            title: 'Feedback Reports',
            subtitle: 'View tester problem reports, screenshots and device details.',
            countStream: _countStream('feedback_reports', status: 'new'),
            countLabel: 'new',
            onTap: () => _open(const AdminFeedbackReportsPage()),
          ),
          _toolCard(
            icon: Icons.workspace_premium_outlined,
            title: 'User Pro Access',
            subtitle: 'Give or remove Pro access for testers and users.',
            countStream: _countStream('user_feature_flags'),
            countLabel: 'records',
            onTap: () => _open(const AdminProAccessPage()),
          ),
          _toolCard(
            icon: Icons.add_location_alt_outlined,
            title: 'Shop Requests',
            subtitle: 'Approve or reject user-submitted TCG shops.',
            countStream: _countStream('tcg_shop_submissions', status: 'pending'),
            countLabel: 'pending',
            onTap: () => _open(const AdminShopRequestsPage()),
          ),
          _toolCard(
            icon: Icons.business_center_outlined,
            title: 'Business Requests',
            subtitle: 'Review business Pro requests and business profiles.',
            countStream: _countStream('business_pro_requests', status: 'pending'),
            countLabel: 'pending',
            onTap: () => _open(const AdminBusinessToolsPage()),
          ),
          _toolCard(
            icon: Icons.storefront_outlined,
            title: 'Business Profiles',
            subtitle: 'Approve, reject and manage Pro/featured business profiles.',
            countStream: _countStream('business_profiles', status: 'pending'),
            countLabel: 'pending',
            onTap: () => _open(const AdminBusinessProfilesPage()),
          ),
        ],
      ),
    );
  }
}

class AdminProAccessPage extends StatefulWidget {
  const AdminProAccessPage({super.key});

  @override
  State<AdminProAccessPage> createState() => _AdminProAccessPageState();
}

class _AdminProAccessPageState extends State<AdminProAccessPage> {
  static const Color _backgroundColor = _AdminToolsPageState._backgroundColor;
  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _fieldColor = _AdminToolsPageState._fieldColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;

  final TextEditingController _userController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
  bool _busy = false;

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  Future<String?> _uidFromInput(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    if (!clean.contains('@')) return clean;

    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: clean)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return query.docs.first.id;
  }

  Future<void> _setProForUid(String uid, bool enabled) async {
    final cleanUid = uid.trim();

    if (cleanUid.isEmpty) {
      _showMessage('Could not update Pro access because the user ID is missing.');
      return;
    }

    await _firestore.collection('user_feature_flags').doc(cleanUid).set(
      <String, dynamic>{
        'userId': cleanUid,
        'restockAlertsEnabled': false,
        'proEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUid,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _setProFromInput(bool enabled) async {
    if (_busy) return;

    final input = _userController.text.trim();
    if (input.isEmpty) {
      _showMessage('Enter a UID or email first.');
      return;
    }

    setState(() => _busy = true);

    try {
      final uid = await _uidFromInput(input);
      if (uid == null || uid.isEmpty) {
        _showMessage('Could not find that user. Try their Firebase UID.');
        return;
      }

      await _setProForUid(uid, enabled);

      _showMessage(enabled ? 'Pro access enabled.' : 'Pro access removed.');
      _userController.clear();
    } catch (error) {
      _showMessage('Could not update Pro access: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleProForUser(String uid, bool enabled) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _setProForUid(uid, enabled);
      _showMessage(enabled ? 'Pro access enabled.' : 'Pro access removed.');
    } catch (error) {
      _showMessage('Could not update Pro access: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteUserAccount(String uid, String displayName) async {
    if (_busy) return;

    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      _showMessage('Could not delete user because the UID is missing.');
      return;
    }

    if (cleanUid == _currentUid) {
      _showMessage('You cannot delete your own admin account from here.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete user?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will permanently delete $displayName from PocketChase. This should only be used for test accounts, fake accounts, or users who need removing.\n\nThis cannot be undone.',
            style: const TextStyle(
              color: _softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text(
                'Delete user',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call(<String, dynamic>{
        'uid': cleanUid,
      });

      _showMessage('User deleted.');
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Could not delete user.');
    } catch (error) {
      _showMessage('Could not delete user: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return _firestore.collection('users').limit(250).snapshots();
  }

  String _userSortName(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final username = (data['username'] ?? data['displayName'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();

    return (username.isNotEmpty ? username : email).toLowerCase();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final users = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    users.sort((a, b) => _userSortName(a).compareTo(_userSortName(b)));

    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('User Pro Access'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _SectionCard(
            title: 'Give or remove Pro manually',
            child: Column(
              children: [
                TextField(
                  controller: _userController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  cursorColor: _goldColor,
                  decoration: _inputDecoration(
                    label: 'User UID or email',
                    hint: 'Paste Firebase UID, or try email address',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _setProFromInput(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Remove'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _setProFromInput(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: _backgroundColor,
                        ),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('Give Pro'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Users',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toggle Pro on or off next to the username.',
            style: TextStyle(
              color: _softTextColor,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _AdminErrorState(error: snapshot.error.toString());
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: _goldColor));
              }

              final docs = _sortedUsers(
                snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[],
              );

              if (docs.isEmpty) {
                return const _EmptyAdminState(message: 'No users found.');
              }

              return Column(
                children: docs.map((doc) {
                  return _AdminProUserTile(
                    uid: doc.id,
                    userData: doc.data(),
                    firestore: _firestore,
                    busy: _busy,
                    onToggle: _toggleProForUser,
                    onDelete: _deleteUserAccount,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _softTextColor),
      hintStyle: const TextStyle(color: Color(0xFFAFC0E6)),
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
        borderSide: const BorderSide(color: _goldColor),
      ),
    );
  }
}

class _AdminProUserTile extends StatelessWidget {
  const _AdminProUserTile({
    required this.uid,
    required this.userData,
    required this.firestore,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
  });

  final String uid;
  final Map<String, dynamic> userData;
  final FirebaseFirestore firestore;
  final bool busy;
  final Future<void> Function(String uid, bool enabled) onToggle;
  final Future<void> Function(String uid, String displayName) onDelete;

  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;

  String _text(String key) {
    return (userData[key] ?? '').toString().trim();
  }

  String get _username {
    final username = _text('username');
    final displayName = _text('displayName');
    final businessName = _text('businessName');
    final email = _text('email');

    if (businessName.isNotEmpty) return businessName;
    if (username.isNotEmpty) return username;
    if (displayName.isNotEmpty) return displayName;
    if (email.isNotEmpty) return email;

    return uid;
  }

  String get _email => _text('email');

  String get _accountType {
    final accountType = _text('accountType');

    if (accountType.isEmpty) return 'standard';

    return accountType;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('user_feature_flags').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final flags = snapshot.data?.data() ?? <String, dynamic>{};
        final isPro = flags['proEnabled'] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isPro ? _goldColor : _borderColor,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _goldColor.withValues(alpha: isPro ? 0.20 : 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _goldColor.withValues(alpha: isPro ? 0.55 : 0.25),
                    ),
                  ),
                  child: Icon(
                    isPro
                        ? Icons.workspace_premium
                        : Icons.person_outline_rounded,
                    color: _goldColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (_email.isNotEmpty)
                        Text(
                          _email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _softTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniAdminBadge(label: _accountType),
                          _MiniAdminBadge(label: isPro ? 'Pro on' : 'Pro off'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: isPro,
                      activeThumbColor: _goldColor,
                      onChanged: busy ? null : (value) => onToggle(uid, value),
                    ),
                    IconButton(
                      tooltip: 'Delete user',
                      onPressed: busy ? null : () => onDelete(uid, _username),
                      icon: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniAdminBadge extends StatelessWidget {
  const _MiniAdminBadge({required this.label});

  final String label;

  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;

  @override
  Widget build(BuildContext context) {
    final isPro = label.toLowerCase().contains('pro on');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isPro
            ? _goldColor.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isPro ? _goldColor : Colors.white24,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPro ? _goldColor : _softTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AdminShopRequestsPage extends StatelessWidget {
  const AdminShopRequestsPage({super.key});

  static const Color _backgroundColor = _AdminToolsPageState._backgroundColor;
  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;
  static const Color _successColor = _AdminToolsPageState._successColor;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _firestore
        .collection('tcg_shop_submissions')
        .where('status', isEqualTo: 'pending')
        .limit(150)
        .snapshots();
  }

  Future<void> _approve(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final now = FieldValue.serverTimestamp();

    try {
      final shopData = Map<String, dynamic>.from(data)
        ..remove('submittedBy')
        ..remove('submittedByEmail')
        ..remove('updatedAt')
        ..remove('createdAt')
        ..['status'] = 'approved'
        ..['updatedAt'] = now
        ..['createdAt'] = data['createdAt'] ?? now;

      final batch = _firestore.batch();
      batch.set(_firestore.collection('tcg_shops').doc(doc.id), shopData, SetOptions(merge: true));
      batch.delete(doc.reference);
      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop request approved and removed.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not approve shop: $error')),
      );
    }
  }

  Future<void> _reject(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await doc.reference.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop request rejected and removed.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject shop: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionPage(
      title: 'Shop Requests',
      stream: _stream(),
      emptyMessage: 'No shop requests found.',
      itemBuilder: (context, doc) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString();
        final name = (data['name'] ?? 'Unnamed shop').toString();
        final town = (data['town'] ?? '').toString();
        final county = (data['county'] ?? '').toString();
        final address = (data['address'] ?? '').toString();
        final imageUrl = (data['imageUrl'] ?? '').toString().trim();

        return _RequestCard(
          title: name,
          subtitle: [town, county].where((item) => item.trim().isNotEmpty).join(', '),
          status: status,
          imageUrl: imageUrl,
          lines: [
            if (address.trim().isNotEmpty) 'Address: $address',
            if ((data['postcode'] ?? '').toString().trim().isNotEmpty)
              'Postcode: ${data['postcode']}',
            if ((data['website'] ?? '').toString().trim().isNotEmpty)
              'Website: ${data['website']}',
            if ((data['submittedByEmail'] ?? '').toString().trim().isNotEmpty)
              'Submitted by: ${data['submittedByEmail']}',
          ],
          approveLabel: 'Approve shop',
          rejectLabel: 'Reject',
          onApprove: status == 'pending' ? () => _approve(context, doc) : null,
          onReject: status == 'pending' ? () => _reject(context, doc) : null,
        );
      },
    );
  }
}

class AdminBusinessToolsPage extends StatelessWidget {
  const AdminBusinessToolsPage({super.key});

  static const Color _backgroundColor = _AdminToolsPageState._backgroundColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _firestore
        .collection('business_pro_requests')
        .where('status', isEqualTo: 'pending')
        .limit(150)
        .snapshots();
  }

  Future<void> _setStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    try {
      final businessId = (doc.data()['businessId'] ?? doc.data()['profileId'] ?? '').toString().trim();
      final ownerUid = (doc.data()['ownerUid'] ?? '').toString().trim();

      if (status != 'approved') {
        await doc.reference.delete();
      }

      if (status == 'approved' && businessId.isNotEmpty) {
        await _firestore.collection('business_profiles').doc(businessId).set(<String, dynamic>{
          'premiumActive': true,
          'premiumSource': 'admin',
          'premiumStartedAt': FieldValue.serverTimestamp(),
          'premiumAdminNotes': 'Approved from admin tools',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _currentUid,
        }, SetOptions(merge: true));
      }

      if (status == 'approved' && ownerUid.isNotEmpty) {
        await _firestore.collection('user_feature_flags').doc(ownerUid).set(<String, dynamic>{
          'userId': ownerUid,
          'restockAlertsEnabled': false,
          'proEnabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _currentUid,
        }, SetOptions(merge: true));
      }

      if (status == 'approved') {
        await doc.reference.delete();
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Business request approved and removed.'
                : 'Business request rejected and removed.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionPage(
      title: 'Business Requests',
      stream: _stream(),
      emptyMessage: 'No business Pro requests found.',
      itemBuilder: (context, doc) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString();
        final name = (data['businessName'] ?? data['name'] ?? 'Business request').toString();

        return _RequestCard(
          title: name,
          subtitle: (data['ownerEmail'] ?? data['email'] ?? '').toString(),
          status: status,
          imageUrl: '',
          lines: [
            if ((data['ownerUid'] ?? '').toString().trim().isNotEmpty) 'Owner: ${data['ownerUid']}',
            if ((data['businessId'] ?? '').toString().trim().isNotEmpty) 'Business ID: ${data['businessId']}',
            if ((data['message'] ?? '').toString().trim().isNotEmpty) 'Message: ${data['message']}',
          ],
          approveLabel: 'Approve Pro',
          rejectLabel: 'Reject',
          onApprove: status == 'pending' ? () => _setStatus(context, doc, 'approved') : null,
          onReject: status == 'pending' ? () => _setStatus(context, doc, 'rejected') : null,
        );
      },
    );
  }
}

class AdminBusinessProfilesPage extends StatelessWidget {
  const AdminBusinessProfilesPage({super.key});

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return _firestore
        .collection('business_profiles')
        .orderBy('updatedAt', descending: true)
        .limit(150)
        .snapshots();
  }

  Future<void> _updateProfile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> updates,
    String message,
  ) async {
    try {
      await doc.reference.set(<String, dynamic>{
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUid,
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update business: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionPage(
      title: 'Business Profiles',
      stream: _stream(),
      emptyMessage: 'No business profiles found.',
      itemBuilder: (context, doc) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString();
        final name = (data['businessName'] ?? 'Business profile').toString();
        final premiumActive = data['premiumActive'] == true;
        final featuredShopEnabled = data['featuredShopEnabled'] == true;
        final autoFeaturePosts = data['autoFeaturePosts'] == true;

        return _RequestCard(
          title: name,
          subtitle: (data['ownerEmail'] ?? '').toString(),
          status: premiumActive ? '$status • Pro' : status,
          imageUrl: (data['logoUrl'] ?? '').toString(),
          lines: [
            if ((data['town'] ?? '').toString().trim().isNotEmpty) 'Town: ${data['town']}',
            if ((data['website'] ?? '').toString().trim().isNotEmpty) 'Website: ${data['website']}',
            'Featured shop: ${featuredShopEnabled ? 'Yes' : 'No'}',
            'Auto feature posts: ${autoFeaturePosts ? 'Yes' : 'No'}',
          ],
          approveLabel: status == 'approved' ? 'Give Pro' : 'Approve',
          rejectLabel: status == 'rejected' ? 'Rejected' : 'Reject',
          onApprove: () => _updateProfile(
            context,
            doc,
            status == 'approved'
                ? <String, dynamic>{
                    'premiumActive': true,
                    'premiumSource': 'admin',
                    'premiumStartedAt': FieldValue.serverTimestamp(),
                    'featuredShopEnabled': true,
                    'autoFeaturePosts': true,
                  }
                : <String, dynamic>{
                    'status': 'approved',
                    'verified': true,
                  },
            status == 'approved' ? 'Business Pro enabled.' : 'Business approved.',
          ),
          onReject: status == 'rejected'
              ? null
              : () => _updateProfile(
                    context,
                    doc,
                    <String, dynamic>{'status': 'rejected'},
                    'Business rejected.',
                  ),
        );
      },
    );
  }
}

class AdminFeedbackReportsPage extends StatelessWidget {
  const AdminFeedbackReportsPage({super.key});

  static const Color _backgroundColor = _AdminToolsPageState._backgroundColor;
  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;
  static const Color _successColor = _AdminToolsPageState._successColor;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('feedback_reports')
        .orderBy('createdAtMs', descending: true)
        .limit(150)
        .snapshots();
  }

  Future<void> _setStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    try {
      await ref.set(<String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

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


  Future<void> _deleteReport(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Delete report?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will permanently delete this feedback report and any screenshots attached to it. This cannot be undone.',
            style: TextStyle(
              color: _softTextColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storagePaths = _imageStoragePaths(data);

      for (final path in storagePaths) {
        try {
          await FirebaseStorage.instance.ref(path).delete();
        } catch (_) {
          // Keep deleting the Firestore report even if an old screenshot path
          // is already missing from Storage.
        }
      }

      await ref.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report deleted.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete report: $error')),
      );
    }
  }

  List<String> _imageStoragePaths(Map<String, dynamic> data) {
    final paths = <String>[];

    final rawPaths = data['imageStoragePaths'];
    if (rawPaths is List) {
      paths.addAll(
        rawPaths
            .whereType<String>()
            .map((path) => path.trim())
            .where((path) => path.isNotEmpty),
      );
    }

    final rawImages = data['images'];
    if (rawImages is List) {
      for (final image in rawImages) {
        if (image is Map) {
          final path = (image['storagePath'] ?? '').toString().trim();
          if (path.isNotEmpty) {
            paths.add(path);
          }
        }
      }
    }

    return paths.toSet().toList();
  }

  List<String> _imageUrls(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is List) {
      return raw.whereType<String>().where((url) => url.trim().isNotEmpty).toList();
    }
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Feedback Reports'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _goldColor));
          }

          final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return const _EmptyAdminState(message: 'No feedback reports found.');
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 330,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final status = (data['status'] ?? 'new').toString();
              final images = _imageUrls(data);

              return _FeedbackReportGridCard(
                title: (data['screen'] ?? 'Feedback report').toString(),
                subtitle: '${data['type'] ?? 'Problem'} • ${data['impact'] ?? 'No impact added'}',
                status: status,
                imageUrl: images.isEmpty ? '' : images.first,
                whatHappened: (data['whatHappened'] ?? '').toString(),
                deviceUsed: (data['deviceUsed'] ?? '').toString(),
                versionInfo: (data['versionInfo'] ?? '').toString(),
                userEmail: (data['userEmail'] ?? '').toString(),
                screenshotCount: images.length,
                onApprove: status == 'reviewed' ? null : () => _setStatus(context, doc.reference, 'reviewed'),
                onReject: status == 'closed' ? null : () => _setStatus(context, doc.reference, 'closed'),
                onDelete: status == 'closed'
                    ? () => _deleteReport(context, doc.reference, data)
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminFeedbackReportDetailsPage(reportId: doc.id, data: data),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class _FeedbackReportGridCard extends StatelessWidget {
  const _FeedbackReportGridCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.imageUrl,
    required this.whatHappened,
    required this.deviceUsed,
    required this.versionInfo,
    required this.userEmail,
    required this.screenshotCount,
    this.onApprove,
    this.onReject,
    this.onDelete,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final String imageUrl;
  final String whatHappened;
  final String deviceUsed;
  final String versionInfo;
  final String userEmail;
  final int screenshotCount;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _fieldColor = _AdminToolsPageState._fieldColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;

  String _clean(String value, {String fallback = ''}) {
    final clean = value.trim();
    return clean.isEmpty ? fallback : clean;
  }

  @override
  Widget build(BuildContext context) {
    final cleanImageUrl = imageUrl.trim();
    final cleanTitle = _clean(title, fallback: 'Feedback report');
    final cleanSubtitle = _clean(subtitle);
    final cleanWhatHappened = _clean(whatHappened);
    final cleanDevice = _clean(deviceUsed);
    final cleanVersion = _clean(versionInfo);
    final cleanUser = _clean(userEmail);

    return Card(
      margin: EdgeInsets.zero,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cleanImageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    height: 72,
                    width: double.infinity,
                    child: Image.network(
                      cleanImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _fieldColor,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: _softTextColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      cleanTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusBadge(label: status),
                ],
              ),
              if (cleanSubtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  cleanSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ],
              if (cleanWhatHappened.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  'What happened: $cleanWhatHappened',
                  maxLines: cleanImageUrl.isEmpty ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    height: 1.20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (cleanDevice.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Device: $cleanDevice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (cleanVersion.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'Version: $cleanVersion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (cleanUser.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'User: $cleanUser',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (screenshotCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$screenshotCount screenshot${screenshotCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _goldColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: onDelete ?? onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: onDelete != null
                              ? Colors.redAccent
                              : (onReject == null ? Colors.white38 : Colors.redAccent),
                          side: BorderSide(
                            color: onDelete != null
                                ? Colors.redAccent
                                : (onReject == null ? Colors.white24 : Colors.redAccent),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: Icon(
                          onDelete != null
                              ? Icons.delete_forever_outlined
                              : Icons.close,
                          size: 16,
                        ),
                        label: Text(
                          onDelete != null ? 'Delete' : 'Close',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: onDelete != null ? onTap : onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: const Color(0xFF041B4A),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: Icon(
                          onDelete != null
                              ? Icons.open_in_new
                              : Icons.check,
                          size: 16,
                        ),
                        label: Text(
                          onDelete != null ? 'Open' : 'Done',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminFeedbackReportDetailsPage extends StatelessWidget {
  const AdminFeedbackReportDetailsPage({
    super.key,
    required this.reportId,
    required this.data,
  });

  final String reportId;
  final Map<String, dynamic> data;

  static const Color _backgroundColor = _AdminToolsPageState._backgroundColor;
  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;
  static const Color _fieldColor = _AdminToolsPageState._fieldColor;

  String _text(String key) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? 'Not added' : value;
  }

  List<String> _imageUrls() {
    final raw = data['imageUrls'];
    if (raw is List) {
      return raw.whereType<String>().where((url) => url.trim().isNotEmpty).toList();
    }
    return const <String>[];
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText(
        '$label: $value',
        style: const TextStyle(color: _softTextColor, height: 1.35, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _imageUrls();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Report details'),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _section('Report', [
            _row('ID', reportId),
            _row('Status', _text('status')),
            _row('Type', _text('type')),
            _row('Impact', _text('impact')),
            _row('Screen', _text('screen')),
          ]),
          const SizedBox(height: 12),
          _section('Problem', [
            _row('Trying to do', _text('tryingToDo')),
            _row('What happened', _text('whatHappened')),
            _row('Expected', _text('expectedResult')),
            _row('Steps', _text('stepsToReproduce')),
          ]),
          const SizedBox(height: 12),
          _section('Device and user', [
            _row('Device', _text('deviceUsed')),
            _row('Version', _text('versionInfo')),
            _row('Platform', _text('devicePlatform')),
            _row('User email', _text('userEmail')),
            _row('Username', _text('username')),
            _row('UID', _text('userId')),
          ]),
          const SizedBox(height: 12),
          _section('Screenshots', [
            if (images.isEmpty)
              const Text(
                'No screenshots attached.',
                style: TextStyle(color: _softTextColor, fontWeight: FontWeight.w700),
              )
            else
              ...images.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(14),
                        color: _fieldColor,
                        child: const Text(
                          'Could not load screenshot.',
                          style: TextStyle(color: _softTextColor),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ]),
        ],
      ),
    );
  }
}

class _AdminCollectionPage extends StatelessWidget {
  const _AdminCollectionPage({
    required this.title,
    required this.stream,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String emptyMessage;
  final Widget Function(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) itemBuilder;

  static const Color _backgroundColor = _AdminToolsPageState._backgroundColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;


  int _sortMs(Map<String, dynamic> data) {
    final createdAtMs = data['createdAtMs'];
    final updatedAtMs = data['updatedAtMs'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    if (createdAtMs is int) return createdAtMs;
    if (updatedAtMs is int) return updatedAtMs;

    if (createdAt is Timestamp) {
      return createdAt.millisecondsSinceEpoch;
    }

    if (updatedAt is Timestamp) {
      return updatedAt.millisecondsSinceEpoch;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminErrorState(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _goldColor));
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )..sort((a, b) => _sortMs(b.data()).compareTo(_sortMs(a.data())));

          if (docs.isEmpty) {
            return _EmptyAdminState(message: emptyMessage);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 300
                      ? 2
                      : 1;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: docs.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 255,
                ),
                itemBuilder: (context, index) => itemBuilder(context, docs[index]),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.imageUrl,
    required this.lines,
    required this.approveLabel,
    required this.rejectLabel,
    this.onApprove,
    this.onReject,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final String imageUrl;
  final List<String> lines;
  final String approveLabel;
  final String rejectLabel;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onTap;

  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _fieldColor = _AdminToolsPageState._fieldColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _goldColor = _AdminToolsPageState._goldColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;

  String _shortButtonLabel(String value) {
    final clean = value.trim().toLowerCase();

    if (clean.contains('approve')) return 'Approve';
    if (clean.contains('reject')) return 'Reject';
    if (clean.contains('pro')) return 'Pro';

    return value.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cleanImageUrl = imageUrl.trim();
    final cleanTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final cleanSubtitle = subtitle.trim();
    final cleanLines = lines.where((line) => line.trim().isNotEmpty).take(3).toList();
    final shortApproveLabel = _shortButtonLabel(approveLabel);
    final shortRejectLabel = _shortButtonLabel(rejectLabel);

    return Card(
      margin: EdgeInsets.zero,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cleanImageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Image.network(
                      cleanImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _fieldColor,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: _softTextColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      cleanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(child: _StatusBadge(label: status)),
                ],
              ),
              if (cleanSubtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  cleanSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _fieldColor.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor.withValues(alpha: 0.82)),
                  ),
                  child: cleanLines.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: cleanLines.map((line) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _softTextColor,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              onReject == null ? Colors.white38 : Colors.redAccent,
                          side: BorderSide(
                            color:
                                onReject == null ? Colors.white24 : Colors.redAccent,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                        icon: const Icon(Icons.close, size: 13),
                        label: Text(
                          shortRejectLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: _goldColor,
                          foregroundColor: const Color(0xFF041B4A),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                        icon: const Icon(Icons.check, size: 13),
                        label: Text(
                          shortApproveLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase().replaceAll('·', '•').trim();
    final color = switch (normalized) {
      'approved' || 'reviewed' || 'closed' || 'approved • pro' => const Color(0xFF4ADE80),
      'rejected' => Colors.redAccent,
      _ => const Color(0xFFF7DE77),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  const _AdminListTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  static const Color _cardColor = _AdminToolsPageState._cardColor;
  static const Color _borderColor = _AdminToolsPageState._borderColor;
  static const Color _softTextColor = _AdminToolsPageState._softTextColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _borderColor),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: _softTextColor)),
        trailing: trailing,
      ),
    );
  }
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _AdminToolsPageState._softTextColor, height: 1.35),
        ),
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
        child: Text(
          'Could not load admin data: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _AdminToolsPageState._softTextColor, height: 1.35),
        ),
      ),
    );
  }
}
