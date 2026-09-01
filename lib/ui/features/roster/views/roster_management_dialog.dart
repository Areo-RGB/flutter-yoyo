import 'package:flutter/material.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/core/athlete_avatar.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';

class RosterManagementDialog extends StatefulWidget {
  final List<Athlete> athletes;
  final ValueChanged<String> onAddAthlete;
  final ValueChanged<String> onRemoveAthlete;
  final VoidCallback onResetDefaults;
  final VoidCallback onDismiss;

  const RosterManagementDialog({
    super.key,
    required this.athletes,
    required this.onAddAthlete,
    required this.onRemoveAthlete,
    required this.onResetDefaults,
    required this.onDismiss,
  });

  @override
  State<RosterManagementDialog> createState() => _RosterManagementDialogState();
}

class _RosterManagementDialogState extends State<RosterManagementDialog> {
  final _textController = TextEditingController();

  void _handleAdd() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onAddAthlete(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: slate900,
      title: Row(
        children: [
          const Icon(Icons.group, color: athleticBlue),
          const SizedBox(width: 8),
          Text(
            'Manage Athletes Roster (${widget.athletes.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'New athlete name...',
                      hintStyle: TextStyle(color: slate500),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: slate600),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: athleticBlue),
                      ),
                    ),
                    onSubmitted: (_) => _handleAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: athleticBlue),
                  onPressed: _handleAdd,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.athletes.length,
                itemBuilder: (context, index) {
                  final athlete = widget.athletes[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        AthleteAvatar(
                          name: athlete.name,
                          backgroundColor: slate700,
                          radius: 16,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            athlete.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: slate500,
                            size: 20,
                          ),
                          onPressed: () => widget.onRemoveAthlete(athlete.id),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onResetDefaults();
          },
          child: const Text(
            'Reset to 16 Default Names',
            style: TextStyle(color: slate400, fontSize: 12),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: athleticBlue),
          onPressed: () {
            widget.onDismiss();
            Navigator.pop(context);
          },
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
