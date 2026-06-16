import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class StaffNotifications extends StatefulWidget {
  const StaffNotifications({super.key});

  @override
  State<StaffNotifications> createState() => _StaffNotificationsState();
}

class _StaffNotificationsState extends State<StaffNotifications> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      // Perfect Endpoint: The backend automatically filters for the authenticated staff member
      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/notifications/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _notifications = data is List ? data : (data['results'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load notifications.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network error. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/notifications/$id/mark_read/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _notifications[index]['is_read'] = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to mark as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "SYSTEM ALERTS",
          style: TextStyle(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.redAccent.shade400),
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Text(
                        "No new alerts",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: primaryColor,
                      onRefresh: _fetchNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final bool isRead = notif['is_read'] ?? false;
                          final bool isEmergency = notif['title'].toString().toUpperCase().contains("EMERGENCY");
                          final Color cardAccent = isEmergency ? Colors.redAccent : primaryColor;

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) _markAsRead(notif['id'].toString(), index);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: isRead ? Colors.transparent : cardAccent.withOpacity(0.05),
                                border: Border.all(
                                  color: isRead ? Colors.grey.withOpacity(0.2) : cardAccent.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: cardAccent.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isEmergency ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.bell_fill,
                                            color: cardAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      notif['title'] ?? 'Alert',
                                                      style: TextStyle(
                                                        color: theme.colorScheme.onSurface,
                                                        fontSize: 15,
                                                        fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: cardAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                notif['message'] ?? '',
                                                style: TextStyle(
                                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                                  fontSize: 13,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}