// ============================================================================
// NEW: MEDICAL DATA ENTRY SCREEN (Interactive & Premium)
// ============================================================================
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:http/http.dart' as http;

class MedicalDataEntryScreen extends StatefulWidget {
  const MedicalDataEntryScreen({super.key});

  @override
  State<MedicalDataEntryScreen> createState() => _MedicalDataEntryScreenState();
}

class _MedicalDataEntryScreenState extends State<MedicalDataEntryScreen> {
  bool _isLoading = true; // Set to true initially to fetch data

  String _selectedBloodType = 'Unknown';
  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  // Multi-Selection State
  final Set<String> _selectedAllergies = {};
  final Set<String> _selectedConditions = {};
  String _selectedRelation = 'Parent';

  // Presets to minimize typing
  final List<String> _allergyPresets = [
    'Peanuts',
    'Penicillin',
    'Dust',
    'Pollen',
    'Shellfish',
    'Latex',
    'Other',
  ];
  final List<String> _conditionPresets = [
    'Asthma',
    'Diabetes',
    'Hypertension',
    'Epilepsy',
    'Anxiety',
    'Other',
  ];
  final List<String> _relationPresets = [
    'Parent',
    'Guardian',
    'Sibling',
    'Spouse',
    'Other',
  ];

  // Controllers for manual entry when "Other" is selected
  final TextEditingController _otherAllergyController = TextEditingController();
  final TextEditingController _otherConditionController =
      TextEditingController();
  final TextEditingController _otherRelationController =
      TextEditingController();

