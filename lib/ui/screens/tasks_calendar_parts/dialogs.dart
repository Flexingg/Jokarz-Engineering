part of '../tasks_calendar_screen.dart';

extension _TasksCalendarDialogs on _TasksCalendarScreenState {
  Future<void> _showDowntimeDialog(DateTime date, {DowntimeEvent? existing}) async {
    final projects = ref.read(projectProvider).projects;
    final machines = <String>{...projects.map((p) => p.machine).where((m) => m.isNotEmpty)};
    final machineCtrl = TextEditingController(text: existing?.machine ?? (machines.isNotEmpty ? machines.first : ''));
    final titleCtrl = TextEditingController(text: existing?.title ?? 'Maintenance');
    final timeCtrl = TextEditingController(text: existing?.timeRange ?? '');
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Add Downtime' : 'Edit Downtime'),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: machineCtrl.text.isEmpty ? null : machineCtrl.text,
          items: machines.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => machineCtrl.text = v ?? '',
          decoration: const InputDecoration(labelText: 'Machine / Line', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. PM - Packer 621', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time range (optional)', hintText: 'e.g. 07:00 - 11:00', isDense: true)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final machine = machineCtrl.text.trim();
          if (machine.isEmpty) return;
          final ev = DowntimeEvent(
            id: existing?.id,
            machine: machine,
            title: titleCtrl.text.trim().isEmpty ? 'Maintenance' : titleCtrl.text.trim(),
            date: date,
            timeRange: timeCtrl.text.trim(),
          );
          final n = ref.read(projectProvider.notifier);
          if (existing == null) { await n.addDowntime(ev); } else { await n.updateDowntime(ev.withId()); }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
  }

  void _showMachineProjects(DowntimeEvent d) {
    final projects = ref.read(projectProvider).projects;
    final matches = projects.where((p) =>
        p.machine.toLowerCase().contains(d.machine.toLowerCase()) ||
        d.machine.toLowerCase().contains(p.machine.toLowerCase())).toList();
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Projects on ${d.machine}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          const Text('No projects on this machine.', style: TextStyle(color: Colors.grey))
        else
          ...matches.map((p) => ListTile(
            dense: true,
            leading: const Icon(Icons.engineering_outlined),
            title: Text('#${p.priority} ${p.title}'),
            subtitle: p.subAssembly.isNotEmpty ? Text(p.subAssembly) : null,
            onTap: () { Navigator.pop(ctx); context.push('/projects/${p.id}'); },
          )),
      ])),
    ));
  }

  Future<void> _showDateNoteDialog(DateTime date) async {
    final current = ref.read(projectProvider);
    final key = DateFormat('yyyy-MM-dd').format(date);
    VoiceNote? existing;
    for (final n in current.voiceNotes) {
      if (n.date != null && DateFormat('yyyy-MM-dd').format(n.date!) == key) {
        existing = n;
        break;
      }
    }

    final titleCtrl = TextEditingController(
        text: existing?.title ?? DateFormat('MM/dd/yyyy').format(date));
    final contentCtrl =
        TextEditingController(text: existing?.transcript ?? '');
    final dateLabel = DateFormat('MMM d').format(date);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Note — $dateLabel' : 'Edit Note — $dateLabel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Defaults to date (MM/DD/YYYY)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Details for this date...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    final notifier = ref.read(projectProvider.notifier);
    final fallbackTitle = DateFormat('MM/dd/yyyy').format(date);

    if (existing != null) {
      await notifier.updateVoiceNote(existing.copyWith(
        title: title.isEmpty ? fallbackTitle : title,
        transcript: content,
        date: date,
      ));
    } else {
      await notifier.addVoiceNote(VoiceNote(
        title: title.isEmpty ? fallbackTitle : title,
        transcript: content,
        durationSeconds: 0,
        date: date,
      ));
    }
  }

  Future<void> _deleteDateNote(DateTime date) async {
    final current = ref.read(projectProvider);
    final key = DateFormat('yyyy-MM-dd').format(date);
    VoiceNote? existing;
    for (final n in current.voiceNotes) {
      if (n.date != null && DateFormat('yyyy-MM-dd').format(n.date!) == key) {
        existing = n;
        break;
      }
    }
    if (existing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Delete the note for ${DateFormat('MMM d').format(date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.of(context).coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(syncStatusProvider.notifier)
          .deleteVoiceNoteEverywhere(existing.id);
    }
  }
}
