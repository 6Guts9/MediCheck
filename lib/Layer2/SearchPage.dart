import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final List<String> _selectedDrugs = [];
  final TextEditingController _searchController = TextEditingController();
  String _result = "Add medications to check for interactions";
  bool _isLoading = false;

  Future<void> _checkInteraction() async {
    // 1. Validation check
    if (_selectedDrugs.length < 1) {
      setState(() {
        _result = "Please add at least one medication to check.";
      });
      return;
    }

    // 2. Start Loading
    setState(() {
      _isLoading = true;
      _result = "Analyzing interaction...";
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('checkInteraction');

      final result = await callable.call({
        'drugs': _selectedDrugs,
      });

      // 3. Process the Data
      final data = result.data;

      // Check if the cloud function sent an error field or a failure severity
      if (data['error'] != null || data['severity'] == "ERROR") {
        setState(() {
          _result = "Error: ${data['error'] ?? data['description'] ?? 'Unknown error'}";
        });
      } else {
        final String severity = (data['severity'] ?? "UNKNOWN").toString();
        final String description = (data['description'] ?? "No description available.").toString();

        setState(() {
          _result = "Severity: ${severity.toUpperCase()}\n\n$description";
        });
      }
    } catch (e) {
      // 4. Handle Network/System errors
      setState(() {
        _result = "Connection failed. Please check your internet and try again.";
      });
      debugPrint("Error calling checkInteraction: $e");
    } finally {
      // 5. ALWAYS re-enable the button, regardless of success or failure
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Interaction Checker",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Add medications to see how they interact with each other and your profile.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),
            _buildSearchField(),
            
            const SizedBox(height: 20),
            
            if (_selectedDrugs.isNotEmpty) ...[
              const Text(
                "Selected Medications:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _selectedDrugs.map((drug) => Chip(
                  label: Text(drug),
                  onDeleted: () {
                    setState(() {
                      _selectedDrugs.remove(drug);
                    });
                  },
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  deleteIcon: const Icon(Icons.close, size: 18),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _checkInteraction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Check Interactions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 40),
            
            const Text(
              "Clinical Analysis Result",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _result.contains("HIGH") || _result.contains("SEVERE") 
                    ? Colors.red.withOpacity(0.3) 
                    : Colors.green.withOpacity(0.3)
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _result,
                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Note: The medical names are from the FDA. The naming of the medicines is American (e.g., Acetaminophen instead of Paracetamol).",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Search & Add Medication",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text == '') {
              return const Iterable<String>.empty();
            }
            try {
              final response = await http.get(Uri.parse(
                  'https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search?terms=${textEditingValue.text}'));
              if (response.statusCode == 200) {
                final List<dynamic> data = jsonDecode(response.body);
                if (data.length >= 2) {
                  final List<dynamic> suggestions = data[1];
                  return suggestions.map((dynamic item) => item.toString());
                }
              }
            } catch (e) {
              debugPrint("Error fetching suggestions: $e");
            }
            return const Iterable<String>.empty();
          },
          onSelected: (String selection) {
            setState(() {
              if (!_selectedDrugs.contains(selection)) {
                _selectedDrugs.add(selection);
              }
            });
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: MediaQuery.of(context).size.width - 50,
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder:
              (context, fieldController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: fieldController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: "Enter medication name...",
                prefixIcon: Icon(Icons.medication_rounded,
                    color: Colors.blue.withOpacity(0.7), size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
