import 'package:flutter/material.dart';

import '../models/celebrity.dart';
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
  String? _errorText;

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
          Autocomplete<Celebrity>(
            optionsBuilder: (textEditingValue) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
              return widget.service.search(
                textEditingValue.text,
                slot.requiredFirstInitial,
                slot.requiredLastInitial,
              );
            },
            displayStringForOption: (celebrity) => celebrity.name,
            onSelected: (celebrity) {
              Navigator.of(context).pop(celebrity);
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final celebrity = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(celebrity.name),
                          subtitle: Text(
                            celebrity.occupation,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => onSelected(celebrity),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textController,
                focusNode: focusNode,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Type a celebrity name...',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      _submitManual(textController.text);
                    },
                  ),
                ),
                onSubmitted: (_) {
                  _submitManual(textController.text);
                },
              );
            },
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

  void _submitManual(String text) {
    if (text.trim().isEmpty) return;
    final celebrity = widget.service.validate(
      text,
      widget.slot.requiredFirstInitial,
      widget.slot.requiredLastInitial,
    );
    if (celebrity != null) {
      Navigator.of(context).pop(celebrity);
    } else {
      setState(() {
        _errorText = 'Not found — try selecting from suggestions';
      });
    }
  }
}
