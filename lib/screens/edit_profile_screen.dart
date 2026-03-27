import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/vocpass_auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = VocPassAuthService.instance.currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<VocPassAuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    final newName = _nameCtrl.text.trim();
    final newUsername = _usernameCtrl.text.trim();

    final changedName = newName != user.name ? newName : null;
    final changedUsername = newUsername != user.username ? newUsername : null;

    if (changedName == null && changedUsername == null) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await auth.updateUser(name: changedName, username: changedUsername);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<VocPassAuthService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯個人資料'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('儲存'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: user?.avatarURL != null
                          ? NetworkImage(user!.avatarURL!)
                          : null,
                      child: user?.avatarURL == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名稱',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Username
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: '帳號',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          if (_isSaving)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
