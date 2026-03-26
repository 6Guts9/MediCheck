import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../Authentication/auth_services.dart';

class EditUsernamePage extends StatefulWidget {
  const EditUsernamePage({super.key});

  @override
  State<EditUsernamePage> createState() => _EditUsernamePageState();
}

class _EditUsernamePageState extends State<EditUsernamePage> {
  final TextEditingController controllerUsername = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current username
    controllerUsername.text = authServices.value.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    controllerUsername.dispose();
    super.dispose();
  }

  void updateUsername() async {
    if (controllerUsername.text.trim().isEmpty) {
      setState(() {
        errorMessage = "Username cannot be empty";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await authServices.value.updateUsername(
        username: controllerUsername.text.trim(),
      );
      showSnackBarSuccess();
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? "An error occurred";
      });
    } catch (e) {
      setState(() {
        errorMessage = "An unexpected error occurred";
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showSnackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.green[500],
      behavior: SnackBarBehavior.floating,
      content: const Text(
        "Username updated successfully",
        style: TextStyle(color: Colors.white),
      ),
      showCloseIcon: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Stack(
        children: [
          // Decorative Circle (Green)
          Positioned(
            top: -40,
            left: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.green.withOpacity(0.2),
            ),
          ),

          // Back Arrow
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    const Text(
                      "Update Username",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Choose a name that others will see",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 40),
                    
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),

                    buildTextField("Enter new username", controllerUsername, icon: Icons.badge_outlined),

                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    const SizedBox(height: 30),

                    // Update Button (Blue)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : updateUsername,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20, 
                                width: 20, 
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String hint, TextEditingController controller, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 20,
          ),
        ),
      ),
    );
  }
}
