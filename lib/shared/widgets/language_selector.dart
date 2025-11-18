import 'package:flutter/material.dart';
import 'package:migra_app/providers/app_data.dart';
import 'package:provider/provider.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final appDataProvider = Provider.of<AppData>(context);
    
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: 'Select Language',
      onSelected: (Locale locale) {
        appDataProvider.setLocale(locale);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
        _buildLanguageItem(
          locale: const Locale('en'),
          flag: '🇺🇸',
          name: 'English',
          isSelected: appDataProvider.locale.languageCode == 'en',
        ),
        _buildLanguageItem(
          locale: const Locale('es'),
          flag: '🇪🇸',
          name: 'Español',
          isSelected: appDataProvider.locale.languageCode == 'es',
        ),
        _buildLanguageItem(
          locale: const Locale('ht'),
          flag: '🇭🇹',
          name: 'Kreyòl Ayisyen',
          isSelected: appDataProvider.locale.languageCode == 'ht',
        ),
      ],
    );
  }

  PopupMenuItem<Locale> _buildLanguageItem({
    required Locale locale,
    required String flag,
    required String name,
    required bool isSelected,
  }) {
    return PopupMenuItem<Locale>(
      value: locale,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text(
            name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.black,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, color: Colors.blue, size: 20),
          ],
        ],
      ),
    );
  }
}
