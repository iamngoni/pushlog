import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class TrainingOnboardingPage extends StatefulWidget {
  const TrainingOnboardingPage({
    required this.preferences,
    this.isEditing = false,
    super.key,
  });

  final WorkoutPreferences preferences;
  final bool isEditing;

  @override
  State<TrainingOnboardingPage> createState() => _TrainingOnboardingPageState();
}

class _TrainingOnboardingPageState extends State<TrainingOnboardingPage> {
  static const _stepCount = 9;

  late int _stepIndex;
  late TrainingGoal _goal;
  late TrainingExperience _experience;
  late BaselineSource _baselineSource;
  late int _durationWeeks;
  late int _sessionsPerWeek;
  late List<int> _preferredWeekdays;
  late ConsistencyPreference _consistencyPreference;
  late CoachingStyle _coachingStyle;
  late bool _remindersEnabled;
  late TimeOfDay _reminderTime;
  late TextEditingController _baselineController;
  late TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    final plan = widget.preferences.trainingPlan;
    final profile = plan?.profile;
    _stepIndex = 0;
    _goal = profile?.goal ?? TrainingGoal.buildHabit;
    _experience = profile?.experience ?? TrainingExperience.newToTraining;
    _baselineSource = profile?.baselineSource ?? BaselineSource.recentResult;
    _durationWeeks = profile?.durationWeeks ?? 12;
    _sessionsPerWeek = profile?.sessionsPerWeek ?? 2;
    _preferredWeekdays = List<int>.from(
      profile?.preferredWeekdays ??
          TrainingProfile.defaultWeekdays(_sessionsPerWeek),
    );
    _consistencyPreference =
        profile?.consistencyPreference ?? ConsistencyPreference.weeklyPlan;
    _coachingStyle = profile?.coachingStyle ?? CoachingStyle.calm;
    _remindersEnabled = widget.preferences.remindersEnabled;
    _reminderTime = TimeOfDay(
      hour: widget.preferences.reminderHour,
      minute: widget.preferences.reminderMinute,
    );
    _baselineController = TextEditingController(
      text: '${profile?.baselineMaxReps ?? 5}',
    );
    _targetController = TextEditingController(
      text: '${profile?.targetMaxReps ?? 15}',
    );
  }

  @override
  void dispose() {
    _baselineController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeOutQuart,
                child: SingleChildScrollView(
                  key: ValueKey(_stepIndex),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                  child: _buildStep(theme),
                ),
              ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppTheme theme) {
    final progress = (_stepIndex + 1) / _stepCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'PUSHLOG',
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                  letterSpacing: 3,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'STEP ${_stepIndex + 1} OF $_stepCount',
                style: AppTypography.labelMono(
                  size: 10,
                  color: theme.secondaryInk,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: progress,
              color: theme.accent,
              backgroundColor: theme.divider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(AppTheme theme) {
    return switch (_stepIndex) {
      0 => _goalStep(theme),
      1 => _experienceStep(theme),
      2 => _baselineStep(theme),
      3 => _outcomeStep(theme),
      4 => _scheduleStep(theme),
      5 => _consistencyStep(theme),
      6 => _coachingStep(theme),
      7 => _reminderStep(theme),
      _ => _previewStep(theme),
    };
  }

  Widget _goalStep(AppTheme theme) {
    return _Question(
      title: 'What should Pushlog help you change?',
      detail: 'Choose the reason you want to keep showing up.',
      theme: theme,
      children: [
        _choice(
          theme,
          title: 'Build a consistent habit',
          detail: 'Start manageable and make training routine.',
          selected: _goal == TrainingGoal.buildHabit,
          onTap: () => setState(() => _goal = TrainingGoal.buildHabit),
        ),
        _choice(
          theme,
          title: 'Increase my maximum',
          detail: 'Work toward more clean, unbroken repetitions.',
          selected: _goal == TrainingGoal.increaseMaximum,
          onTap: () => setState(() => _goal = TrainingGoal.increaseMaximum),
        ),
        _choice(
          theme,
          title: 'Improve endurance',
          detail: 'Build repeatable sets and total session volume.',
          selected: _goal == TrainingGoal.improveEndurance,
          onTap: () => setState(() => _goal = TrainingGoal.improveEndurance),
        ),
        _choice(
          theme,
          title: 'Maintain my ability',
          detail: 'Keep current capacity with a reliable schedule.',
          selected: _goal == TrainingGoal.maintainAbility,
          onTap: () {
            setState(() {
              _goal = TrainingGoal.maintainAbility;
              _targetController.text = _baselineController.text;
            });
          },
        ),
        _choice(
          theme,
          title: 'Set my own target',
          detail: 'Control the outcome and schedule directly.',
          selected: _goal == TrainingGoal.custom,
          onTap: () => setState(() => _goal = TrainingGoal.custom),
        ),
      ],
    );
  }

  Widget _experienceStep(AppTheme theme) {
    return _Question(
      title: 'Which description fits today?',
      detail:
          'This changes the starting workload, not which controls you can use.',
      theme: theme,
      children: [
        _choice(
          theme,
          title: 'New or returning',
          detail: 'I am starting, or returning after a long break.',
          selected: _experience == TrainingExperience.newToTraining,
          onTap: () => _setExperience(TrainingExperience.newToTraining),
        ),
        _choice(
          theme,
          title: 'Training regularly',
          detail: 'I currently train one to three times per week.',
          selected: _experience == TrainingExperience.regular,
          onTap: () => _setExperience(TrainingExperience.regular),
        ),
        _choice(
          theme,
          title: 'Experienced',
          detail: 'I train consistently and want direct plan control.',
          selected: _experience == TrainingExperience.experienced,
          onTap: () => _setExperience(TrainingExperience.experienced),
        ),
      ],
    );
  }

  Widget _baselineStep(AppTheme theme) {
    return _Question(
      title: 'What is your current baseline?',
      detail:
          'Use clean repetitions and stop before form breaks. '
          'Stop if you feel pain.',
      theme: theme,
      children: [
        _choice(
          theme,
          title: 'Use a recent result',
          detail: 'I know roughly how many clean push-ups I can do.',
          selected: _baselineSource == BaselineSource.recentResult,
          onTap: () =>
              setState(() => _baselineSource = BaselineSource.recentResult),
        ),
        _choice(
          theme,
          title: 'Guide me through a test',
          detail: 'Start conservatively, then reassess from the Today screen.',
          selected: _baselineSource == BaselineSource.guidedAssessment,
          onTap: () => setState(() {
            _baselineSource = BaselineSource.guidedAssessment;
            _setConservativeBaseline();
          }),
        ),
        _choice(
          theme,
          title: 'Start conservatively',
          detail: 'Use a low estimate and adjust from completed sessions.',
          selected: _baselineSource == BaselineSource.conservativeStart,
          onTap: () => setState(() {
            _baselineSource = BaselineSource.conservativeStart;
            _setConservativeBaseline();
          }),
        ),
        const SizedBox(height: 8),
        _numberField(
          theme,
          controller: _baselineController,
          label: _baselineSource == BaselineSource.recentResult
              ? 'CURRENT CLEAN MAX'
              : 'TEMPORARY STARTING ESTIMATE',
          suffix: 'REPS',
          enabled: _baselineSource == BaselineSource.recentResult,
          onChanged: (value) {
            final baseline = int.tryParse(value);
            final target = int.tryParse(_targetController.text);
            if (baseline != null && (target == null || target < baseline)) {
              _targetController.text = '${baseline + 5}';
            }
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _outcomeStep(AppTheme theme) {
    return _Question(
      title: 'Where would you like to be?',
      detail:
          'This is your target, not a guaranteed prediction. '
          'You can adjust it at any time.',
      theme: theme,
      children: [
        _numberField(
          theme,
          controller: _targetController,
          label: 'TARGET CLEAN MAX',
          suffix: 'REPS',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 22),
        _sectionLabel(theme, 'PLAN LENGTH'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final weeks in const [8, 12, 16]) ...[
              Expanded(
                child: _CompactChoice(
                  label: '$weeks WEEKS',
                  selected: _durationWeeks == weeks,
                  theme: theme,
                  onTap: () => setState(() => _durationWeeks = weeks),
                ),
              ),
              if (weeks != 16) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _scheduleStep(AppTheme theme) {
    return _Question(
      title: 'When can you train consistently?',
      detail:
          'Choose two to five sessions. Planned recovery days never break '
          'your progress.',
      theme: theme,
      children: [
        _sectionLabel(theme, 'SESSIONS PER WEEK'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final count in const [2, 3, 4, 5]) ...[
              Expanded(
                child: _CompactChoice(
                  label: '$count',
                  selected: _sessionsPerWeek == count,
                  theme: theme,
                  onTap: () => _setSessionsPerWeek(count),
                ),
              ),
              if (count != 5) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 26),
        _sectionLabel(
          theme,
          'TRAINING DAYS ${_preferredWeekdays.length}/$_sessionsPerWeek',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              SizedBox(
                width: 56,
                child: _CompactChoice(
                  label: _weekdayLabel(weekday),
                  selected: _preferredWeekdays.contains(weekday),
                  theme: theme,
                  onTap: () => _toggleWeekday(weekday),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _consistencyStep(AppTheme theme) {
    return _Question(
      title: 'What should staying on track mean?',
      detail: 'Choose motivation that respects recovery and real life.',
      theme: theme,
      children: [
        _choice(
          theme,
          title: 'Complete the weekly plan',
          detail: 'Track how many planned sessions you finish each week.',
          selected: _consistencyPreference == ConsistencyPreference.weeklyPlan,
          onTap: () => setState(
            () => _consistencyPreference = ConsistencyPreference.weeklyPlan,
          ),
        ),
        _choice(
          theme,
          title: 'Keep scheduled sessions',
          detail:
              'Count consecutive planned sessions. Recovery days are skipped.',
          selected:
              _consistencyPreference == ConsistencyPreference.scheduledSessions,
          onTap: () => setState(
            () => _consistencyPreference =
                ConsistencyPreference.scheduledSessions,
          ),
        ),
        _choice(
          theme,
          title: 'No streak',
          detail: 'Show completed work without a consistency counter.',
          selected: _consistencyPreference == ConsistencyPreference.none,
          onTap: () => setState(
            () => _consistencyPreference = ConsistencyPreference.none,
          ),
        ),
      ],
    );
  }

  Widget _coachingStep(AppTheme theme) {
    return _Question(
      title: 'How should Pushlog coach you?',
      detail:
          'This changes reminders and celebrations. '
          'It never changes your data.',
      theme: theme,
      children: [
        _choice(
          theme,
          title: 'Calm',
          detail: 'Concise, supportive prompts with low pressure.',
          selected: _coachingStyle == CoachingStyle.calm,
          onTap: () => setState(() => _coachingStyle = CoachingStyle.calm),
        ),
        _choice(
          theme,
          title: 'Energetic',
          detail:
              'Stronger encouragement and more visible completion feedback.',
          selected: _coachingStyle == CoachingStyle.energetic,
          onTap: () => setState(() => _coachingStyle = CoachingStyle.energetic),
        ),
        _choice(
          theme,
          title: 'Minimal',
          detail: 'Targets, progress, and status with almost no coaching copy.',
          selected: _coachingStyle == CoachingStyle.minimal,
          onTap: () => setState(() => _coachingStyle = CoachingStyle.minimal),
        ),
      ],
    );
  }

  Widget _reminderStep(AppTheme theme) {
    return _Question(
      title: 'Would a training-day reminder help?',
      detail: 'Pushlog only schedules reminders on the days you selected.',
      theme: theme,
      children: [
        _choice(
          theme,
          title: 'Remind me',
          detail: 'Ask for notification permission when the plan is saved.',
          selected: _remindersEnabled,
          onTap: () => setState(() => _remindersEnabled = true),
        ),
        _choice(
          theme,
          title: 'Not now',
          detail: 'You can enable reminders later in Settings.',
          selected: !_remindersEnabled,
          onTap: () => setState(() => _remindersEnabled = false),
        ),
        if (_remindersEnabled) ...[
          const SizedBox(height: 12),
          Material(
            color: theme.surface,
            child: InkWell(
              onTap: _pickReminderTime,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.divider),
                ),
                child: Row(
                  children: [
                    Text(
                      'REMINDER TIME',
                      style: AppTypography.labelMono(
                        size: 10,
                        color: theme.secondaryInk,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _reminderTime.format(context),
                      style: AppTypography.title(color: theme.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _previewStep(AppTheme theme) {
    final plan = _buildPlan();
    final firstDate = _firstTrainingDate(plan, plan.startDate);
    final firstSession = plan.sessionFor(firstDate);
    final endLabel = _shortDate(plan.endDate);
    return _Question(
      title: 'Your starting plan',
      detail: 'Review the first week. Every choice remains editable.',
      theme: theme,
      children: [
        _PreviewRow(
          label: 'TARGET',
          value: '${plan.profile.targetMaxReps} CLEAN REPS',
          detail: 'ASPIRATION BY $endLabel',
          theme: theme,
        ),
        _PreviewRow(
          label: 'FIRST SESSION',
          value: '${firstSession.sets} × ${firstSession.repsPerSet}',
          detail:
              '${firstSession.totalReps} TOTAL REPS · ${_shortDate(firstDate)}',
          theme: theme,
        ),
        _PreviewRow(
          label: 'SCHEDULE',
          value: '${plan.profile.sessionsPerWeek} DAYS / WEEK',
          detail: plan.profile.preferredWeekdays.map(_weekdayLabel).join(' · '),
          theme: theme,
        ),
        _PreviewRow(
          label: 'REASSESS',
          value: 'EVERY 4 WEEKS',
          detail: 'ADJUST FROM COMPLETED WORK',
          theme: theme,
        ),
        const SizedBox(height: 18),
        Text(
          'Pushlog starts working sets below your reported maximum and changes '
          'whole repetitions gradually. The target is not a guarantee. '
          'Stop training if you feel pain.',
          style: AppTypography.body(color: theme.secondaryInk),
        ),
      ],
    );
  }

  Widget _choice(
    AppTheme theme, {
    required String title,
    required String detail,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ChoiceTile(
        title: title,
        detail: detail,
        selected: selected,
        theme: theme,
        onTap: onTap,
      ),
    );
  }

  Widget _numberField(
    AppTheme theme, {
    required TextEditingController controller,
    required String label,
    required String suffix,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: AppTypography.headingMedium(color: theme.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.labelMono(
          size: 10,
          color: theme.secondaryInk,
          letterSpacing: 1.2,
        ),
        suffixText: suffix,
        suffixStyle: AppTypography.labelMono(
          color: theme.secondaryInk,
          letterSpacing: 1.2,
        ),
        filled: true,
        fillColor: enabled ? theme.surface : theme.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.divider),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: theme.accent, width: 2),
        ),
      ),
    );
  }

  Widget _sectionLabel(AppTheme theme, String label) {
    return Text(
      label,
      style: AppTypography.labelMono(
        size: 10,
        color: theme.secondaryInk,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _buildFooter(AppTheme theme) {
    final canContinue = _isCurrentStepValid;
    final isLast = _stepIndex == _stepCount - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.divider)),
      ),
      child: Row(
        children: [
          if (_stepIndex > 0 || widget.isEditing) ...[
            Expanded(
              child: _FooterButton(
                label: _stepIndex == 0 ? 'CANCEL' : 'BACK',
                theme: theme,
                onTap: _stepIndex == 0
                    ? () => Navigator.of(context).pop()
                    : _previous,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: _FooterButton(
              label: isLast
                  ? widget.isEditing
                        ? 'SAVE PLAN'
                        : 'START PLAN'
                  : 'CONTINUE',
              theme: theme,
              emphasized: true,
              enabled: canContinue,
              onTap: isLast ? _finish : _next,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isCurrentStepValid {
    final baseline = int.tryParse(_baselineController.text) ?? 0;
    final target = int.tryParse(_targetController.text) ?? 0;
    return switch (_stepIndex) {
      2 => baseline > 0,
      3 => target > 0,
      4 => _preferredWeekdays.length == _sessionsPerWeek,
      _ => true,
    };
  }

  void _next() {
    if (!_isCurrentStepValid || _stepIndex >= _stepCount - 1) return;
    FocusScope.of(context).unfocus();
    setState(() => _stepIndex += 1);
  }

  void _previous() {
    if (_stepIndex <= 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _stepIndex -= 1);
  }

  void _setExperience(TrainingExperience experience) {
    final sessionCount = switch (experience) {
      TrainingExperience.newToTraining => 2,
      TrainingExperience.regular => 3,
      TrainingExperience.experienced => 4,
    };
    setState(() {
      _experience = experience;
      _sessionsPerWeek = sessionCount;
      _preferredWeekdays = TrainingProfile.defaultWeekdays(sessionCount);
    });
  }

  void _setConservativeBaseline() {
    _baselineController.text = '5';
    final target = int.tryParse(_targetController.text) ?? 0;
    if (target < 5) _targetController.text = '15';
  }

  void _setSessionsPerWeek(int count) {
    setState(() {
      _sessionsPerWeek = count;
      _preferredWeekdays = TrainingProfile.defaultWeekdays(count);
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_preferredWeekdays.contains(weekday)) {
        _preferredWeekdays.remove(weekday);
      } else if (_preferredWeekdays.length < _sessionsPerWeek) {
        _preferredWeekdays
          ..add(weekday)
          ..sort();
      }
    });
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (selected == null || !mounted) return;
    setState(() => _reminderTime = selected);
  }

  TrainingProfile _buildProfile() {
    final baseline = int.tryParse(_baselineController.text) ?? 5;
    final enteredTarget = int.tryParse(_targetController.text) ?? baseline;
    final target = _goal == TrainingGoal.maintainAbility
        ? baseline
        : enteredTarget;
    return TrainingProfile(
      goal: _goal,
      experience: _experience,
      baselineSource: _baselineSource,
      baselineMaxReps: baseline.clamp(1, 999),
      targetMaxReps: target.clamp(1, 999),
      durationWeeks: _durationWeeks,
      sessionsPerWeek: _sessionsPerWeek,
      preferredWeekdays: List<int>.unmodifiable(_preferredWeekdays),
      consistencyPreference: _consistencyPreference,
      coachingStyle: _coachingStyle,
    );
  }

  TrainingPlan _buildPlan() {
    final existingPlan = widget.preferences.trainingPlan;
    if (widget.isEditing && existingPlan != null) {
      return existingPlan.copyWith(profile: _buildProfile());
    }
    final now = DateTime.now();
    return TrainingPlan(
      profile: _buildProfile(),
      startDate: DateTime(now.year, now.month, now.day),
      createdAt: now,
    );
  }

  void _finish() {
    if (!_isCurrentStepValid) return;
    final plan = _buildPlan();
    final updatedPreferences = widget.preferences.copyWith(
      remindersEnabled: _remindersEnabled,
      reminderHour: _reminderTime.hour,
      reminderMinute: _reminderTime.minute,
      trainingPlan: () => plan,
    );
    context.read<WorkoutBloc>().add(UpdatePreferencesEvent(updatedPreferences));
    if (widget.isEditing) {
      Navigator.of(context).pop();
    }
  }

  DateTime _firstTrainingDate(TrainingPlan plan, DateTime from) {
    var cursor = from;
    for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
      if (plan.isTrainingDay(cursor)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return from;
  }

  String _weekdayLabel(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'MON',
      DateTime.tuesday => 'TUE',
      DateTime.wednesday => 'WED',
      DateTime.thursday => 'THU',
      DateTime.friday => 'FRI',
      DateTime.saturday => 'SAT',
      _ => 'SUN',
    };
  }

  String _shortDate(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.title,
    required this.detail,
    required this.theme,
    required this.children,
  });

  final String title;
  final String detail;
  final AppTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headingLarge(color: theme.ink)),
        const SizedBox(height: 12),
        Text(detail, style: AppTypography.bodyLarge(color: theme.secondaryInk)),
        const SizedBox(height: 28),
        ...children,
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.detail,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? theme.surface : theme.background,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? theme.accent : theme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: AppTypography.title(color: theme.ink)),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: AppTypography.body(color: theme.secondaryInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  selected ? 'SELECTED' : 'SELECT',
                  style: AppTypography.labelMono(
                    size: 9,
                    color: selected ? theme.accentInk : theme.secondaryInk,
                    letterSpacing: 1,
                    weight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactChoice extends StatelessWidget {
  const _CompactChoice({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? theme.accent : theme.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? theme.accent : theme.divider,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.labelMono(
                size: 10,
                color: selected ? AppColors.fixedDark : theme.ink,
                letterSpacing: 1,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    required this.detail,
    required this.theme,
  });

  final String label;
  final String value;
  final String detail;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMono(
              size: 9,
              color: theme.secondaryInk,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(value, style: AppTypography.title(color: theme.ink)),
          const SizedBox(height: 4),
          Text(
            detail,
            style: AppTypography.labelMono(
              size: 10,
              color: theme.secondaryInk,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.theme,
    required this.onTap,
    this.emphasized = false,
    this.enabled = true,
  });

  final String label;
  final AppTheme theme;
  final VoidCallback onTap;
  final bool emphasized;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: emphasized ? theme.accent : theme.surface,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              border: Border.all(
                color: emphasized ? theme.accent : theme.divider,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.labelMono(
                color: emphasized ? AppColors.fixedDark : theme.ink,
                letterSpacing: 1.4,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
