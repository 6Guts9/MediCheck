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
  final TextEditingController _drugAController = TextEditingController();
  final TextEditingController _drugBController = TextEditingController();
  String _result = "Enter drugs to check for interactions";
  bool _isLoading = false;

  Future<void> _checkInteraction() async {
    if (_drugAController.text.isEmpty || _drugBController.text.isEmpty) {
      setState(() {
        _result = "Please enter both drug names.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = "Analyzing interaction...";
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('checkInteraction');
      final result = await callable.call({
        'drugA': _drugAController.text,
        'drugB': _drugBController.text,
      });

      final data = result.data;
      
      if (data['error'] != null) {
        setState(() {
          _result = "Error: ${data['error']}";
          _isLoading = false;
        });
      } else {
        final String severity = (data['severity'] ?? "UNKNOWN").toString();
        final String description = (data['description'] ?? "No description available.").toString();
        setState(() {
          _result = "Severity: ${severity.toUpperCase()}\n\n$description";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = "Failed to check interaction. Please check your internet connection and try again.";
        _isLoading = false;
      });
      debugPrint("Error calling checkInteraction: $e");
    }
  }

  @override
  void dispose() {
    _drugAController.dispose();
    _drugBController.dispose();
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
              "Check if two medications are safe to take together.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            
            _buildInputField("First Medication", _drugAController),
            const SizedBox(height: 20),
            _buildInputField("Second Medication", _drugBController),
            
            const SizedBox(height: 40),
            
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
                  : const Text("Check Now", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 40),
            
            const Text(
              "Result",
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
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
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
            controller.text = selection;
          },
          fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
            fieldController.text = controller.text;
            fieldController.addListener(() {
              controller.text = fieldController.text;
            });

            return TextField(
              controller: fieldController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: "Enter medication name...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.medication_rounded, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            );
          },
        ),
      ],
    );
  }
}
