// lib/presentation/screens/settings/settings_screen.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ringtask/blocs/auth/auth_bloc.dart';
import 'package:ringtask/blocs/auth/auth_event.dart';
import 'package:ringtask/blocs/settings/settings_bloc.dart';
import 'package:ringtask/blocs/settings/settings_event.dart';
import 'package:ringtask/blocs/settings/settings_state.dart';
import 'package:ringtask/data/models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool pushNotifications = true;
  bool fingerprintUnlock = false;

  late final AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  SettingsModel? _resolveSettings(SettingsState state) {
    if (state is SettingsLoaded) return state.settings;
    if (state is SettingsUpdateSuccess) return state.settings;
    if (state is SettingsSyncSuccess) return state.syncedSettings;
    if (state is SettingsResetSuccess) return state.defaultSettings;
    if (state is SettingsUpdating) return state.currentSettings;
    return null;
  }

  String _themeModeLabel(String mode) {
    switch (mode) {
      case 'light': return 'Light';
      case 'dark': return 'Dark';
      case 'oled': return 'OLED';
      default: return 'System';
    }
  }

  IconData _themeModeIcon(String mode) {
    switch (mode) {
      case 'light': return Icons.wb_sunny_rounded;
      case 'dark': return Icons.nightlight_round;
      case 'oled': return Icons.brightness_2_rounded;
      default: return Icons.settings_suggest_rounded;
    }
  }

  void _showThemeSheet(BuildContext context, String current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Choose Theme',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            _ThemeOption(
              icon: Icons.wb_sunny_rounded,
              label: 'Light',
              isSelected: current == 'light',
              onTap: () {
                context.read<SettingsBloc>().add(
                    const UpdateThemeSettings(themeMode: 'light'));
                Navigator.pop(sheetCtx);
              },
            ),
            _ThemeOption(
              icon: Icons.nightlight_round,
              label: 'Dark',
              isSelected: current == 'dark',
              onTap: () {
                context.read<SettingsBloc>().add(
                    const UpdateThemeSettings(themeMode: 'dark'));
                Navigator.pop(sheetCtx);
              },
            ),
            _ThemeOption(
              icon: Icons.brightness_2_rounded,
              label: 'OLED (Pure Black)',
              isSelected: current == 'oled',
              onTap: () {
                context.read<SettingsBloc>().add(
                    const UpdateThemeSettings(themeMode: 'oled'));
                Navigator.pop(sheetCtx);
              },
            ),
            _ThemeOption(
              icon: Icons.settings_suggest_rounded,
              label: 'System',
              isSelected: current == 'system',
              onTap: () {
                context.read<SettingsBloc>().add(
                    const UpdateThemeSettings(themeMode: 'system'));
                Navigator.pop(sheetCtx);
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  String _ringtoneLabel(String? path) {
    if (path == null || path.isEmpty) return 'Default';
    if (path.startsWith('content://')) return 'System Ringtone';
    return path.split('/').last;
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  void _showRingtonePickerOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Select Ringtone Source',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.library_music_rounded, color: Color(0xFF2196F3)),
              title: const Text('System Ringtone'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickSystemRingtone(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_rounded, color: Color(0xFF2196F3)),
              title: const Text('Pick Audio File'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAudioFile(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _pickSystemRingtone(BuildContext context) async {
    try {
      const channel = MethodChannel('ringtask/workmanager');
      final String? uri = await channel.invokeMethod<String>('pickRingtone');
      
      if (!context.mounted) return;
      if (uri != null) {
        context.read<SettingsBloc>().add(
          UpdateSingleSetting(key: 'fakeCallRingtone', value: uri),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error picking system ringtone')),
      );
    }
  }

  Future<void> _pickAudioFile(BuildContext context) async {
    // Request permissions first (especially for Android 13+)
    if (Theme.of(context).platform == TargetPlatform.android) {
      final status = await Permission.audio.request();
      if (status.isPermanentlyDenied) {
        if (!context.mounted) return;
        _showPermissionDialog(context);
        return;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (!context.mounted) return;
    if (result == null) return;

    final path = result.files.single.path;

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not access this file. Try a different audio file.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.read<SettingsBloc>().add(
      UpdateSingleSetting(key: 'fakeCallRingtone', value: path),
    );
  }

  Future<void> _togglePreview(String? path) async {
    if (path == null || path.isEmpty) {
      // Play default asset if no custom path
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.stop();
      } else {
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      }
      return;
    }

    if (_playerState == PlayerState.playing) {
      await _audioPlayer.stop();
    } else {
      try {
        if (path.startsWith('content://')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preview not available for system ringtones.')),
          );
        } else {
          await _audioPlayer.play(DeviceFileSource(path));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error playing audio file')),
        );
      }
    }
  }

  void _clearRingtone(BuildContext context) {
    context.read<SettingsBloc>().add(
      const UpdateSingleSetting(key: 'fakeCallRingtone', value: null),
    );
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
            'RingTask needs access to your music files to set a custom ringtone. Please enable it in Settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.read<AuthBloc>().add(const LogoutRequested());
              },
              child: const Text(
                'Log Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsBloc, SettingsState>(
      listenWhen: (_, next) =>
      next is SettingsError || next is SettingsUpdateSuccess,
      listener: (context, state) {
        if (state is SettingsError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
        if (state is SettingsUpdateSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.successMessage ?? 'Settings saved'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
        }
      },
      builder: (context, state) {
        final settings = _resolveSettings(state);
        final themeMode = settings?.themeMode ?? 'light';
        final show24HourTime = settings?.show24HourTime ?? false;
        final ringtonePath = settings?.fakeCallRingtone;
        final isLoading =
            state is SettingsLoading || state is SettingsUpdating;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Account Settings'),
                _buildCard([
                  _buildNavTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildNavTile(
                    icon: Icons.email_outlined,
                    title: 'Manage Email',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionHeader('Appearance & General'),
                _buildCard([
                  ListTile(
                    onTap: () => _showThemeSheet(context, themeMode),
                    leading: Icon(
                      _themeModeIcon(themeMode),
                      color: const Color(0xFF2196F3),
                      size: 24,
                    ),
                    title: const Text('Theme',
                        style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _themeModeLabel(themeMode),
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
                      ],
                    ),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.access_time_rounded,
                    title: 'Use 24-Hour Format',
                    value: show24HourTime,
                    onChanged: (val) {
                      context.read<SettingsBloc>().add(
                        UpdateSingleSetting(key: 'show24HourTime', value: val),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionHeader('Ringtone'),
                _buildCard([_buildRingtoneTile(ringtonePath, context)]),
                const SizedBox(height: 20),
                _buildSectionHeader('Notifications'),
                _buildCard([
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    value: pushNotifications,
                    onChanged: (val) =>
                        setState(() => pushNotifications = val),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionHeader('Privacy & Security'),
                _buildCard([
                  _buildSwitchTile(
                    icon: Icons.fingerprint,
                    title: 'Fingerprint Unlock',
                    value: fingerprintUnlock,
                    onChanged: (val) =>
                        setState(() => fingerprintUnlock = val),
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionHeader('About RingTask'),
                _buildCard([
                  _buildNavTile(
                    icon: Icons.info_outline,
                    title: 'App Information',
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildVersionTile(),
                ]),
                const SizedBox(height: 30),
                _buildLogoutButton(context),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Tile builders ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context)
              .textTheme
              .bodySmall
              ?.color
              ?.withValues(alpha: 0.6),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() => Divider(
    height: 1,
    indent: 56,
    color: Theme.of(context).dividerColor,
  );

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 24),
      title: Text(title,
          style:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      trailing:
      const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2196F3), size: 24),
      title: Text(title,
          style:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF2196F3),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildRingtoneTile(String? path, BuildContext context) {
    final label = _ringtoneLabel(path);
    final hasCustom = path != null && path.isNotEmpty;
    final isPlaying = _playerState == PlayerState.playing;

    return ListTile(
      onTap: () => _showRingtonePickerOptions(context),
      leading: const Icon(Icons.music_note_outlined,
          color: Color(0xFF2196F3), size: 24),
      title: const Text('Ringtone',
          style:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      subtitle: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.stop_circle : Icons.play_circle_filled,
              color: const Color(0xFF2196F3),
              size: 28,
            ),
            onPressed: () => _togglePreview(path),
          ),
          if (hasCustom)
            GestureDetector(
              onTap: () => _clearRingtone(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.grey, size: 16),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
        ],
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildVersionTile() {
    return ListTile(
      leading:
      const Icon(Icons.code, color: Color(0xFF2196F3), size: 24),
      title: const Text('Version',
          style:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      subtitle: const Text('Current application build',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Text('1.0.0',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text(
            'Log Out',
            style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red.shade700,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade100),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Private helper widget ────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isSelected
            ? const Color(0xFF2196F3)
            : Theme.of(context).iconTheme.color,
      ),
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: Color(0xFF2196F3))
          : null,
    );
  }
}