import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/student_screens/tabs/components/push_notification_service.dart'; // Adjust path if needed

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _expandedIndices = {};

  StreamSubscription<RemoteMessage>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();

    _notificationSubscription = PushNotificationService().onMessageStream
        .listen((message) {
          if (mounted) {
            _fetchNotifications();
          }
        });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Authentication token missing.");
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/notifications/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _notifications = data is List ? data : (data['results'] ?? []);
          // Sort by newest first
          _notifications.sort(
            (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load transmissions.');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleExpand(int index, String id, bool isRead) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
        if (!isRead) _markAsRead(index, id);
      }
    });
  }

  Future<void> _markAsRead(int index, String id) async {
    setState(() {
      _notifications[index]['is_read'] = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/notifications/$id/mark_read/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );
    } catch (e) {
      debugPrint("Read sync failed: $e");
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month) {
        return "Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }
      return "${date.day}/${date.month} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ALERTS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transmissions',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(primaryColor, slateColor, textColor)),
        ],
      ),
    );
  }

  Widget _buildBody(Color primaryColor, Color slateColor, Color textColor) {
    if (_isLoading)
      return Center(
        child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
      );
    if (_error != null)
      return _buildErrorState(primaryColor, textColor, slateColor);
    if (_notifications.isEmpty)
      return _buildEmptyState(primaryColor, textColor, slateColor);

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchNotifications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 120.0),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final bool isRead = n['is_read'] ?? false;
          final bool isExpanded = _expandedIndices.contains(index);

          final bool isDirect = n['target_audience'] == 'personal';

          return GestureDetector(
            onTap: () => _toggleExpand(index, n['id'].toString(), isRead),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isRead
                    ? textColor.withOpacity(0.02)
                    : primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isRead
                      ? primaryColor.withOpacity(0.05)
                      : primaryColor.withOpacity(0.2),
                ),
                boxShadow: isRead
                    ? []
                    : [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDirect
                              ? Colors.orange.withOpacity(0.1)
                              : (isRead
                                    ? slateColor.withOpacity(0.1)
                                    : primaryColor.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDirect
                              ? CupertinoIcons.person_fill
                              : CupertinoIcons.antenna_radiowaves_left_right,
                          color: isDirect
                              ? Colors.orange
                              : (isRead ? slateColor : primaryColor),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n['title'] ?? 'Message',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (isDirect)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "PERSONAL",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(n['created_at'] ?? ''),
                              style: TextStyle(
                                color: slateColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: isExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(color: textColor.withOpacity(0.05)),
                                const SizedBox(height: 12),
                                Text(
                                  n['message'] ?? '',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.8),
                                    fontSize: 14,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Color primary, Color text, Color slate) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.bell_slash,
            size: 64,
            color: slate.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Quiet for now',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          Text(
            'We will notify you of any updates.',
            style: TextStyle(fontSize: 14, color: slate),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color primary, Color text, Color slate) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.wifi_exclamationmark,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "Connection Error",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: slate, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _fetchNotifications,
              child: Text(
                'TRY AGAIN',
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
