import 'package:flutter/material.dart';
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
        'current meds': _medications, // Space in name to match your screenshot
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medical Information Saved!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // This will show you exactly what the error is if it happens again
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update the load function to match the names too
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
          
          // Normalize gender from DB (e.g. "male") to match Dropdown items (e.g. "Male")
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
              _selectedGender = null; // Reset if invalid
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
            child: CircleAvatar(radius: 100, backgroundColor: Colors.green.withOpacity(0.1)),
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
                  const Text("Keep your profile updated for better health insights.", style: TextStyle(color: Colors.grey)),
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
                  _buildListSection("Chronic Diseases", _chronicDiseases, Icons.healing_outlined, (val) {
                    setState(() => _chronicDiseases.add(val));
                  }),
                  const SizedBox(height: 20),
                  _buildListSection("Allergies", _allergies, Icons.warning_amber_rounded, (val) {
                    setState(() => _allergies.add(val));
                  }),
                  const SizedBox(height: 20),
                  _buildListSection("Surgeries", _surgeries, Icons.personal_injury_outlined, (val) {
                    setState(() => _surgeries.add(val));
                  }),
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

  Widget _buildListSection(String title, List<String> list, IconData icon, Function(String) onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Wrap(
          spacing: 8,
          children: list.map((item) => Chip(
            label: Text(item),
            backgroundColor: Colors.blue.withOpacity(0.1),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () => setState(() => list.remove(item)),
          )).toList(),
        ),
        _buildAddButton("Add $title", () => _showSimpleInputDialog("Add $title", onAdd)),
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
                Text("${med['dosage'] ?? ''} - ${med['frequency'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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

  void _showSimpleInputDialog(String title, Function(String) onAdd) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "Enter value...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            if (controller.text.isNotEmpty) onAdd(controller.text);
            Navigator.pop(context);
          }, child: const Text("Add")),
        ],
      ),
    );
  }

  void _showMedicationDialog() {
    final nameC = TextEditingController();
    final doseC = TextEditingController();
    final freqC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Medication"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Drug Name")),
            TextField(controller: doseC, decoration: const InputDecoration(labelText: "Dosage (e.g. 500mg)")),
            TextField(controller: freqC, decoration: const InputDecoration(labelText: "Frequency (e.g. 2x Daily)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () {
            if (nameC.text.isNotEmpty) {
              setState(() => _medications.add({
                'name': nameC.text,
                'dosage': doseC.text,
                'frequency': freqC.text,
                'rxNormId': 'N/A',
              }));
            }
            Navigator.pop(context);
          }, child: const Text("Add")),
        ],
      ),
    );
  }
}
