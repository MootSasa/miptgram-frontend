import 'package:flutter/material.dart';
import '../../../utils/haptic_utils.dart';

class SoundOption {
  final String id;
  final String title;

  const SoundOption({required this.id, required this.title});
}

const List<SoundOption> kAvailableNotificationSounds = [
  SoundOption(id: '', title: 'По умолчанию (Theaver)'),
  SoundOption(id: 'ding', title: 'Ding'),
  SoundOption(id: 'chime', title: 'Chime'),
  SoundOption(id: 'chord', title: 'Chord'),
  SoundOption(id: 'pop', title: 'Pop'),
  SoundOption(id: 'pulse', title: 'Pulse'),
  SoundOption(id: 'note', title: 'Note'),
  SoundOption(id: 'whistle', title: 'Whistle'),
  SoundOption(id: 'none', title: 'Без звука'),
];

const List<SoundOption> kAvailableRingtones = [
  SoundOption(id: '', title: 'По умолчанию'),
  SoundOption(id: 'ring_classic', title: 'Классический'),
  SoundOption(id: 'ring_digital', title: 'Цифровой'),
  SoundOption(id: 'ring_soft', title: 'Мягкий звонок'),
  SoundOption(id: 'ring_pulse', title: 'Импульс'),
  SoundOption(id: 'none', title: 'Без мелодии'),
];

class SoundPickerSheet extends StatelessWidget {
  final String? currentSoundId;
  final List<SoundOption> options;
  final String title;
  final ValueChanged<String> onSelected;

  const SoundPickerSheet({
    Key? key,
    required this.currentSoundId,
    required this.options,
    required this.title,
    required this.onSelected,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String? currentSoundId,
    required ValueChanged<String> onSelected,
    String title = 'Звук уведомления',
    bool isRingtone = false,
  }) {
    HapticUtils.tap();
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SoundPickerSheet(
        currentSoundId: currentSoundId ?? '',
        options: isRingtone ? kAvailableRingtones : kAvailableNotificationSounds,
        title: title,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedId = currentSoundId ?? '';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final opt = options[index];
                final isSelected = opt.id == selectedId;

                return ListTile(
                  title: Text(opt.title),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFF0088CC))
                      : null,
                  onTap: () {
                    HapticUtils.selection();
                    onSelected(opt.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
