import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/project_template.dart';
import '../../providers/project_provider.dart';
import 'expressive_badge.dart';


class TemplateDialogs {
  /// Opens a dialog to save the current project structure as a reusable template.
  static Future<void> showSaveAsTemplateDialog(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final nameCtrl = TextEditingController(text: '${project.title} Template');
    final descCtrl = TextEditingController(text: project.description);

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_copy_rounded, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text('Save as Template'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a reusable blueprint from "${project.title}" including its ${project.tasks.length} task steps and ${project.orders.length} order items.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Template Name *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Procedure Notes / Description',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await ref.read(projectProvider.notifier).saveProjectAsTemplate(
                    project.id,
                    name,
                    description: descCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Template saved successfully!'),
                    backgroundColor: AppTheme.accentEmerald,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: Colors.black87,
            ),
            child: const Text('Save Template'),
          ),
        ],
      ),
    );
  }

  /// Opens a picker dialog displaying all system & custom templates to instantiate a project.
  static Future<ProjectTemplate?> showTemplatePicker(BuildContext context, WidgetRef ref) async {
    final state = ref.read(projectProvider);
    final templates = state.allTemplates;

    return showDialog<ProjectTemplate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dashboard_customize_rounded, color: AppTheme.accentEmerald),
            SizedBox(width: 8),
            Text('Project & PM Templates'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: templates.isEmpty
              ? const Center(child: Text('No templates available.'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final t = templates[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          if (t.isSystemTemplate)
                            const ExpressiveBadge(
                              label: 'STANDARD',
                              color: AppTheme.primaryCyan,
                              fontSize: 9,
                            )
                          else
                            const ExpressiveBadge(
                              label: 'CUSTOM',
                              color: AppTheme.accentAmber,
                              fontSize: 9,
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(t.description, style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              ExpressiveBadge(
                                label: '${t.tasks.length} Tasks',
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                              ExpressiveBadge(
                                label: t.category.label,
                                color: t.category == ProjectCategory.maintenance
                                    ? AppTheme.primaryCyan
                                    : (t.category == ProjectCategory.kaizen
                                        ? AppTheme.accentEmerald
                                        : AppTheme.accentAmber),
                                fontSize: 10,
                              ),

                              if (t.tags.isNotEmpty)
                                ...t.tags.take(2).map((tag) => ExpressiveBadge(
                                      label: tag,
                                      color: Colors.blueGrey,
                                      fontSize: 10,
                                    )),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }
}
