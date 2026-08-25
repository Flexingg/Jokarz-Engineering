import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';
import '../../widgets/expressive_badge.dart';

class JapaneseTranslateView extends StatelessWidget {
  const JapaneseTranslateView({super.key});

  Future<void> _launchCamera(BuildContext context) async {
    final uri = Uri.parse('https://translate.google.com/?sl=ja&tl=en&op=images');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Google Translate')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching Google Translate: $e')),
        );
      }
    }
  }

  Future<void> _launchWebText(BuildContext context) async {
    final uri = Uri.parse('https://translate.google.com/?sl=ja&tl=en&op=translate');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  static const List<({String kanji, String romaji, String english, String category})> plantPhrases = [
    (kanji: '非常停止', romaji: 'Hijō Teishi', english: 'Emergency Stop (E-Stop)', category: 'Safety'),
    (kanji: '異常 / アラーム', romaji: 'Ijō / Arāmu', english: 'Abnormal / Machine Alarm', category: 'Alarms'),
    (kanji: '自動運転', romaji: 'Jidō Unten', english: 'Automatic Operation / Run', category: 'Controls'),
    (kanji: '手動運転', romaji: 'Shudō Unten', english: 'Manual Operation / Jog', category: 'Controls'),
    (kanji: '原点復帰', romaji: 'Genten Fukki', english: 'Origin / Home Return', category: 'Controls'),
    (kanji: '始動 / 起動', romaji: 'Shidō / Kidō', english: 'Start / Power-On', category: 'Controls'),
    (kanji: '停止', romaji: 'Teishi', english: 'Stop / Halt', category: 'Controls'),
    (kanji: '段取り替え', romaji: 'Dandori-gae', english: 'Tooling / Line Changeover', category: 'Production'),
    (kanji: '定期点検', romaji: 'Teiki Tenken', english: 'Periodic Maintenance Inspection', category: 'Maintenance'),
    (kanji: '給油 / 潤滑', romaji: 'Kyūyu / Junkatsu', english: 'Lubrication / Grease Lube', category: 'Maintenance'),
    (kanji: '保全 / 保守', romaji: 'Hozen / Hoshu', english: 'Maintenance / Preventative Care', category: 'Maintenance'),
    (kanji: '圧力', romaji: 'Atsuryoku', english: 'Pressure (Pneumatic / Hydraulic)', category: 'Sensors'),
    (kanji: '流量', romaji: 'Ryūryō', english: 'Flow Rate', category: 'Sensors'),
    (kanji: '温度', romaji: 'Ondo', english: 'Temperature', category: 'Sensors'),
    (kanji: '回転数 / 速度', romaji: 'Kaitensū / Sokudo', english: 'RPM / Machine Speed', category: 'Sensors'),
    (kanji: '寸法 / 測定', romaji: 'Sunpō / Sokutei', english: 'Dimension / Measurement', category: 'Quality'),
    (kanji: '隙間 / クリアランス', romaji: 'Sukima / Kuriaransu', english: 'Clearance / Gap', category: 'Mechanical'),
    (kanji: '締付トルク', romaji: 'Shimetsuke Toruku', english: 'Tightening Torque', category: 'Mechanical'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Camera Direct Launcher Hero Card
          ExpressiveCard(
            isGlowing: true,
            glowColor: AppTheme.accentCoral,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCoral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentCoral, size: 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('🇯🇵 ➔ 🇺🇸', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 6),
                              Text(
                                'Japanese Camera Lens',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scan Japanese electrical cabinets, PLC schematics, touch panels, and machine drawings directly with live camera translation.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCoral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                        ),
                        onPressed: () => _launchCamera(context),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Open Camera Translate', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _launchWebText(context),
                        icon: const Icon(Icons.translate_rounded, size: 16),
                        label: const Text('Text Mode', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Common Plant Vocabulary Reference Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FACTORY FLOOR JAPANESE REFERENCE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
              ),
              ExpressiveBadge(label: 'Manufacturing Terms', color: AppTheme.primaryCyan, fontSize: 10),
            ],
          ),
          const SizedBox(height: 10),

          // Vocabulary Cards
          ...plantPhrases.map((phrase) {
            return ExpressiveCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      phrase.kanji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phrase.english,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${phrase.romaji} • ${phrase.category}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
