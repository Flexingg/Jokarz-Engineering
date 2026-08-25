import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/project.dart';
import '../../models/bom_item.dart';
import '../../models/project_log.dart';
import '../../providers/project_provider.dart';
import '../widgets/expressive_card.dart';
import '../widgets/expressive_badge.dart';
import '../widgets/voice_memo_modal.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? photo =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (photo != null) {
        await ref
            .read(projectProvider.notifier)
            .addProjectPhoto(widget.projectId, photo.path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo attached to project!'),
              backgroundColor: AppTheme.accentEmerald,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showAddLogDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    LogType selectedType = LogType.update;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add Engineering Log Entry'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Log Title',
                      hintText: 'e.g. Tolerances measured on test print',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LogType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Log Type'),
                    items: LogType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes & Findings',
                      hintText: 'Enter observation, fit adjustments, sensor readings...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final log = ProjectLog(
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    type: selectedType,
                  );
                  await ref
                      .read(projectProvider.notifier)
                      .addProjectLog(widget.projectId, log);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Log'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddBOMDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final partNumCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '0.00');
    final qtyCtrl = TextEditingController(text: '1');
    final urlCtrl = TextEditingController();
    BOMCategory category = BOMCategory.other;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add BOM Component'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Part / Component Name',
                      hintText: 'e.g. M3x12 Socket Head Screw',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<BOMCategory>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: BOMCategory.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Unit Cost (\$)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Quantity'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: supplierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      hintText: 'e.g. McMaster, DigiKey, Amazon',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: partNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Part Number / SKU',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final item = BOMItem(
                    name: nameCtrl.text.trim(),
                    category: category,
                    unitCost: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                    quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
                    supplier: supplierCtrl.text.trim(),
                    partNumber: partNumCtrl.text.trim(),
                    linkUrl: urlCtrl.text.trim(),
                  );
                  await ref
                      .read(projectProvider.notifier)
                      .addBOMItem(widget.projectId, item);
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Add Part'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.read(projectProvider.notifier).getProjectById(widget.projectId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Project not found or deleted.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          project.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppTheme.accentAmber),
            tooltip: 'Dictate Note for Project',
            onPressed: () => VoiceMemoModal.show(
              context,
              preselectedProjectId: project.id,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyan),
            tooltip: 'Edit Project Details',
            onPressed: () => context.push('/projects/${project.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.accentCoral),
            tooltip: 'Delete Project',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Project?'),
                  content: Text('Are you sure you want to delete "${project.title}"? This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCoral),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(projectProvider.notifier).deleteProject(project.id);
                if (context.mounted) {
                  context.pop();
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryCyan,
          tabs: [
            const Tab(icon: Icon(Icons.info_outline), text: 'Overview & CAD'),
            Tab(
              icon: const Icon(Icons.receipt_long_outlined),
              text: 'BOM (${project.bom.length})',
            ),
            Tab(
              icon: const Icon(Icons.history_edu_outlined),
              text: 'Logs (${project.logs.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(context, project, currency, isDark),
          _buildBOMTab(context, project, currency, isDark),
          _buildLogsTab(context, project, isDark),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    Project project,
    NumberFormat currency,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges & Status Row
          Row(
            children: [
              ExpressiveBadge(
                label: project.category.label,
                color: AppTheme.primaryCyan,
                fontSize: 12,
              ),
              const SizedBox(width: 8),
              ExpressiveBadge(
                label: project.status.label,
                color: project.status == ProjectStatus.complete
                    ? AppTheme.accentEmerald
                    : AppTheme.accentAmber,
                fontSize: 12,
              ),
              const SizedBox(width: 8),
              ExpressiveBadge(
                label: 'Priority: ${project.priority.label}',
                color: project.priority == ProjectPriority.critical
                    ? AppTheme.accentCoral
                    : AppTheme.primaryBlue,
                fontSize: 12,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description Card
          ExpressiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Project Scope & Specifications',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  project.description.isEmpty
                      ? 'No description provided.'
                      : project.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                if (project.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: project.tags
                        .map(
                          (t) => Chip(
                            label: Text('#$t', style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3D Printing & Budget Estimations Card
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return GridView.count(
                crossAxisCount: isWide ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 2.0 : 3.0,
                children: [
                  _buildMetricTile(
                    title: 'Total BOM Cost',
                    value: currency.format(project.totalBOMCost),
                    subtitle: 'Budget: ${currency.format(project.budget)}',
                    icon: Icons.attach_money_rounded,
                    color: AppTheme.accentEmerald,
                    isDark: isDark,
                  ),
                  _buildMetricTile(
                    title: 'Est. Print Time',
                    value: '${project.estimatedPrintHours.toStringAsFixed(1)} hrs',
                    subtitle: 'Machine Run Time',
                    icon: Icons.timer_outlined,
                    color: AppTheme.primaryCyan,
                    isDark: isDark,
                  ),
                  _buildMetricTile(
                    title: 'Filament Usage',
                    value: '${project.estimatedFilamentGrams.toStringAsFixed(0)} g',
                    subtitle: 'Material Weight',
                    icon: Icons.scale_outlined,
                    color: AppTheme.accentPurple,
                    isDark: isDark,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Attached Photos & Inspections Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Photo Inspections & Blueprints',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Attach Photo'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (project.photoPaths.isEmpty)
            ExpressiveCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        'No inspection photos attached yet',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Upload Photo / Schematic'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: project.photoPaths.length,
                itemBuilder: (context, idx) {
                  final path = project.photoPaths[idx];
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBOMTab(
    BuildContext context,
    Project project,
    NumberFormat currency,
    bool isDark,
  ) {
    return Column(
      children: [
        // BOM Sourcing Bar & Export Action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Procurement: ${project.purchasedItemCount} of ${project.bom.length} items (${(project.bomCompletionRatio * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${currency.format(project.totalBOMCost)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download_rounded, color: AppTheme.primaryCyan),
                tooltip: 'Export BOM CSV',
                onPressed: () {
                  final csv = ref.read(storageServiceProvider).exportBOMToCSV(project);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Exported Bill of Materials CSV'),
                      content: SingleChildScrollView(
                        child: SelectableText(
                          csv,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddBOMDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Part'),
              ),
            ],
          ),
        ),

        // BOM Items List
        Expanded(
          child: project.bom.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No components added to BOM yet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddBOMDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Part'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: project.bom.length,
                  itemBuilder: (context, index) {
                    final item = project.bom[index];
                    return ExpressiveCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Checkbox(
                            value: item.isPurchased,
                            activeColor: AppTheme.accentEmerald,
                            onChanged: (_) {
                              ref
                                  .read(projectProvider.notifier)
                                  .toggleBOMItemPurchased(project.id, item.id);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    decoration: item.isPurchased
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    ExpressiveBadge(
                                      label: item.category.label,
                                      color: AppTheme.primaryCyan,
                                      fontSize: 9,
                                    ),
                                    if (item.supplier.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${item.supplier}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                    if (item.partNumber.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '#${item.partNumber}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currency.format(item.totalCost),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${item.quantity} × ${currency.format(item.unitCost)}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () {
                              ref
                                  .read(projectProvider.notifier)
                                  .deleteBOMItem(project.id, item.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLogsTab(BuildContext context, Project project, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${project.logs.length} Log Entries Recorded',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => VoiceMemoModal.show(
                      context,
                      preselectedProjectId: project.id,
                    ),
                    icon: const Icon(Icons.mic, color: AppTheme.accentAmber, size: 16),
                    label: const Text(
                      'Voice Dictation',
                      style: TextStyle(color: AppTheme.accentAmber, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddLogDialog(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Entry'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: project.logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_edu_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No field logs or voice memos recorded yet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddLogDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Log Entry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: project.logs.length,
                  itemBuilder: (context, index) {
                    final log = project.logs[index];
                    return ExpressiveCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ExpressiveBadge(
                                label: log.type.label,
                                color: log.type == LogType.voice
                                    ? AppTheme.accentAmber
                                    : (log.type == LogType.milestone
                                        ? AppTheme.accentEmerald
                                        : AppTheme.primaryCyan),
                                fontSize: 10,
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MMM d, y • h:mm a').format(log.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                onPressed: () {
                                  ref
                                      .read(projectProvider.notifier)
                                      .deleteProjectLog(project.id, log.id);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            log.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (log.content.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              log.content,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return ExpressiveCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
