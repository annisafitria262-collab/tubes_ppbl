import 'package:flutter/material.dart';
import '../../../core/database/db_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isLoading = false;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // Panggil fungsi Insert SQLite
      int result = await DatabaseHelper.instance.registerUser(
        _namaCtrl.text.trim(), 
        _emailCtrl.text.trim(), 
        _passwordCtrl.text
      );

      setState(() => _isLoading = false);

      if (result > 0) {
        // Jika sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pendaftaran berhasil! Silakan Login. ✅"),
              backgroundColor: Color(0xFF2E7D32),
            )
          );
          Navigator.pop(context); // Kembali ke halaman Login
        }
      } else {
        // Jika gagal (Misal: email sudah dipakai, melanggar UNIQUE SQLite)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Email ini sudah terdaftar! Gunakan email lain. ⚠️"),
              backgroundColor: Colors.orange,
            )
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E7D32)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Center(
                  child: Text("🥗", style: TextStyle(fontSize: 80)),
                ),
                const SizedBox(height: 20),
                const Text("Buat Akun", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                const SizedBox(height: 5),
                Text("Bergabunglah dan evaluasi dietmu sekarang.", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 40),

                // INPUT NAMA
                TextFormField(
                  controller: _namaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value!.isEmpty ? 'Nama wajib diisi!' : null,
                ),
                const SizedBox(height: 20),

                // INPUT EMAIL
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Email wajib diisi!';
                    if (!value.contains('@')) return 'Format email tidak valid!';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // INPUT PASSWORD
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _isPasswordHidden,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordHidden ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _isPasswordHidden = !_isPasswordHidden;
                        });
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password wajib diisi!';
                    if (value.length < 6) return 'Password minimal 6 karakter!';
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // TOMBOL REGISTER
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 3,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Daftar Sekarang", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}