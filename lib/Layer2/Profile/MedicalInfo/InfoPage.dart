import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../Authentication/auth_services.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final _firestore = FirebaseFirestore.instance;
  final String? _uid = authServices.value.currentUser?.uid;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  String? _selectedGender;
  List<String> _chronicDiseases = [];
  List<String> _allergies = [];
  List<String> _surgeries = [];
  List<Map<String, dynamic>> _medications = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMedicalInfo();
  }

  Future<void> _saveMedicalInfo() async {
    if (_uid == null) return;
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('user').doc(_uid).set({
        'age': int.tryParse(_ageController.text),
        'weight': double.tryParse(_weightController.text),
        'height': double.tryParse(_heightController.text),
        'gender': _selectedGender,
        'ChronicalDiseases': _chronicDiseases,
        'allergies': _allergies,
        'surgeries': _surgeries,
        'current meds': _medications,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medical Information Saved!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMedicalInfo() async {
    if (_uid == null) return;
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot doc = await _firestore.collection('user').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _ageController.text = data['age']?.toString() ?? '';
          _weightController.text = data['weight']?.toString() ?? '';
          _heightController.text = data['height']?.toString() ?? '';

          String? genderFromDb = data['gender'];
          if (genderFromDb != null) {
            String lower = genderFromDb.toLowerCase();
            if (lower == "male") {
              _selectedGender = "Male";
            } else if (lower == "female") {
              _selectedGender = "Female";
            } else if (lower == "other") {
              _selectedGender = "Other";
            } else {
              _selectedGender = null;
            }
          }

          _chronicDiseases = List<String>.from(data['ChronicalDiseases'] ?? []);
          _allergies = List<String>.from(data['allergies'] ?? []);
          _surgeries = List<String>.from(data['surgeries'] ?? []);
          _medications = List<Map<String, dynamic>>.from(data['current meds'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading info: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(radius: 100, backgroundColor: Colors.green.withOpacity(0.4)),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text("Medical Info", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text("Keep your profile updated for better health insights.",
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 30),
                        _buildSectionTitle("Physical Metrics"),
                        Row(
                          children: [
                            Expanded(child: _buildSmallField("Age", _ageController, "yrs")),
                            const SizedBox(width: 10),
                            Expanded(child: _buildGenderDropdown()),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: _buildSmallField("Weight", _weightController, "kg")),
                            const SizedBox(width: 10),
                            Expanded(child: _buildSmallField("Height", _heightController, "cm")),
                          ],
                        ),
                        const SizedBox(height: 30),
                        _buildClinicalAutocompleteSection(
                          "Chronic Diseases",
                          _chronicDiseases,
                          "https://clinicaltables.nlm.nih.gov/api/conditions/v3/search?terms=",
                          (val) => setState(() => _chronicDiseases.add(val)),
                        ),
                        const SizedBox(height: 20),
                        _buildClinicalAutocompleteSection(
                          "Allergies",
                          _allergies,
                          "https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search?terms=",
                          (val) => setState(() => _allergies.add(val)),
                        ),
                        const SizedBox(height: 20),
                        _buildClinicalAutocompleteSection(
                          "Surgeries",
                          _surgeries,
                          "https://clinicaltables.nlm.nih.gov/api/procedures/v3/search?terms=",
                          (val) => setState(() => _surgeries.add(val)),
                        ),
                        const SizedBox(height: 30),
                        _buildSectionTitle("Current Medications"),
                        ..._medications.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var med = entry.value;
                          return _buildMedicationCard(med, idx);
                        }).toList(),
                        _buildAddButton("Add Medication", () => _showMedicationDialog()),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _saveMedicalInfo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: const Text("Save Information", style: TextStyle(color: Colors.white, fontSize: 18)),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildSmallField(String hint, TextEditingController controller, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(" $hint ($unit)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(" Gender", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              hint: const Text("Select"),
              items: ["Male", "Female", "Other"].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalAutocompleteSection(String title, List<String> list, String apiUrl, Function(String) onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Wrap(
          spacing: 8,
          children: list
              .map((item) => Chip(
                    label: Text(item),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => list.remove(item)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text == '') {
              return const Iterable<String>.empty();
            }
            try {
              final response = await http.get(Uri.parse('$apiUrl${textEditingValue.text}'));
              if (response.statusCode == 200) {
                final List<dynamic> data = jsonDecode(response.body);

                if (data.length >= 4 && data[3] != null) {
                  final List<dynamic> matches = data[3];
                  return matches.map((dynamic item) => item.toString());
                }
              }
            } catch (e) {
              debugPrint("Error fetching suggestions: $e");
            }
            return const Iterable<String>.empty();
          },
          onSelected: (String selection) {
            if (!list.contains(selection)) {
              onAdd(selection);
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: "Search $title...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: MediaQuery.of(context).size.width - 40,
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(title: Text(option), onTap: () => onSelected(option));
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blue),
      label: Text(label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> med, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFF4F7F6), child: Icon(Icons.medication, color: Colors.blue)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("${med['dosage'] ?? ''} - ${med['frequency'] ?? ''}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => setState(() => _medications.removeAt(index)),
          )
        ],
      ),
    );
  }

  void _showMedicationDialog() {
    final nameController = TextEditingController();
    final doseController = TextEditingController();
    final freqController = TextEditingController();
    String selectedName = "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue),
            SizedBox(width: 10),
            Text("Add Medication", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(" Drug Name", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),

              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                  try {

                    final response = await http.get(Uri.parse(
                        'https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search?terms=${textEditingValue.text}'));
                    if (response.statusCode == 200) {
                      final List<dynamic> data = jsonDecode(response.body);

                      if (data.length >= 2) {
                        return List<String>.from(data[1]);
                      }
                    }
                  } catch (e) {
                    debugPrint("Autocomplete Error: $e");
                  }
                  return const Iterable<String>.empty();
                },
                onSelected: (String selection) {
                  selectedName = selection;
                  nameController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _buildDialogInputDecoration("e.g., Advil", Icons.medication),
                  );
                },
              ),
              const SizedBox(height: 15),
              const Text(" Dosage", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              TextField(
                controller: doseController,
                decoration: _buildDialogInputDecoration("e.g., 500mg", Icons.straighten),
              ),
              const SizedBox(height: 15),
              const Text(" Frequency", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              TextField(
                controller: freqController,
                decoration: _buildDialogInputDecoration("e.g., Twice daily", Icons.access_time),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final name = nameController.text.isNotEmpty ? nameController.text : selectedName;
              if (name.isNotEmpty) {
                setState(() => _medications.add({
                  'name': name,
                  'dosage': doseController.text,
                  'frequency': freqController.text,
                  'rxNormId': 'N/A',
                }));
                Navigator.pop(context);
              }
            },
            child: const Text("Add to Profile", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  InputDecoration _buildDialogInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.blue.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