  // Emergency Contact Controllers (Typing required for names/numbers)
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMedicalData();
  }

  @override
  void dispose() {
    _otherAllergyController.dispose();
    _otherConditionController.dispose();
    _otherRelationController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchMedicalData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/medical-profiles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);

        if (dataList.isNotEmpty) {
          final profile = dataList.first;

          setState(() {
            // 1. Blood Type
            final bt = profile['blood_type'] ?? 'Unknown';
            if (_bloodTypes.contains(bt)) {
              _selectedBloodType = bt;
            }

            // 2. Allergies
            final algString = profile['allergies'] ?? 'None';
            if (algString != 'None' && algString.isNotEmpty) {
              final algList = algString
                  .split(',')
                  .map((e) => e.trim())
                  .toList();
              List<String> otherAlgs = [];
              for (var alg in algList) {
                if (_allergyPresets.contains(alg)) {
                  _selectedAllergies.add(alg);
                } else {
                  otherAlgs.add(alg);
                }
              }
              if (otherAlgs.isNotEmpty) {
                _selectedAllergies.add('Other');
                _otherAllergyController.text = otherAlgs.join(', ');
              }
            }

            // 3. Medical Conditions
            final condString = profile['medical_conditions'] ?? 'None';
            if (condString != 'None' && condString.isNotEmpty) {
              final condList = condString
                  .split(',')
                  .map((e) => e.trim())
                  .toList();
              List<String> otherConds = [];
              for (var cond in condList) {
                if (_conditionPresets.contains(cond)) {
                  _selectedConditions.add(cond);
                } else {
                  otherConds.add(cond);
                }
              }
              if (otherConds.isNotEmpty) {
                _selectedConditions.add('Other');
                _otherConditionController.text = otherConds.join(', ');
              }
            }

            // 4. Emergency Contact
            _contactNameController.text =
                profile['emergency_contact_name'] ?? '';
            _contactPhoneController.text =
                profile['emergency_contact_phone'] ?? '';

            final relation = profile['emergency_contact_relation'] ?? 'Parent';
            if (_relationPresets.contains(relation)) {
              _selectedRelation = relation;
            } else {
              _selectedRelation = 'Other';
              _otherRelationController.text = relation;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch medical profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMedicalData() async {
    // Basic Validation
    if (_contactNameController.text.trim().isEmpty ||
        _contactPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency contact name and phone are required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");
      final token = await user.getIdToken();

      // Compile final strings for backend
      List<String> finalAllergies = _selectedAllergies
          .where((a) => a != 'Other')
          .toList();
      if (_selectedAllergies.contains('Other') &&
          _otherAllergyController.text.trim().isNotEmpty) {
        finalAllergies.add(_otherAllergyController.text.trim());
      }

      List<String> finalConditions = _selectedConditions
          .where((c) => c != 'Other')
          .toList();
      if (_selectedConditions.contains('Other') &&
          _otherConditionController.text.trim().isNotEmpty) {
        finalConditions.add(_otherConditionController.text.trim());
      }

      String finalRelation =
          _selectedRelation == 'Other' &&
              _otherRelationController.text.trim().isNotEmpty
          ? _otherRelationController.text.trim()
          : _selectedRelation;

      final Map<String, dynamic> payload = {
        "blood_type": _selectedBloodType,
        "allergies": finalAllergies.isNotEmpty
            ? finalAllergies.join(", ")
            : "None",
        "medical_conditions": finalConditions.isNotEmpty
            ? finalConditions.join(", ")
            : "None",
        "emergency_contact_name": _contactNameController.text.trim(),
        "emergency_contact_phone": _contactPhoneController.text.trim(),
        "emergency_contact_relation": finalRelation,
      };

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/medical-profiles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Medical profile securely encrypted and updated."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception("Failed to update profile: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An error occurred while securing your medical data."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildChipSelector(
    List<String> options,
    Set<String> selectedSet,
    bool isMulti,
  ) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: options.map((option) {
        final isSelected = selectedSet.contains(option);
        return FilterChip(
          label: Text(
            option,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
          selected: isSelected,
          selectedColor: Colors.redAccent,
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Colors.redAccent
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          onSelected: (bool selected) {
            setState(() {
              if (isMulti) {
                selected ? selectedSet.add(option) : selectedSet.remove(option);
              } else {
                selectedSet.clear();
                if (selected) selectedSet.add(option);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(
    String hint,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "MEDICAL PROFILE",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.lock_shield_fill,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "This data is heavily encrypted and only decodes for authorized medical staff during an active emergency.",
                            style: TextStyle(
                              color: Colors.redAccent.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // BLOOD TYPE
                  Text(
                    "BLOOD TYPE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: textColor.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBloodType,
                        dropdownColor: theme.scaffoldBackgroundColor,
                        items: _bloodTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedBloodType = val!),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ALLERGIES
                  Text(
                    "KNOWN ALLERGIES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: textColor.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildChipSelector(_allergyPresets, _selectedAllergies, true),
                  if (_selectedAllergies.contains('Other')) ...[
                    const SizedBox(height: 12),
                    _buildTextInput(
                      "Specify other allergies...",
                      _otherAllergyController,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // MEDICAL CONDITIONS
                  Text(
                    "MEDICAL CONDITIONS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: textColor.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildChipSelector(
                    _conditionPresets,
                    _selectedConditions,
                    true,
                  ),
                  if (_selectedConditions.contains('Other')) ...[
                    const SizedBox(height: 12),
                    _buildTextInput(
                      "Specify other conditions...",
                      _otherConditionController,
                    ),
                  ],

                  const SizedBox(height: 40),
                  Divider(color: textColor.withOpacity(0.1), thickness: 1),
                  const SizedBox(height: 32),

                  // EMERGENCY CONTACT
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.phone_circle_fill,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "EMERGENCY CONTACT",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "RELATIONSHIP",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: textColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedRelation,
                        dropdownColor: theme.scaffoldBackgroundColor,
                        items: _relationPresets
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedRelation = val!),
                      ),
                    ),
                  ),
                  if (_selectedRelation == 'Other') ...[
                    const SizedBox(height: 12),
                    _buildTextInput(
                      "Specify relationship (e.g. Aunt, Friend)",
                      _otherRelationController,
                    ),
                  ],

                  const SizedBox(height: 16),
                  _buildTextInput("Contact Full Name", _contactNameController),
                  const SizedBox(height: 16),
                  _buildTextInput(
                    "Contact Phone Number",
                    _contactPhoneController,
                    type: TextInputType.phone,
                  ),

                  const SizedBox(height: 48),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveMedicalData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.redAccent.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'SECURE & SAVE PROFILE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
