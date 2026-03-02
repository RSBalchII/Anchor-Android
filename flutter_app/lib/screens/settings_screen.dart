import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _engineUrlController = TextEditingController();
  final TextEditingController _githubTokenController = TextEditingController();
  
  bool _autoSync = false;
  bool _wifiOnly = true;
  int _syncInterval = 3600;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _engineUrlController.text = settings.engineUrl;
    _githubTokenController.text = settings.githubToken ?? '';
    _autoSync = settings.autoSync;
    _wifiOnly = settings.wifiOnly;
    _syncInterval = settings.syncInterval;
  }

  @override
  void dispose() {
    _engineUrlController.dispose();
    _githubTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Engine URL
          TextField(
            controller: _engineUrlController,
            decoration: const InputDecoration(
              labelText: 'Engine URL',
              hintText: 'http://localhost:3160',
              prefixIcon: Icon(Icons.dns),
            ),
            onChanged: (value) {
              context.read<SettingsService>().setEngineUrl(value);
              context.read<ApiService>().refreshConnection();
            },
          ),
          
          const SizedBox(height: 16),
          
          // GitHub Token
          TextField(
            controller: _githubTokenController,
            decoration: const InputDecoration(
              labelText: 'GitHub Token (Optional)',
              hintText: 'ghp_...',
              prefixIcon: Icon(Icons.key),
            ),
            obscureText: true,
            onChanged: (value) {
              context.read<SettingsService>().setGithubToken(value.isEmpty ? null : value);
            },
          ),
          
          const SizedBox(height: 24),
          
          // Auto Sync
          SwitchListTile(
            title: const Text('Auto Sync'),
            subtitle: const Text('Automatically sync repositories'),
            value: _autoSync,
            onChanged: (value) {
              setState(() => _autoSync = value);
              context.read<SettingsService>().setAutoSync(value);
            },
          ),
          
          // WiFi Only
          SwitchListTile(
            title: const Text('WiFi Only'),
            subtitle: const Text('Only sync on WiFi'),
            value: _wifiOnly,
            onChanged: (value) {
              setState(() => _wifiOnly = value);
              context.read<SettingsService>().setWifiOnly(value);
            },
          ),
          
          // Sync Interval
          ListTile(
            title: const Text('Sync Interval'),
            subtitle: Text('${_syncInterval ~/ 3600} hours'),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              // Show dialog to change sync interval
            },
          ),
          
          const SizedBox(height: 24),
          
          // About
          Card(
            child: ListTile(
              title: const Text('About'),
              subtitle: const Text('Anchor Android v0.1.0'),
              leading: const Icon(Icons.info),
            ),
          ),
        ],
      ),
    );
  }
}
