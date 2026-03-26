import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_theme.dart';
import '../../../core/models/hobby.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/hobby_providers.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 5;

  // Step 0 — Basic Info
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;

  // Step 1 — Photo & Bio
  File? _avatarFile;
  final _bioController = TextEditingController();

  // Step 2 — About You
  String? _selectedGender;
  DateTime? _dateOfBirth;

  // Step 3 — Location
  final _locationController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _detectingLocation = false;

  // Step 4 — Interests
  final Set<int> _selectedHobbyIds = {};
  int? _primaryHobbyId;

  // General
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Username availability ─────────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }
    setState(() {
      _usernameAvailable = null;
      _checkingUsername = true;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      final available =
          await ref.read(authServiceProvider).isUsernameAvailable(trimmed);
      if (mounted) {
        setState(() {
          _usernameAvailable = available;
          _checkingUsername = false;
        });
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _next() async {
    if (_step == 0) {
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim();
      if (name.isEmpty) {
        setState(() => _error = 'Please enter your full name.');
        return;
      }
      if (username.isEmpty) {
        setState(() => _error = 'Please choose a username.');
        return;
      }
      if (_usernameAvailable != true) {
        setState(() => _error = 'Please choose an available username.');
        return;
      }
    }
    setState(() => _error = null);
    if (_step < _totalSteps - 1) {
      _goToStep(_step + 1);
    } else {
      await _submit();
    }
  }

  void _skip() {
    setState(() => _error = null);
    if (_step < _totalSteps - 1) {
      _goToStep(_step + 1);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) _goToStep(_step - 1);
  }

  // ── Avatar picker ─────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final xFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xFile != null && mounted) {
      setState(() => _avatarFile = File(xFile.path));
    }
  }

  // ── Location detection ────────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    setState(() {
      _detectingLocation = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _error = 'Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            _locationController.text = [
              p.locality,
              p.administrativeArea,
              p.country,
            ].where((s) => s != null && s.isNotEmpty).join(', ');
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not detect location.');
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = ref.read(currentUserIdProvider)!;
      final profileService = ProfileService(ref.read(supabaseProvider));

      // 1. Create the profile row
      await ref.read(authServiceProvider).createProfile(
            username: _usernameController.text.trim().toLowerCase(),
            fullName: _nameController.text.trim(),
          );

      // 2. Optional fields
      final optionals = <String, dynamic>{};
      final bio = _bioController.text.trim();
      if (bio.isNotEmpty) optionals['bio'] = bio;
      if (_selectedGender != null) optionals['gender'] = _selectedGender;
      if (_dateOfBirth != null) {
        optionals['date_of_birth'] =
            _dateOfBirth!.toIso8601String().split('T').first;
      }
      final loc = _locationController.text.trim();
      if (loc.isNotEmpty) optionals['location'] = loc;
      if (_latitude != null) optionals['latitude'] = _latitude;
      if (_longitude != null) optionals['longitude'] = _longitude;
      if (optionals.isNotEmpty) {
        await profileService.updateProfile(userId, optionals);
      }

      // 3. Avatar
      if (_avatarFile != null) {
        await profileService.uploadAvatar(userId, _avatarFile!);
      }

      // 4. Hobbies
      if (_selectedHobbyIds.isNotEmpty) {
        await profileService.updateUserHobbies(
          userId,
          _selectedHobbyIds
              .map((id) => (hobbyId: id, isPrimary: id == _primaryHobbyId))
              .toList(),
        );
      }

      if (mounted) {
        ref.read(profileExistsNotifierProvider.notifier).markCreated();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header & progress ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedOpacity(
                        opacity: _step > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: GestureDetector(
                          onTap: _step > 0 ? _back : null,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Step ${_step + 1} of $_totalSteps',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / _totalSteps,
                      minHeight: 4,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Page view ────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0(colors, isDark),
                  _buildStep1(colors, isDark),
                  _buildStep2(colors, isDark),
                  _buildStep3(colors, isDark),
                  _buildStep4(colors, isDark),
                ],
              ),
            ),

            // ── Bottom actions ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _buildGradientButton(
                      label: _step == _totalSteps - 1 ? 'Finish' : 'Continue',
                      colors: colors,
                      loading: _loading,
                      onTap: _loading ? null : _next,
                    ),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading ? null : _skip,
                      child: Text(
                        _step == _totalSteps - 1
                            ? 'Finish later'
                            : 'Skip for now',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  // Sign out escape hatch on step 0
                  if (_step == 0) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => ref.read(authServiceProvider).signOut(),
                      child: Text(
                        'Sign out',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Steps
  // ─────────────────────────────────────────────────────────────────────────

  // Step 0 — Basic Info
  Widget _buildStep0(AppColorScheme colors, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle("What's your name?", 'This is how others will find you.'),
          const SizedBox(height: 28),
          _label('Full Name', isDark),
          const SizedBox(height: 8),
          _textField(
            controller: _nameController,
            hint: 'e.g. Alex Johnson',
            icon: Icons.person_outline_rounded,
            colors: colors,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _label('Username', isDark),
          const SizedBox(height: 8),
          _textField(
            controller: _usernameController,
            hint: 'e.g. alexjohnson',
            icon: Icons.alternate_email_rounded,
            colors: colors,
            isDark: isDark,
            onChanged: _onUsernameChanged,
            suffix: _checkingUsername
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : _usernameAvailable == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          _usernameAvailable!
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: _usernameAvailable!
                              ? Colors.green
                              : Colors.redAccent,
                          size: 20,
                        ),
                      ),
          ),
          const SizedBox(height: 6),
          if (_usernameAvailable == false)
            Text(
              'This username is already taken.',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else if (_usernameAvailable == true)
            Text(
              'Great, this username is available!',
              style: TextStyle(
                color: Colors.green.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  // Step 1 — Photo & Bio
  Widget _buildStep1(AppColorScheme colors, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle('Add a photo & bio', 'Help others know who you are.'),
          const SizedBox(height: 28),

          // Avatar picker
          Center(
            child: GestureDetector(
              onTap: _loading ? null : _pickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _avatarFile == null
                          ? LinearGradient(
                              colors: [
                                colors.primary.withValues(alpha: 0.15),
                                colors.accent.withValues(alpha: 0.15),
                              ],
                            )
                          : null,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.4),
                        width: 2.5,
                      ),
                    ),
                    child: _avatarFile != null
                        ? ClipOval(
                            child:
                                Image.file(_avatarFile!, fit: BoxFit.cover),
                          )
                        : Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: colors.primary.withValues(alpha: 0.5),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.accent],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkScaffold
                              : AppColors.lightScaffold,
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Tap to choose a photo',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 28),
          _label('Bio', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
            child: TextField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 150,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Tell people a bit about yourself…',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2 — About You
  Widget _buildStep2(AppColorScheme colors, bool isDark) {
    const genders = [
      'Male',
      'Female',
      'Non-binary',
      'Other',
      'Prefer not to say',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle(
              'A bit about you', 'Used to personalise your experience.'),
          const SizedBox(height: 28),

          _label('Gender', isDark),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: genders.map((g) {
              final selected = _selectedGender == g;
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedGender = selected ? null : g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.13)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? colors.primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected
                          ? colors.primary
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          _label('Date of Birth', isDark),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ??
                    DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(1920),
                lastDate:
                    DateTime(now.year - 13, now.month, now.day),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: colors.primary,
                      brightness: Theme.of(ctx).brightness,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dateOfBirth = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_rounded,
                      size: 20, color: colors.primary),
                  const SizedBox(width: 12),
                  Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day} / ${_dateOfBirth!.month} / ${_dateOfBirth!.year}'
                        : 'Select your date of birth',
                    style: TextStyle(
                      color: _dateOfBirth != null
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.grey.shade400,
                      fontWeight: _dateOfBirth != null
                          ? FontWeight.w500
                          : FontWeight.w400,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_rounded,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 3 — Location
  Widget _buildStep3(AppColorScheme colors, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepTitle(
              'Where are you based?', 'Helps you connect with people nearby.'),
          const SizedBox(height: 28),

          _label('Location', isDark),
          const SizedBox(height: 8),
          _textField(
            controller: _locationController,
            hint: 'e.g. London, UK',
            icon: Icons.location_on_rounded,
            colors: colors,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _detectingLocation ? null : _detectLocation,
              icon: _detectingLocation
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(Icons.my_location_rounded,
                      color: colors.primary, size: 18),
              label: Text(
                _detectingLocation
                    ? 'Detecting…'
                    : 'Use my current location',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_latitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Location detected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Step 4 — Interests
  Widget _buildStep4(AppColorScheme colors, bool isDark) {
    final hobbiesAsync = ref.watch(allHobbiesProvider);

    return hobbiesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Could not load interests')),
      data: (allHobbies) {
        final categories = <String, List<Hobby>>{};
        for (final h in allHobbies) {
          categories.putIfAbsent(h.category, () => []).add(h);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepTitle('Your interests',
                  'Tap to select · tap again to mark as primary ⭐'),
              if (_selectedHobbyIds.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${_selectedHobbyIds.length} selected'
                  '${_primaryHobbyId != null ? ' · 1 primary' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ...categories.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: entry.value.map((hobby) {
                          final selected =
                              _selectedHobbyIds.contains(hobby.id);
                          final isPrimary = _primaryHobbyId == hobby.id;
                          final color = hobby.colorValue;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (!selected) {
                                  _selectedHobbyIds.add(hobby.id);
                                } else if (!isPrimary) {
                                  _primaryHobbyId = hobby.id;
                                } else {
                                  _selectedHobbyIds.remove(hobby.id);
                                  _primaryHobbyId = null;
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(
                                        alpha: isDark ? 0.2 : 0.1)
                                    : (isDark
                                        ? Colors.white
                                            .withValues(alpha: 0.05)
                                        : Colors.white
                                            .withValues(alpha: 0.9)),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? color.withValues(alpha: 0.7)
                                      : (isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.1)
                                          : Colors.black
                                              .withValues(alpha: 0.08)),
                                  width: isPrimary ? 2 : 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(hobby.icon,
                                      style: const TextStyle(
                                          fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    hobby.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: selected
                                          ? color
                                          : (isDark
                                              ? Colors.white60
                                              : Colors.black54),
                                    ),
                                  ),
                                  if (isPrimary) ...[
                                    const SizedBox(width: 4),
                                    const Text('⭐',
                                        style: TextStyle(
                                            fontSize: 10)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  )),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _stepTitle(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required AppColorScheme colors,
    required bool isDark,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(icon, size: 20, color: colors.primary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 15),
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required AppColorScheme colors,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: loading
                ? [Colors.grey.shade400, Colors.grey.shade400]
                : [colors.primary, colors.accent],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
