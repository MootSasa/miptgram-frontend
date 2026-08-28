import 'package:flutter/material.dart';

class AdminPermissionsWidget extends StatefulWidget {
  final Map<String, bool> initialPermissions;
  final ValueChanged<Map<String, bool>> onPermissionsChanged;

  const AdminPermissionsWidget({
    super.key,
    required this.initialPermissions,
    required this.onPermissionsChanged,
  });

  @override
  AdminPermissionsWidgetState createState() => AdminPermissionsWidgetState();
}

class AdminPermissionsWidgetState extends State<AdminPermissionsWidget> {
  late Map<String, bool> _permissionStates;
  final List<String> _permissions = [
    'Can manage users',
    'Can delete messages',
    'Can pin messages',
    'Can manage groups',
    'Can change group settings',
    'Can ban users',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize permission states with initial values, defaulting to false for any missing permissions
    _permissionStates = {for (String p in _permissions) p: widget.initialPermissions[p] ?? false};
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _permissions.length,
      itemBuilder: (context, index) {
        final permission = _permissions[index];
        return CheckboxListTile(
          title: Text(permission),
          value: _permissionStates[permission]!,
          onChanged: (bool? value) {
            setState(() {
              _permissionStates[permission] = value!;
            });
            widget.onPermissionsChanged(Map.from(_permissionStates));
          },
          secondary: const Icon(Icons.admin_panel_settings),
        );
      },
    );
  }
}