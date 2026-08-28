import 'project.dart';
import 'order_item.dart';

/// A project matched by universal search.
class ProjectSearchHit {
  final Project project;
  const ProjectSearchHit(this.project);
}

/// An order (project-attached or standalone/unlinked) matched by search.
/// [project] is null for standalone (unlinked) orders.
class OrderSearchHit {
  final String description;
  final String pr;
  final String po;
  final double price;
  final DateTime? eta;
  final bool delivered;
  final Project? project;
  final String projectTitle;

  const OrderSearchHit({
    required this.description,
    required this.pr,
    required this.po,
    required this.price,
    required this.delivered,
    this.eta,
    this.project,
    required this.projectTitle,
  });

  factory OrderSearchHit.fromOrder(OrderItem order, Project project) {
    return OrderSearchHit(
      description: order.description,
      pr: order.pr,
      po: order.po,
      price: order.price,
      eta: order.eta,
      delivered: order.delivered,
      project: project,
      projectTitle: project.title,
    );
  }

  bool get isStandalone => project == null;
}

/// A note matched by search — either a voice/written note or a project-attached
/// note (`isProjectNote == true`).
class NoteSearchHit {
  final String title;
  final String content;
  final String? projectId;
  final String? projectTitle;
  final bool isProjectNote;

  const NoteSearchHit({
    required this.title,
    required this.content,
    this.projectId,
    this.projectTitle,
    this.isProjectNote = false,
  });
}

class SearchResults {
  final List<ProjectSearchHit> projects;
  final List<OrderSearchHit> orders;
  final List<NoteSearchHit> notes;

  const SearchResults({
    this.projects = const [],
    this.orders = const [],
    this.notes = const [],
  });

  int get totalCount => projects.length + orders.length + notes.length;
  bool get isEmpty => totalCount == 0;
}
