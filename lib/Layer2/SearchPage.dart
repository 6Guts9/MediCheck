import 'package:flutter/material.dart';

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

  void _checkInteraction() {
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

    // Mocking a fetch for now. You can later replace this with 
    // an HTTP call to your Firebase Cloud Function (.ts file)
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        // This is where you will display the result from your database/logic
        _result = "Checked interaction between \"${_drugAController.text}\" and \"${_drugBController.text}\".\n\nNo severe interactions found in the test database.";
      });
    });
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
            
            // Input Fields
            _buildInputField("First Medication", _drugAController),
            const SizedBox(height: 20),
            _buildInputField("Second Medication", _drugBController),
            
            const SizedBox(height: 40),
            
            // Check Button
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
            
            // Result Display
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
                border: Border.all(color: Colors.green.withOpacity(0.3)),
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
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter name...",
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.medication_rounded, color: Colors.blue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }
}
