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

  /// Built-in plant engineering standard templates.
  static List<ProjectTemplate> get systemTemplates => [
        ProjectTemplate(
          id: 'sys-motor-gearbox',
          name: 'Motor & Gearbox Replacement',
          description: 'Standard procedure for replacing drive motor or gearbox assembly.',
          category: ProjectCategory.maintenance,
          defaultPhase: ProjectPhases.pending,
          tags: ['Drive', 'Motor', 'LOTO', 'Mechanical'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Apply LOTO & verify zero mechanical/electrical energy', offsetDays: 0),
            TaskTemplate(description: 'Uncouple motor, tag wiring, unbolt mount & rig down old unit', offsetDays: 0),
            TaskTemplate(description: 'Position replacement unit, torque mounting bolts to spec', offsetDays: 1),
            TaskTemplate(description: 'Precision shaft alignment (dial indicator / laser alignment)', offsetDays: 1),
            TaskTemplate(description: 'Wire motor, verify rotation direction before coupling', offsetDays: 1),
            TaskTemplate(description: 'Full load test & vibration / temperature baseline check', offsetDays: 2),
            TaskTemplate(description: 'Return old core to storeroom / rebuild tag', offsetDays: 2),
          ],
          suggestedOrders: const [
            OrderTemplate(description: 'Drive coupling insert / spider elastomer', estimatedPrice: 45.0, addToStores: true),
            OrderTemplate(description: 'Replacement gearbox synthetic lube (ISO VG 220)', estimatedPrice: 85.0, addToStores: true),
          ],
        ),
        ProjectTemplate(
          id: 'sys-pm-line-audit',
          name: 'Line Preventative Maintenance (PM) Audit',
          description: 'Comprehensive mechanical & electrical PM checklist for machine line.',
          category: ProjectCategory.maintenance,
          defaultPhase: ProjectPhases.installation,
          tags: ['PM', 'Inspection', 'Lube', 'Safety'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Inspect all drive belts, chain tension, and sprocket wear', offsetDays: 0),
            TaskTemplate(description: 'Lubricate all pillow block bearings and linear guide rails', offsetDays: 0),
            TaskTemplate(description: 'Check pneumatic FRL filters, clean bowls & inspect line pressure', offsetDays: 1),
            TaskTemplate(description: 'Clean & realign all photoelectric / proximity sensors', offsetDays: 1),
            TaskTemplate(description: 'Test all emergency stops, safety gate interlocks & light curtains', offsetDays: 1),
            TaskTemplate(description: 'Log any worn parts needing purchase orders', offsetDays: 2),
          ],
        ),
        ProjectTemplate(
          id: 'sys-safety-guard',
          name: 'Safety Guarding & Interlock Installation',
          description: 'Design, fabrication, and interlock integration for machine pinch-point.',
          category: ProjectCategory.kaizen,
          defaultPhase: ProjectPhases.idea,
          tags: ['Safety', 'Guarding', 'Fabrication', 'Interlock'],
          isSystemTemplate: true,

          tasks: const [
            TaskTemplate(description: 'Perform risk assessment and measure hazard zone clearances', offsetDays: 0),
            TaskTemplate(description: 'CAD / sketch guarding frame (extruded aluminum / polycarbonate)', offsetDays: 1),
            TaskTemplate(description: 'Order safety interlock switch and frame extrusion hardware', offsetDays: 2),
            TaskTemplate(description: 'Cut, assemble frame, mount hinges, and install polycarbonate panels', offsetDays: 5),
            TaskTemplate(description: 'Wire safety interlock into safety relay circuit (dual-channel)', offsetDays: 6),
            TaskTemplate(description: 'Safety validation run: verify immediate motion stop on gate open', offsetDays: 7),
            TaskTemplate(description: 'Operator sign-off & update standard operating procedure (SOP)', offsetDays: 7),
          ],
        ),
        ProjectTemplate(
          id: 'sys-kaizen-optimization',
          name: 'Kaizen / 5S Line Flow Optimization',
          description: 'Continuous improvement project to eliminate bottleneck or reduce changeover time.',
          category: ProjectCategory.kaizen,
          defaultPhase: ProjectPhases.idea,
          tags: ['Kaizen', 'Continuous Improvement', '5S', 'SMED'],
          isSystemTemplate: true,
          tasks: const [
            TaskTemplate(description: 'Conduct video time-study of current changeover process', offsetDays: 0),
            TaskTemplate(description: 'Identify top 3 non-value-added steps / tool search waste', offsetDays: 2),
            TaskTemplate(description: 'Design dedicated shadow board & quick-change guide rails', offsetDays: 4),
            TaskTemplate(description: 'Install toolless clamping handles on adjustable guide rails', offsetDays: 7),
            TaskTemplate(description: 'Run trial changeover with shift technicians & time result', offsetDays: 9),
            TaskTemplate(description: 'Document standard changeover procedure with photo aids', offsetDays: 10),
          ],
        ),
      ];
}
