import 'package:flutter/material.dart';

import '../models/game_cell.dart';
import '../services/celebrity_service.dart';

class CellInputDialog extends StatefulWidget {
  final CellSlot slot;
  final CelebrityService service;

  const CellInputDialog({
    super.key,
    required this.slot,
    required this.service,
  });

  @override
  State<CellInputDialog> createState() => _CellInputDialogState();
}

class _CellInputDialogState extends State<CellInputDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name someone: ${slot.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'First name starts with ${slot.requiredFirstInitial}, '
            'last name starts with ${slot.requiredLastInitial}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Type a celebrity name...',
              errorText: _errorText,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _submit,
              ),
            ),
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final celebrity = widget.service.validate(
      text,
      widget.slot.requiredFirstInitial,
      widget.slot.requiredLastInitial,
    );
    if (celebrity != null) {
      Navigator.of(context).pop(celebrity);
    } else {
      setState(() {
        _errorText = 'Not in our database — try another name';
      });
    }
  }
}
