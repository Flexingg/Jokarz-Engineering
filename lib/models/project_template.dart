import 'package:uuid/uuid.dart';
import 'project.dart';

/// A blueprint for creating recurring projects or standard PM checklists.
class TaskTemplate {
  final String description;
  final String pendingReason;
  final int offsetDays; // Number of days from project start to schedule task

  const TaskTemplate({
    required this.description,
    this.pendingReason = '',
    this.offsetDays = 0,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'pendingReason': pendingReason,
        'offsetDays': offsetDays,
      };

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
        description: json['description'] as String? ?? '',
        pendingReason: json['pendingReason'] as String? ?? '',
        offsetDays: (json['offsetDays'] as num?)?.toInt() ?? 0,
      );
}

class OrderTemplate {
  final String description;
  final double estimatedPrice;
  final bool addToStores;

  const OrderTemplate({
    required this.description,
    this.estimatedPrice = 0.0,
    this.addToStores = false,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'estimatedPrice': estimatedPrice,
        'addToStores': addToStores,
      };

  factory OrderTemplate.fromJson(Map<String, dynamic> json) => OrderTemplate(
        description: json['description'] as String? ?? '',
        estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble() ?? 0.0,
        addToStores: json['addToStores'] as bool? ?? false,
      );
}

class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final ProjectCategory category;
  final String defaultPhase;
  final String defaultMachine;
  final List<String> tags;
  final List<TaskTemplate> tasks;
  final List<OrderTemplate> suggestedOrders;
  final bool isSystemTemplate;
  final DateTime createdAt;

  ProjectTemplate({
    String? id,
    required this.name,
    this.description = '',
    this.category = ProjectCategory.maintenance,
    this.defaultPhase = ProjectPhases.idea,
    this.defaultMachine = '',
    this.tags = const [],
    this.tasks = const [],
    this.suggestedOrders = const [],
    this.isSystemTemplate = false,
    DateTime? createdAt,
  })  : id = (id != null && id.trim().isNotEmpty) ? id.trim() : const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  ProjectTemplate copyWith({
    String? name,
    String? description,
    ProjectCategory? category,
    String? defaultPhase,
    String? defaultMachine,
    List<String>? tags,
    List<TaskTemplate>? tasks,
    List<OrderTemplate>? suggestedOrders,
    bool? isSystemTemplate,
  }) {
    return ProjectTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultPhase: defaultPhase ?? this.defaultPhase,
      defaultMachine: defaultMachine ?? this.defaultMachine,
      tags: tags ?? this.tags,
      tasks: tasks ?? this.tasks,
      suggestedOrders: suggestedOrders ?? this.suggestedOrders,
      isSystemTemplate: isSystemTemplate ?? this.isSystemTemplate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'defaultPhase': defaultPhase,
      'defaultMachine': defaultMachine,
      'tags': tags,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'suggestedOrders': suggestedOrders.map((o) => o.toJson()).toList(),
      'isSystemTemplate': isSystemTemplate,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProjectTemplate.fromJson(Map<String, dynamic> json) {
    return ProjectTemplate(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: ProjectCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ProjectCategory.maintenance,
      ),
      defaultPhase: json['defaultPhase'] as String? ?? ProjectPhases.idea,
      defaultMachine: json['defaultMachine'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      suggestedOrders: (json['suggestedOrders'] as List<dynamic>?)
              ?.map((e) => OrderTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSystemTemplate: json['isSystemTemplate'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Built-in default project workflow templates.
  static List<ProjectTemplate> get systemTemplates => [
        ProjectTemplate(
          id: 'sys-inhouse-design',
          name: 'Simple In House Design',
          description:
              'Standard design, fabricate, install workflow done in-house.',
          category: ProjectCategory.kaizen,
          defaultPhase: ProjectPhases.idea,
          tags: ['Design', 'Fabrication', 'Install'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Take measurements'),
            TaskTemplate(description: 'Make design'),
            TaskTemplate(description: 'Verified design'),
            TaskTemplate(description: 'Fabricate'),
            TaskTemplate(description: 'Install'),
            TaskTemplate(description: 'Validate'),
          ],
        ),
        ProjectTemplate(
          id: 'sys-outsource-design',
          name: 'Simple Outsource Design',
          description:
              'Design and procurement workflow when the design is outsourced.',
          category: ProjectCategory.kaizen,
          defaultPhase: ProjectPhases.idea,
          tags: ['Design', 'Procurement', 'RFQ'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Take measurements'),
            TaskTemplate(description: 'Make design'),
            TaskTemplate(description: 'Verified design'),
            TaskTemplate(description: 'Get approval'),
            TaskTemplate(description: 'RFQ'),
            TaskTemplate(description: 'Submit purchase req'),
            TaskTemplate(description: 'Received'),
            TaskTemplate(description: 'Quality check'),
            TaskTemplate(description: 'Install'),
            TaskTemplate(description: 'Validate'),
          ],
        ),
        ProjectTemplate(
          id: 'sys-parts-request',
          name: 'Parts Request',
          description: 'Quick workflow to source a spare part from the stores.',
          category: ProjectCategory.maintenance,
          defaultPhase: ProjectPhases.pending,
          tags: ['Parts', 'Stores'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Find part'),
            TaskTemplate(description: 'Make stores request'),
            TaskTemplate(description: 'Send follow-up email'),
          ],
        ),
        ProjectTemplate(
          id: 'sys-maintenance-fix',
          name: 'Maintenance Fix',
          description: 'Plan a maintenance job into scheduled downtime and close out.',
          category: ProjectCategory.maintenance,
          defaultPhase: ProjectPhases.pending,
          tags: ['Maintenance', 'Downtime'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Prep job'),
            TaskTemplate(description: 'Scheduled down time'),
            TaskTemplate(description: 'Do job'),
            TaskTemplate(description: 'Close BAMM'),
          ],
        ),
        ProjectTemplate(
          id: 'sys-small-capital',
          name: 'Small Capital',
          description:
              'Small capital project: quotes, funding request, issue purchase reqs.',
          category: ProjectCategory.capital,
          defaultPhase: ProjectPhases.idea,
          tags: ['Capital', 'FR', 'Procurement'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Get quotes / preliminary design'),
            TaskTemplate(description: 'Make FR'),
            TaskTemplate(description: 'FR approved'),
            TaskTemplate(description: 'Firm quotes/design'),
            TaskTemplate(description: 'Issue purchase reqs'),
            TaskTemplate(description: 'Received'),
            TaskTemplate(description: 'Quality check'),
            TaskTemplate(description: 'Install'),
            TaskTemplate(description: 'Validate'),
          ],
        ),
        ProjectTemplate(
          id: 'sys-large-capital',
          name: 'Large Capital',
          description:
              'Large capital project: funding request plus PPMA documentation and peer review.',
          category: ProjectCategory.capital,
          defaultPhase: ProjectPhases.idea,
          tags: ['Capital', 'FR', 'PPMA', 'Procurement'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Get quotes / preliminary design'),
            TaskTemplate(description: 'Make FR'),
            TaskTemplate(description: 'Make PPMA docs'),
            TaskTemplate(description: 'Peer review'),
            TaskTemplate(description: 'FR approved'),
            TaskTemplate(description: 'Firm quotes/design'),
            TaskTemplate(description: 'Issue purchase reqs'),
            TaskTemplate(description: 'Received'),
            TaskTemplate(description: 'Quality check'),
            TaskTemplate(description: 'Install'),
            TaskTemplate(description: 'Validate'),
          ],
        ),
      ];
}
