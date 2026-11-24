import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/common.dart';

/// Add-a-note box plus the list of existing notes (newest first as given).
class NotesSection extends StatefulWidget {
  const NotesSection({super.key, required this.notes, required this.onAdd, this.hint = 'Write a note…'});
  final List<Note> notes;
  final ValueChanged<String> onAdd;
  final String hint;

  @override
  State<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    final text = _c.text.trim();
    if (text.isEmpty) {
      AppSnack.error(context, 'Write something first');
      return;
    }
    widget.onAdd(text);
    _c.clear();
    FocusScope.of(context).unfocus();
    AppSnack.success(context, 'Note added');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _c, hint: widget.hint, maxLines: 3),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: AppButton(label: 'Add note', icon: Icons.add_rounded, onPressed: _add, expand: false, compact: true)),
        const SizedBox(height: 16),
        if (widget.notes.isEmpty)
          const EmptyState(icon: Icons.sticky_note_2_outlined, title: 'No notes yet', message: 'Notes you add will appear here.', compact: true)
        else
          for (final n in widget.notes)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              shadow: false,
              color: const Color(0xFFF6F6F2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.text, style: AppText.body),
                  const SizedBox(height: 8),
                  Text(Fmt.dateTime(n.at), style: AppText.caption.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
      ],
    );
  }
}
