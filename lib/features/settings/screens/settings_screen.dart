import 'package:flutter/material.dart';
import 'package:migra_app/core/providers/theme_provider.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:provider/provider.dart';
import 'package:migra_app/core/themes/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLanguageDialog(BuildContext context) {
    final appDataProvider = Provider.of<AppData>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context: context,
                locale: const Locale('en'),
                flag: '🇺🇸',
                name: 'English',
                isSelected: appDataProvider.locale.languageCode == 'en',
                onTap: () {
                  appDataProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              _buildLanguageOption(
                context: context,
                locale: const Locale('es'),
                flag: '🇪🇸',
                name: 'Español',
                isSelected: appDataProvider.locale.languageCode == 'es',
                onTap: () {
                  appDataProvider.setLocale(const Locale('es'));
                  Navigator.pop(context);
                },
              ),
              _buildLanguageOption(
                context: context,
                locale: const Locale('ht'),
                flag: '🇭🇹',
                name: 'Kreyòl Ayisyen',
                isSelected: appDataProvider.locale.languageCode == 'ht',
                onTap: () {
                  appDataProvider.setLocale(const Locale('ht'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required Locale locale,
    required String flag,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: onTap,
    );
  }

  String _getCurrentLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'ht':
        return 'Kreyòl Ayisyen';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appDataProvider = Provider.of<AppData>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(_getCurrentLanguageName(appDataProvider.locale.languageCode)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showLanguageDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Handle notification settings
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Log Out', style: TextStyle(color: AppColors.error)),
            onTap: () {
              // Handle log out
            },
          ),
        ],
      ),
    );
  }
}
