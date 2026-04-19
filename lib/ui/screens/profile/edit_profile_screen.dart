import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/hobby.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme_provider.dart';
import '../../../core/utils/avatar_cropper.dart';
import '../../widgets/app_cached_image.dart';
import '../../widgets/custom_avatar_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;

  String? _gender;
  DateTime? _dateOfBirth;

  static const _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Other',
    'Prefer not to say',
  ];

  // hobbyId → isPrimary
  final Map<int, bool> _selectedHobbies = {};

  double? _latitude;
  double? _longitude;

  bool _initialized = false;
  bool _saving = false;
  bool _locating = false;
  bool _avatarUploading = false;
  String? _avatarUrl; // current avatar URL (may be updated locally)
  File? _localAvatarFile; // local file for instant preview after picking

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _populateFields() {
    final profile = ref.read(fullProfileProvider).value;
    final userId = ref.read(currentUserIdProvider);
    final hobbies = userId != null
        ? ref.read(userHobbiesProvider(userId)).value ?? []
        : [];

    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _usernameController.text = profile.username;
      _bioController.text = profile.bio ?? '';
      _phoneController.text = profile.phone ?? '';
      _locationController.text = profile.location ?? '';
      _gender = profile.gender;
      _dateOfBirth = profile.dateOfBirth;
      _avatarUrl = profile.avatarUrl;
      _latitude = profile.latitude;
      _longitude = profile.longitude;
    }

    _selectedHobbies.clear();
    for (final uh in hobbies) {
      _selectedHobbies[uh.hobbyId] = uh.isPrimary;
    }

    _initialized = true;
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1536,
      maxHeight: 1536,
      imageQuality: 95,
    );
    if (picked == null) return;

    final colors = ref.read(appColorSchemeProvider);
    final file = await cropAvatar(
      sourcePath: picked.path,
      toolbarColor: colors.primary,
      activeControlsWidgetColor: colors.primary,
    );
    if (file == null || !mounted) return;

    // Show local file immediately as preview
    setState(() {
      _localAvatarFile = file;
      _avatarUploading = true;
    });

    try {
      final client = ref.read(supabaseProvider);
      final url = await ProfileService(client).uploadAvatar(userId, file);
      if (mounted) {
        setState(() {
          _avatarUrl = url;
          // Keep _localAvatarFile so we keep showing the local preview
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _setCustomAvatar(String url) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _avatarUploading = true);
    try {
      await ProfileService(ref.read(supabaseProvider))
          .updateProfile(userId, {'avatar_url': url});
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _localAvatarFile = null;
      });
      ref.invalidate(fullProfileProvider);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _avatarUploading = true);
    try {
      final client = ref.read(supabaseProvider);
      await ProfileService(client).removeAvatar(userId);
      if (mounted) setState(() {
        _avatarUrl = null;
        _localAvatarFile = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  void _showAvatarOptions(bool isDark, AppColorScheme colors) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                _avatarOptionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from Gallery',
                  color: colors.primary,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                _avatarOptionTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take a Photo',
                  color: colors.primary,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
                _avatarOptionTile(
                  icon: Icons.face_retouching_natural_rounded,
                  label: 'Pick a Custom Avatar',
                  color: colors.primary,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    showCustomAvatarPicker(
                      context,
                      onPicked: _setCustomAvatar,
                    );
                  },
                ),
                if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _avatarOptionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove Photo',
                    color: Colors.red.shade400,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _removeAvatar();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final client = ref.read(supabaseProvider);
    final service = ProfileService(client);

    try {
      await service.updateProfile(userId, {
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'gender': _gender,
        'date_of_birth': _dateOfBirth?.toIso8601String().split('T').first,
      });

      await service.updateUserHobbies(
        userId,
        _selectedHobbies.entries
            .map((e) => (hobbyId: e.key, isPrimary: e.value))
            .toList(),
      );

      ref.invalidate(currentProfileProvider);
      ref.invalidate(fullProfileProvider);
      ref.invalidate(userHobbiesProvider(userId));

      if (mounted) {
        HapticFeedback.lightImpact();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _trackLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission permanently denied.'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality?.isNotEmpty == true
            ? p.locality!
            : p.subAdministrativeArea?.isNotEmpty == true
                ? p.subAdministrativeArea!
                : p.administrativeArea ?? '';
        final country = p.country ?? '';
        final locationString = [city, country]
            .where((s) => s.isNotEmpty)
            .join(', ');
        if (mounted) {
          setState(() => _locationController.text = locationString);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(fullProfileProvider);
    final userId = ref.watch(currentUserIdProvider);
    final hobbiesAsync = userId != null
        ? ref.watch(userHobbiesProvider(userId))
        : const AsyncValue<List<Never>>.loading();
    final allHobbiesAsync = ref.watch(allHobbiesProvider);

    final isLoading = profileAsync.isLoading || hobbiesAsync.isLoading || allHobbiesAsync.isLoading;
    final hasError = profileAsync.hasError || allHobbiesAsync.hasError;

    if (!_initialized && !isLoading && !hasError && profileAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized) {
          setState(() => _populateFields());
        }
      });
    }

    final bgColor = isDark ? AppColors.darkScaffold : AppColors.lightScaffold;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: 22,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _saving
                        ? [colors.primary.withValues(alpha: 0.5), colors.accent.withValues(alpha: 0.5)]
                        : [colors.primary, colors.accent],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Text(
                    'Failed to load profile',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                )
              : _buildForm(context, colors, isDark, allHobbiesAsync.value ?? []),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppColorScheme colors,
    bool isDark,
    List<Hobby> allHobbies,
  ) {
    final inputDeco = _inputDecoration(isDark);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Avatar ─────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: () => _showAvatarOptions(isDark, colors),
              child: SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade200,
                      ),
                      child: _avatarUploading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : ClipOval(
                              child: _localAvatarFile != null
                                  ? Image.file(
                                      _localAvatarFile!,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                    )
                                  : AppCachedImage(
                                      imageUrl: _avatarUrl,
                                      width: 84,
                                      height: 84,
                                      errorWidget: Icon(
                                        Icons.person,
                                        size: 36,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor(isDark), width: 2.5),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Name + Username row ────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Name', isDark),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: inputDeco.copyWith(hintText: 'Full name'),
                      style: _inputTextStyle(isDark),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Username', isDark),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _usernameController,
                      decoration: inputDeco.copyWith(
                        hintText: 'username',
                        prefixText: '@',
                        prefixStyle: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: _inputTextStyle(isDark),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Bio ────────────────────────────────────────────
          _label('Bio', isDark),
          const SizedBox(height: 4),
          TextFormField(
            controller: _bioController,
            decoration: inputDeco.copyWith(hintText: 'A short bio about yourself'),
            style: _inputTextStyle(isDark),
            maxLines: 2,
            maxLength: 150,
          ),

          const SizedBox(height: 10),

          // ── Phone ──────────────────────────────────────────
          _label('Phone', isDark),
          const SizedBox(height: 4),
          TextFormField(
            controller: _phoneController,
            decoration: inputDeco.copyWith(hintText: 'Phone'),
            style: _inputTextStyle(isDark),
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 14),

          // ── Gender ─────────────────────────────────────────
          _label('Gender', isDark),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderOptions.map((g) {
              final selected = _gender == g;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _gender = selected ? null : g);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.13)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? colors.primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected
                          ? colors.primary
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ── Location ───────────────────────────────────────
          _label('Location', isDark),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _locationController,
                  decoration: inputDeco.copyWith(hintText: 'City, Country'),
                  style: _inputTextStyle(isDark),
                ),
              ),
              const SizedBox(width: 8),
              _buildTrackLocationButton(isDark, colors),
            ],
          ),

          const SizedBox(height: 14),

          // ── Date of Birth ──────────────────────────────────
          _label('Date of Birth', isDark),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(now.year - 18),
                firstDate: DateTime(1920),
                lastDate: DateTime(now.year - 13, now.month, now.day),
              );
              if (picked != null) setState(() => _dateOfBirth = picked);
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      color: _dateOfBirth != null
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Hobbies ────────────────────────────────────────
          Row(
            children: [
              _label('Hobbies', isDark),
              const SizedBox(width: 6),
              Text(
                '${_selectedHobbies.length}/5',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _selectedHobbies.length >= 5
                      ? Colors.orange.shade400
                      : Colors.grey.shade500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showHobbyPicker(allHobbies, isDark, colors);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18, color: colors.primary),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedHobbies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Long-press to set primary',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
          const SizedBox(height: 8),
          _buildSelectedHobbies(allHobbies, isDark),
        ],
      ),
    );
  }

  // Background color helper for avatar border
  Color bgColor(bool isDark) =>
      isDark ? AppColors.darkScaffold : AppColors.lightScaffold;

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
        letterSpacing: 0.1,
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor:
          isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ref.read(appColorSchemeProvider).primary,
          width: 1.5,
        ),
      ),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
    );
  }

  TextStyle _inputTextStyle(bool isDark) {
    return TextStyle(
      fontSize: 14,
      color: isDark ? Colors.white : Colors.black,
    );
  }

  Widget _buildSelectedHobbies(List<Hobby> allHobbies, bool isDark) {
    final colors = ref.watch(appColorSchemeProvider);
    final hobbyMap = {for (final h in allHobbies) h.id: h};

    if (_selectedHobbies.isEmpty) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showHobbyPicker(allHobbies, isDark, colors);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              style: BorderStyle.solid,
            ),
          ),
          child: Center(
            child: Text(
              'Tap "See all" to add hobbies',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // Sort: primary first, then by id
    final sortedEntries = _selectedHobbies.entries.toList()
      ..sort((a, b) {
        if (a.value && !b.value) return -1;
        if (!a.value && b.value) return 1;
        return a.key.compareTo(b.key);
      });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: sortedEntries.map((entry) {
        final hobby = hobbyMap[entry.key];
        if (hobby == null) return const SizedBox.shrink();
        final isPrimary = entry.value;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedHobbies.remove(hobby.id));
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() {
              for (final key in _selectedHobbies.keys.toList()) {
                _selectedHobbies[key] = false;
              }
              _selectedHobbies[hobby.id] = true;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPrimary
                  ? colors.primary
                  : hobby.colorValue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary
                    ? colors.primary
                    : hobby.colorValue.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hobby.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  hobby.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isPrimary
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                if (isPrimary) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: isPrimary
                      ? Colors.white70
                      : (isDark ? Colors.white54 : Colors.black38),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showHobbyPicker(List<Hobby> allHobbies, bool isDark, AppColorScheme colors) {
    // Work on a local copy so we can cancel
    final localSelected = Map<int, bool>.from(_selectedHobbies);
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = searchQuery.isEmpty
                ? allHobbies
                : allHobbies
                    .where((h) =>
                        h.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        h.category.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            // Group by category
            final grouped = <String, List<Hobby>>{};
            for (final h in filtered) {
              grouped.putIfAbsent(h.category, () => []).add(h);
            }
            final categories = grouped.keys.toList()..sort();

            return Dialog(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                    child: Row(
                      children: [
                        Text(
                          'Choose Hobbies',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${localSelected.length}/5',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: localSelected.length >= 5
                                ? Colors.orange.shade400
                                : Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      onChanged: (v) => setDialogState(() => searchQuery = v),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search hobbies...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Colors.grey.shade500,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Hobby list grouped by category
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: categories.length,
                      itemBuilder: (context, catIndex) {
                        final category = categories[catIndex];
                        final hobbies = grouped[category]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (catIndex > 0) const SizedBox(height: 10),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: hobbies.map((hobby) {
                                final isSelected =
                                    localSelected.containsKey(hobby.id);
                                final isPrimary =
                                    localSelected[hobby.id] == true;

                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setDialogState(() {
                                      if (isSelected) {
                                        localSelected.remove(hobby.id);
                                      } else if (localSelected.length < 5) {
                                        localSelected[hobby.id] = false;
                                      }
                                    });
                                  },
                                  onLongPress: () {
                                    if (!isSelected) return;
                                    HapticFeedback.mediumImpact();
                                    setDialogState(() {
                                      for (final key
                                          in localSelected.keys.toList()) {
                                        localSelected[key] = false;
                                      }
                                      localSelected[hobby.id] = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isPrimary
                                              ? colors.primary
                                              : hobby.colorValue.withValues(
                                                  alpha: 0.15))
                                          : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.06)
                                              : Colors.grey.shade100),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? (isPrimary
                                                ? colors.primary
                                                : hobby.colorValue
                                                    .withValues(alpha: 0.5))
                                            : Colors.transparent,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(hobby.icon,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                        const SizedBox(width: 5),
                                        Text(
                                          hobby.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: isPrimary
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                        if (isPrimary) ...[
                                          const SizedBox(width: 3),
                                          const Icon(Icons.star_rounded,
                                              size: 13,
                                              color: Colors.white),
                                        ],
                                        if (isSelected && !isPrimary) ...[
                                          const SizedBox(width: 3),
                                          Icon(Icons.check_rounded,
                                              size: 14,
                                              color: hobby.colorValue),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Done button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedHobbies
                              ..clear()
                              ..addAll(localSelected);
                          });
                          Navigator.pop(dialogContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.accent],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackLocationButton(bool isDark, AppColorScheme colors) {
    return GestureDetector(
      onTap: _locating ? null : _trackLocation,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: _locating
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : Icon(
                  Icons.my_location_rounded,
                  color: colors.primary,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
