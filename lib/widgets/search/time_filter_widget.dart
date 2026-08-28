import 'package:flutter/material.dart';

/// A widget for selecting a time period filter for search.
class TimeFilterWidget extends StatefulWidget {
  /// Callback when the selected time period changes.
  final ValueChanged<String?> onChanged;

  /// The currently selected time period.
  final String? selectedPeriod;

  const TimeFilterWidget({
    Key? key,
    required this.onChanged,
    this.selectedPeriod,
  }) : super(key: key);

  @override
  State<TimeFilterWidget> createState() => _TimeFilterWidgetState();
}

class _TimeFilterWidgetState extends State<TimeFilterWidget> {
  late String? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.selectedPeriod;
  }

  @override
  void didUpdateWidget(covariant TimeFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriod != oldWidget.selectedPeriod) {
      _selectedPeriod = widget.selectedPeriod;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: _selectedPeriod,
      isDense: true,
      hint: const Text('Time Period'),
      items: const [
        DropdownMenuItem(
          value: 'today',
          child: Text('Today'),
        ),
        DropdownMenuItem(
          value: 'yesterday',
          child: Text('Yesterday'),
        ),
        DropdownMenuItem(
          value: 'last7days',
          child: Text('Last 7 days'),
        ),
        DropdownMenuItem(
          value: 'last30days',
          child: Text('Last 30 days'),
        ),
        DropdownMenuItem(
          value: 'custom',
          child: Text('Custom'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedPeriod = value;
        });
        widget.onChanged(value);
      },
    );
  }
}