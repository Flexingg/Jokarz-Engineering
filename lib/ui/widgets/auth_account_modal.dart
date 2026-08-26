import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';

void showAuthAccountModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const AuthAccountModal(),
  );
}

class AuthAccountModal extends ConsumerStatefulWidget {
  const AuthAccountModal({super.key});

  @override
  ConsumerState<AuthAccountModal> createState() => _AuthAccountModalState();
}

class _AuthAccountModalState extends ConsumerState<AuthAccountModal> {
  bool _isLoading = false;
  String? _errorMessage;
  Uri? _authUri;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final user = ref.watch(authStateProvider).value;
    final syncState = ref.watch(syncStatusProvider);
    final syncNotifier = ref.read(syncStatusProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: AppTheme.primaryCyan,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Cross-Device Cloud Sync',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.accentCoral, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.accentCoral, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (user != null) ...[
                // User signed in card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceCard : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accentEmerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (user.photoURL != null)
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(user.photoURL!),
                        )
                      else
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primaryCyan,
                          child: Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'Google User',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Sync status indicator box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (syncState.status == SyncStatus.synced
                            ? AppTheme.accentEmerald
                            : syncState.status == SyncStatus.error
                                ? AppTheme.accentCoral
                                : AppTheme.accentAmber)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (syncState.status == SyncStatus.synced
                              ? AppTheme.accentEmerald
                              : syncState.status == SyncStatus.error
                                  ? AppTheme.accentCoral
                                  : AppTheme.accentAmber)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        syncState.status == SyncStatus.synced
                            ? Icons.check_circle_rounded
                            : syncState.status == SyncStatus.error
                                ? Icons.error_rounded
                                : Icons.sync_rounded,
                        color: syncState.status == SyncStatus.synced
                            ? AppTheme.accentEmerald
                            : syncState.status == SyncStatus.error
                                ? AppTheme.accentCoral
                                : AppTheme.accentAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              syncState.status == SyncStatus.synced
                                  ? 'Active Live Sync Enabled'
                                  : syncState.status == SyncStatus.error
                                      ? 'Cloud Sync Error'
                                      : 'Syncing in background...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: syncState.status == SyncStatus.error
                                    ? AppTheme.accentCoral
                                    : null,
                              ),
                            ),
                            if (syncState.errorMessage != null &&
                                syncState.status == SyncStatus.error)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  syncState.errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.accentCoral,
                                  ),
                                ),
                              ),
                            if (syncState.lastSyncedAt != null)
                              Text(
                                'Last synced: ${DateFormat('h:mm:ss a').format(syncState.lastSyncedAt!)}',
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
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Force Sync'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                });
                                try {
                                  await syncNotifier.pushAllLocalToCloud();
                                } catch (e) {
                                  setState(() => _errorMessage = e.toString());
                                } finally {
                                  setState(() => _isLoading = false);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.switch_account_rounded, size: 18),
                        label: const Text('Switch Account'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                  _authUri = null;
                                });
                                try {
                                  final cred = await authService.switchGoogleAccount(
                                    onAuthUrl: (uri) {
                                      if (mounted) setState(() => _authUri = uri);
                                    },
                                  );
                                  if (cred != null) {
                                    await syncNotifier.pushAllLocalToCloud();
                                  }
                                } catch (e) {
                                  setState(() => _errorMessage = 'Switch error: $e');
                                } finally {
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                  label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCoral,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          await authService.signOut();
                          setState(() => _isLoading = false);
                          if (context.mounted) Navigator.pop(context);
                        },
                ),
              ] else ...[
                // Not signed in card
                Text(
                  'Sign in with your Google account to automatically sync projects, tasks, orders, and field notes in real time across your Android phone and Windows workstation.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                            _authUri = null;
                          });
                          try {
                            final cred = await authService.signInWithGoogle(
                              onAuthUrl: (uri) {
                                if (mounted) setState(() => _authUri = uri);
                              },
                            );
                            if (cred != null) {
                              // Initial cloud sync
                              await syncNotifier.pushAllLocalToCloud();
                              if (context.mounted) Navigator.pop(context);
                            }
                          } catch (e) {
                            setState(() {
                              _errorMessage = 'Sign-in error: $e';
                            });
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata_rounded, color: Colors.blue, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),

                if (_isLoading && _authUri != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Browser authorization in progress...',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryCyan,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                                label: const Text('Open Browser', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  if (_authUri != null) {
                                    authService.openBrowser(_authUri!);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _authUri.toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sign-in URL copied to clipboard!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
