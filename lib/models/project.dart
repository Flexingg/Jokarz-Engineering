import 'package:uuid/uuid.dart';
import 'bom_item.dart';
import 'project_log.dart';

enum ProjectCategory {
  threeDPrinting('3D Printing & CAD'),
  electronics('Electronics & Circuits'),
  mechanical('Mechanical & Machining'),
  embedded('Software & Embedded'),
  robotics('Robotics & Automation'),
  workshop('Tooling & Workshop'),
  general('General Engineering');

  final String label;
  const ProjectCategory(this.label);
}

enum ProjectStatus {
  idea('💡 Concept / Idea'),
  planning('📐 Planning & CAD'),
  prototyping('⚡ Prototyping'),
  testing('🔬 Testing & Validation'),
  production('🏭 Production Ready'),
  complete('✅ Completed'),
  archived('📦 Archived');

  final String label;
  const ProjectStatus(this.label);
}

enum ProjectPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical 🔥');

  final String label;
  const ProjectPriority(this.label);
}

class Project {
  final String id;
  final String title;
  final String description;
  final ProjectCategory category;
  final ProjectStatus status;
  final ProjectPriority priority;
  final double budget;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BOMItem> bom;
  final List<ProjectLog> logs;
  final List<String> photoPaths;
  final double estimatedPrintHours;
  final double estimatedFilamentGrams;

  Project({
    String? id,
    required this.title,
    this.description = '',
    this.category = ProjectCategory.threeDPrinting,
    this.status = ProjectStatus.planning,
    this.priority = ProjectPriority.medium,
    this.budget = 0.0,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<BOMItem>? bom,
    List<ProjectLog>? logs,
    List<String>? photoPaths,
    this.estimatedPrintHours = 0.0,
    this.estimatedFilamentGrams = 0.0,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        bom = bom ?? [],
        logs = logs ?? [],
        photoPaths = photoPaths ?? [];

  double get totalBOMCost =>
      bom.fold(0.0, (previousValue, item) => previousValue + item.totalCost);

  int get purchasedItemCount => bom.where((i) => i.isPurchased).length;

  double get bomCompletionRatio =>
      bom.isEmpty ? 0.0 : purchasedItemCount / bom.length;

  Project copyWith({
    String? title,
    String? description,
    ProjectCategory? category,
    ProjectStatus? status,
    ProjectPriority? priority,
    double? budget,
    List<String>? tags,
    DateTime? updatedAt,
    List<BOMItem>? bom,
    List<ProjectLog>? logs,
    List<String>? photoPaths,
    double? estimatedPrintHours,
    double? estimatedFilamentGrams,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      budget: budget ?? this.budget,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      bom: bom ?? this.bom,
      logs: logs ?? this.logs,
      photoPaths: photoPaths ?? this.photoPaths,
      estimatedPrintHours: estimatedPrintHours ?? this.estimatedPrintHours,
      estimatedFilamentGrams:
          estimatedFilamentGrams ?? this.estimatedFilamentGrams,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'priority': priority.name,
      'budget': budget,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'bom': bom.map((e) => e.toJson()).toList(),
      'logs': logs.map((e) => e.toJson()).toList(),
      'photoPaths': photoPaths,
      'estimatedPrintHours': estimatedPrintHours,
      'estimatedFilamentGrams': estimatedFilamentGrams,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled Project',
      description: json['description'] as String? ?? '',
      category: ProjectCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ProjectCategory.general,
      ),
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProjectStatus.idea,
      ),
      priority: ProjectPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ProjectPriority.medium,
      ),
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      bom: (json['bom'] as List<dynamic>?)
              ?.map((e) => BOMItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => ProjectLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      photoPaths: (json['photoPaths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      estimatedPrintHours:
          (json['estimatedPrintHours'] as num?)?.toDouble() ?? 0.0,
      estimatedFilamentGrams:
          (json['estimatedFilamentGrams'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
