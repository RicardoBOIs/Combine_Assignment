// add_event_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'community_main_model.dart';
import 'community_repository_service.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({Key? key}) : super(key: key);

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  // ─── controllers & keys ──────────────────────────────────────────────────
  final _formKey            = GlobalKey<FormState>();
  final _titleC             = TextEditingController();
  final _shortDescC         = TextEditingController();
  final _descC              = TextEditingController();
  final _locationC          = TextEditingController();
  final _capacityC          = TextEditingController();
  final _termsC             = TextEditingController();
  final _scrollController   = ScrollController();

  // ─── state ───────────────────────────────────────────────────────────────
  String?  _eventType;
  bool     _existLeaderboard = false;
  String?  _leaderboardType;
  String?  _selectedHabit;                 // only "Step Counter"
  DateTime? _startDate;
  DateTime? _endDate;
  XFile?    _pickedImage;
  bool      _saving = false;

  // ─── constants ───────────────────────────────────────────────────────────
  static const _eventTypes = [
    'Workshop', 'Seminar', 'Meetup', 'Competition', 'Other'
  ];
  static const _leaderboardTypes = [
    'Manually Input Score', 'Auto Input Score'
  ];

  // ─── theme constants ───────────────────────────────────────────────────────
  late final _primaryGreen = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF4CAF50)
      : const Color(0xFF2E7D32);
  late final _lightGreen = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF81C784)
      : const Color(0xFFA5D6A7);
  late final _accentGreen = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF00C853)
      : const Color(0xFF00C853);

  final _picker = ImagePicker();
  final _repo   = RepositoryService.instance;

  // ─── helpers ─────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? DateTime.now() : (_startDate ?? DateTime.now());
    final picked  = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate : DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    // Scroll to top to show progress
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    // ── validation ────────────────────────────────────────────────────────
    if (_existLeaderboard && _leaderboardType == null) {
      _snack('Please select a leaderboard type.'); return;
    }
    if (_existLeaderboard &&
        _leaderboardType == 'Auto Input Score' &&
        _selectedHabit == null) {
      _snack('Please select a habit title.'); return;
    }
    if (!_formKey.currentState!.validate() ||
        _startDate == null || _endDate == null) {
      _snack('Please complete all required fields.'); return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    var comm = CommunityMain(
      title              : _titleC.text.trim(),
      typeOfEvent        : _eventType ?? 'Other',
      shortDescription   : _shortDescC.text.trim(),
      description        : _descC.text.trim(),
      startDate          : _startDate!,
      endDate            : _endDate!,
      location           : _locationC.text.trim(),
      capacity           : int.tryParse(_capacityC.text) ?? 0,
      termsAndConditions : _termsC.text.trim(),
      imagePath          : _pickedImage?.path,
      existLeaderboard   : _existLeaderboard ? 'Yes' : 'No',
      typeOfLeaderboard  : _existLeaderboard ? _leaderboardType : null,
      selectedHabitTitle : _existLeaderboard &&
          _leaderboardType == 'Auto Input Score'
          ? _selectedHabit
          : null,
      createdAt          : now,
      updatedAt          : now,
    );

    try {
      // 1) save locally to get an auto-id
      final newId = await _repo.insertCommunity(comm);
      comm = comm.copyWith(id: newId);

      // 2) push to Firestore (repo handles offline gracefully)
      await _repo.saveCommunity(comm);

      if (context.mounted) {
        _snack('Event saved successfully!', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) _snack('Error saving: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool success = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: success ? _accentGreen : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  // ─── UI ──────────────────────────────────────────────────────────────────
  Widget _imagePicker() => GestureDetector(
    onTap: _pickImage,
    child: Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pickedImage == null ? _lightGreen : Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _pickedImage == null
          ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _lightGreen.withOpacity(0.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 64, color: _primaryGreen),
            const SizedBox(height: 12),
            Text(
              'Add Event Image',
              style: TextStyle(
                color: _primaryGreen,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Tap to change image',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: _primaryGreen),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: _lightGreen),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryGreen),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightGreen),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _lightGreen),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryGreen, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      filled: true,
      fillColor: _lightGreen.withOpacity(0.05),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Community Event'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Green gradient background at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_primaryGreen, _lightGreen.withOpacity(0.0)],
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _imagePicker(),

                  _buildSectionTitle('Basic Information', Icons.info_outline),

                  // ── Title ────────────────────────────────────────────────
                  TextFormField(
                    controller: _titleC,
                    decoration: _inputDecoration(
                      label: 'Event Title*',
                      icon: Icons.title,
                      hint: 'Enter a descriptive title',
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Event type ──────────────────────────────────────────
                  DropdownButtonFormField<String>(
                    value: _eventType,
                    decoration: _inputDecoration(
                      label: 'Type of Event*',
                      icon: Icons.category,
                    ),
                    items: _eventTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _eventType = v),
                    validator: (v) => v == null ? 'Select event type' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Short desc ──────────────────────────────────────────
                  TextFormField(
                    controller: _shortDescC,
                    maxLength : 80,
                    decoration: _inputDecoration(
                      label: 'Brief Description*',
                      icon: Icons.short_text,
                      hint: 'A short tagline for your event',
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter a brief description' : null,
                  ),

                  _buildSectionTitle('Event Details', Icons.event_note),

                  // ── Full desc ───────────────────────────────────────────
                  TextFormField(
                    controller: _descC,
                    maxLines  : 4,
                    decoration: _inputDecoration(
                      label: 'Full Description*',
                      icon: Icons.description,
                      hint: 'Describe your event in detail',
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Dates ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: _lightGreen),
                              borderRadius: BorderRadius.circular(12),
                              color: _lightGreen.withOpacity(0.05),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: _primaryGreen),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date*',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _startDate == null
                                            ? 'Select date'
                                            : fmt.format(_startDate!),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: _startDate == null ? Colors.grey : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: _lightGreen),
                              borderRadius: BorderRadius.circular(12),
                              color: _lightGreen.withOpacity(0.05),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: _primaryGreen),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date*',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _endDate == null
                                            ? 'Select date'
                                            : fmt.format(_endDate!),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: _endDate == null ? Colors.grey : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_startDate == null || _endDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child : Text('Both dates are required',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 16),

                  // ── Location ────────────────────────────────────────────
                  TextFormField(
                    controller: _locationC,
                    decoration: _inputDecoration(
                      label: 'Location*',
                      icon: Icons.location_on,
                      hint: 'Where will this event take place?',
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter location' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Capacity ────────────────────────────────────────────
                  TextFormField(
                    controller: _capacityC,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      label: 'Capacity*',
                      icon: Icons.people,
                      hint: 'Maximum number of participants',
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Enter capacity';
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) return 'Enter a positive number';
                      return null;
                    },
                  ),

                  _buildSectionTitle('Terms & Conditions', Icons.gavel),

                  // ── Terms ───────────────────────────────────────────────
                  TextFormField(
                    controller: _termsC,
                    maxLines  : 3,
                    decoration: _inputDecoration(
                      label: 'Terms & Conditions*',
                      icon: Icons.rule,
                      hint: 'Rules and guidelines for participants',
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter T&C' : null,
                  ),

                  _buildSectionTitle('Leaderboard Settings', Icons.leaderboard),

                  // ── Leaderboard switch ─────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _lightGreen.withOpacity(0.1),
                      border: Border.all(
                        color: _existLeaderboard ? _primaryGreen : _lightGreen,
                        width: _existLeaderboard ? 2 : 1,
                      ),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Enable Leaderboard',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _existLeaderboard ? _primaryGreen : null,
                        ),
                      ),
                      subtitle: const Text(
                        'Track participant progress and display rankings',
                      ),
                      value: _existLeaderboard,
                      activeColor: Colors.white,
                      activeTrackColor: _accentGreen,
                      secondary: Icon(
                        Icons.leaderboard,
                        color: _existLeaderboard ? _primaryGreen : Colors.grey.shade600,
                      ),
                      onChanged: (v) => setState(() {
                        _existLeaderboard = v;
                        if (!v) {
                          _leaderboardType = null;
                          _selectedHabit = null;
                        }
                      }),
                    ),
                  ),

                  // ── Leaderboard details ────────────────────────────────
                  if (_existLeaderboard) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _leaderboardType,
                      decoration: _inputDecoration(
                        label: 'Leaderboard Type*',
                        icon: Icons.category,
                      ),
                      items: _leaderboardTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _leaderboardType = v;
                        if (v != 'Auto Input Score') _selectedHabit = null;
                      }),
                      validator: (v) =>
                      v == null ? 'Select leaderboard type' : null,
                    ),
                  ],
                  if (_existLeaderboard &&
                      _leaderboardType == 'Auto Input Score') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value      : _selectedHabit,
                      items      : const [
                        DropdownMenuItem(
                            value: 'Step Counter', child: Text('Step Counter'))
                      ],
                      decoration : _inputDecoration(
                        label: 'Habit Title*',
                        icon: Icons.fitness_center,
                      ),
                      onChanged  : (h) => setState(() => _selectedHabit = h),
                      validator  : (v) =>
                      v == null ? 'Select habit title' : null,
                    ),
                  ],
                  const SizedBox(height: 36),

                  // ── Save button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white
                          )
                      )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _saving ? 'SAVING EVENT...' : 'CREATE EVENT',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _primaryGreen),
                      const SizedBox(height: 24),
                      const Text(
                        'Creating your event...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleC.dispose();
    _shortDescC.dispose();
    _descC.dispose();
    _locationC.dispose();
    _capacityC.dispose();
    _termsC.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}