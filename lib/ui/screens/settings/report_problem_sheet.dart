import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_theme.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/services/report_service.dart';
import '../../../core/theme_provider.dart';

// Until the `reported_entity_type` enum gains an 'app' value, app-level
// problem reports are stored against the reporter's own profile id with
// category='other' and a type prefix in the description.
const _types = [
  (value: 'bug', label: 'Bug or crash'),
  (value: 'feedback', label: 'Feedback or suggestion'),
  (value: 'content', label: 'Inappropriate content'),
  (value: 'other', label: 'Something else'),
];

Future<void> showReportProblemSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _ReportProblemSheet(),
  );
}

class _ReportProblemSheet extends ConsumerStatefulWidget {
  const _ReportProblemSheet();

  @override
  ConsumerState<_ReportProblemSheet> createState() =>
      _ReportProblemSheetState();
}

class _ReportProblemSheetState extends ConsumerState<_ReportProblemSheet> {
  String _selectedType = _types.first.value;
  final _descriptionCtrl = TextEditingController();
  bool _saving = false;
  String? _descriptionError;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final text = _descriptionCtrl.text.trim();
    if (text.length < 10) {
      setState(
        () => _descriptionError = 'Please add at least 10 characters',
      );
      return;
    }

    setState(() {
      _descriptionError = null;
      _saving = true;
    });

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final typeLabel =
        _types.firstWhere((t) => t.value == _selectedType).label;

    try {
      await ReportService(ref.read(supabaseProvider)).submitReport(
        reporterId: userId,
        reportedEntityId: userId,
        reportedEntityType: 'profile',
        category: _selectedType == 'content'
            ? 'inappropriate_content'
            : 'other',
        description: '[$typeLabel] $text',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thanks for letting us know.')),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _descriptionError = 'Could not submit: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(appColorSchemeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final border = _descriptionError != null
        ? Colors.red.withValues(alpha: 0.5)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));
    final subtleText = isDark ? Colors.white54 : Colors.black54;
    final tileText = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Report a problem',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: tileText,
                    ),
                  ),
                  const Spacer(),
                  if (_saving)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary, colors.accent],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\u2019s happening?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtleText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final isSelected = _selectedType == t.value;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedType = t.value);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withValues(alpha: 0.15)
                                : fieldBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.06)),
                            ),
                          ),
                          child: Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? colors.primary : tileText,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Describe it',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtleText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _descriptionCtrl,
                      maxLines: 5,
                      maxLength: 800,
                      style: TextStyle(color: tileText, fontSize: 14),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                        hintText: 'Include steps, what you expected, and what happened',
                        hintStyle: TextStyle(
                          color: subtleText,
                          fontSize: 14,
                        ),
                        counterStyle: TextStyle(
                          color: subtleText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  if (_descriptionError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _descriptionError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
