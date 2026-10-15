import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../screens/diagnostics_screen.dart';

const String kAppName = 'AOR Engineering';
const String kReleasesUrl = 'https://github.com/Flexingg/Jokarz-Engineering/releases';

/// "1.6.0 (build 28)" from the installed package; empty while loading or when
/// the platform can't report it.
String formatVersion(PackageInfo? info) {
  if (info == null || info.version.isEmpty) return '';
  return info.buildNumber.isEmpty ? info.version : '${info.version} (build ${info.buildNumber})';
}

/// Link to this version's release notes, or the releases list if unknown.
Uri releaseNotesUri(PackageInfo? info) {
  final v = info?.version ?? '';
  return Uri.parse(v.isEmpty ? kReleasesUrl : '$kReleasesUrl/tag/v$v');
}

/// Bottom of Settings: app name, the real installed version, and links.
class AppFooter extends StatefulWidget {
  /// Test seam; production reads the installed package.
  final Future<PackageInfo> Function()? loadInfo;
  const AppFooter({super.key, this.loadInfo});

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  late final Future<PackageInfo?> _info = _load();

  Future<PackageInfo?> _load() async {
    try {
      return await (widget.loadInfo ?? PackageInfo.fromPlatform)();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return FutureBuilder<PackageInfo?>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data;
        final version = formatVersion(info);
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: Column(
            children: [
              Text(kAppName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                version.isEmpty ? ' ' : 'Version $version',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        launchUrl(releaseNotesUri(info), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.new_releases_outlined, size: 16),
                    label: const Text('Release notes'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: const Text('Diagnostics log'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
