// edit_event_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'community_repository_service.dart';
import 'community_main_model.dart';

/// Admin page to edit or delete an existing event with enhanced visual styling
class EditEventPage extends StatefulWidget {
  final CommunityMain event;
  const EditEventPage({Key? key, required this.event}) : super(key: key);

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  // Color scheme constants
  final _primaryGreen = const Color(0xFF2E7D32); // Deeper green for primary elements
  final _accentGreen = const Color(0xFF66BB6A); // Lighter green for accents
  final _lightGreen = const Color(0xFFDCEDC8); // Very light green for backgrounds
  final _surfaceColor = const Color(0xFFF5F9F5); // Off-white with green tint

  final _repo = RepositoryService.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _shortDescController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _capacityController;
  late TextEditingController _termsController;

  String? _eventType;
  bool _existLeaderboard = false;
  String? _leaderboardType;
  String? _selectedHabit;

  DateTime? _startDate;
  DateTime? _endDate;
  XFile? _pickedImage;
  String? _initialImagePath;

  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  final List<String> _eventTypes = [
    'Workshop', 'Seminar', 'Meetup', 'Competition', 'Other'
  ];
  final List<String> _leaderboardTypes = [
    'Manually Input Score', 'Auto Input Score'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController     = TextEditingController(text: e.title);
    _shortDescController = TextEditingController(text: e.shortDescription);
    _descController      = TextEditingController(text: e.description);
    _locationController  = TextEditingController(text: e.location);
    _capacityController  = TextEditingController(text: e.capacity.toString());
    _termsController     = TextEditingController(text: e.termsAndConditions);

    _eventType        = e.typeOfEvent;
    _existLeaderboard = e.existLeaderboard == 'Yes';
    _leaderboardType  = e.typeOfLeaderboard;
    _selectedHabit    = e.selectedHabitTitle;

    _startDate = e.startDate;
    _endDate   = e.endDate;

    if (e.imagePath != null && e.imagePath!.isNotEmpty) {
      _pickedImage      = XFile(e.imagePath!);
      _initialImagePath = e.imagePath;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);
    final first = isStart
        ? DateTime(now.year - 5)
        : (_startDate ?? DateTime(now.year - 5));

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: _primaryGreen,
            onPrimary: Colors.white,
            secondary: _accentGreen,
            surface: _surfaceColor,
          ),
          dialogBackgroundColor: _surfaceColor,
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate != null && _endDate!.isBefore(date)) {
            _endDate = date;
          }
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_existLeaderboard && _leaderboardType == null) {
      _showSnackBar('Please select a leaderboard type.');
      return;
    }
    if (_existLeaderboard &&
        _leaderboardType == 'Auto Input Score' &&
        _selectedHabit == null) {
      _showSnackBar('Please select a habit title.');
      return;
    }
    if (!_formKey.currentState!.validate() ||
        _startDate == null ||
        _endDate == null) {
      _showSnackBar('Please complete all required fields.');
      return;
    }

    setState(() => _isSaving = true);

    // determine final image path
    String? finalImagePath = _initialImagePath;
    if (_pickedImage != null) {
      finalImagePath = (_pickedImage!.path != _initialImagePath)
          ? _pickedImage!.path
          : _initialImagePath;
    } else {
      finalImagePath = null;
    }

    final updated = CommunityMain(
      id: widget.event.id,
      title: _titleController.text.trim(),
      typeOfEvent: _eventType ?? 'Other',
      shortDescription: _shortDescController.text.trim(),
      description: _descController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      location: _locationController.text.trim(),
      capacity: int.tryParse(_capacityController.text.trim()) ?? 0,
      termsAndConditions: _termsController.text.trim(),
      imagePath: finalImagePath,
      existLeaderboard: _existLeaderboard ? 'Yes' : 'No',
      typeOfLeaderboard:
      _existLeaderboard ? _leaderboardType : null,
      selectedHabitTitle:
      (_existLeaderboard && _leaderboardType == 'Auto Input Score')
          ? _selectedHabit
          : null,
      createdAt: widget.event.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await _repo.saveCommunity(updated);
      if (mounted) {
        _showSnackBar('Event updated successfully!', isSuccess: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating event: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess ? _primaryGreen : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        )
    );
  }

  Widget _buildImagePicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accentGreen, width: 2),
            color: _lightGreen,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _pickedImage == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate,
                    size: 64, color: _primaryGreen.withOpacity(0.7)),
                const SizedBox(height: 12),
                Text(
                  'Tap to select event image',
                  style: TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommended: landscape orientation',
                  style: TextStyle(
                    color: _primaryGreen.withOpacity(0.7),
                    fontSize: 12,
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
                Image.file(
                  File(_pickedImage!.path),
                  fit: BoxFit.cover,
                ),
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
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
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
      ),
      if (_pickedImage != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Remove Image',
                style: TextStyle(color: Colors.redAccent)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.redAccent, width: 0.5),
              ),
              backgroundColor: Colors.red.withOpacity(0.08),
            ),
            onPressed: () => setState(() => _pickedImage = null),
          ),
        ),
    ],
  );

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primaryGreen),
      labelStyle: TextStyle(color: _primaryGreen),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentGreen),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentGreen.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryGreen, width: 2),
      ),
      filled: true,
      fillColor: _surfaceColor,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: _primaryGreen,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required bool isStart,
    required VoidCallback onTap,
  }) {
    final date = isStart ? _startDate : _endDate;
    final formatter = DateFormat('MMM d, yyyy');

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: date == null
                  ? Colors.red.withOpacity(0.5)
                  : _accentGreen.withOpacity(0.5),
            ),
            color: date == null
                ? Colors.red.withOpacity(0.05)
                : _surfaceColor,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: date == null ? Colors.redAccent : _primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  date == null
                      ? isStart ? 'Start Date*' : 'End Date*'
                      : formatter.format(date),
                  style: TextStyle(
                    color: date == null
                        ? Colors.grey.shade700
                        : Colors.black87,
                    fontWeight: date == null ? FontWeight.normal : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Event',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: _primaryGreen,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isSaving
                ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
                : IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
              iconSize: 28,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: 16,
            color: _primaryGreen,
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Event Image'),
                      const SizedBox(height: 8),
                      _buildImagePicker(),

                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration(
                          label: 'Event Title*',
                          icon: Icons.title,
                          hint: 'Enter an engaging title',
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Enter a title' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _eventType,
                        decoration: _inputDecoration(
                          label: 'Type of Event*',
                          icon: Icons.event,
                        ),
                        items: _eventTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setState(() => _eventType = v),
                        validator: (v) => v == null ? 'Select event type' : null,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: _primaryGreen),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _shortDescController,
                        maxLength: 80,
                        decoration: _inputDecoration(
                          label: 'Brief Description*',
                          icon: Icons.short_text,
                          hint: 'Summarize your event (max 80 chars)',
                        ),
                        validator: (v) => v!.trim().isEmpty
                            ? 'Enter a brief description'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          label: 'Full Description*',
                          icon: Icons.description,
                          hint: 'Provide complete event details',
                        ),
                        validator: (v) =>
                        v!.trim().isEmpty ? 'Enter description' : null,
                      ),

                      _buildSectionHeader('Event Schedule'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDateButton(
                            isStart: true,
                            onTap: () => _pickDate(isStart: true),
                          ),
                          const SizedBox(width: 12),
                          _buildDateButton(
                            isStart: false,
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ],
                      ),
                      if (_startDate == null || _endDate == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            'Both start and end dates are required',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      _buildSectionHeader('Event Details'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: _inputDecoration(
                          label: 'Location*',
                          icon: Icons.location_on,
                          hint: 'Physical address or online link',
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Enter location' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'Capacity*',
                          icon: Icons.people,
                          hint: 'Maximum number of participants',
                        ),
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Enter capacity';
                          if (int.tryParse(v) == null) return 'Must be a valid number';
                          if (int.parse(v) <= 0) return 'Capacity must be positive';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _termsController,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          label: 'Terms & Conditions*',
                          icon: Icons.rule,
                          hint: 'Rules and conditions for participation',
                        ),
                        validator: (v) =>
                        v!.trim().isEmpty ? 'Enter terms & conditions' : null,
                      ),

                      _buildSectionHeader('Leaderboard Settings'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accentGreen.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: Text('Enable Leaderboard',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _primaryGreen,
                                ),
                              ),
                              subtitle: const Text(
                                'Track participants\' performance with rankings',
                                style: TextStyle(fontSize: 12),
                              ),
                              value: _existLeaderboard,
                              onChanged: (v) => setState(() {
                                _existLeaderboard = v;
                                if (!v) {
                                  _leaderboardType = null;
                                  _selectedHabit = null;
                                }
                              }),
                              secondary: Icon(Icons.leaderboard, color: _primaryGreen),
                              activeColor: _primaryGreen,
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (_existLeaderboard) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _leaderboardType,
                                decoration: _inputDecoration(
                                  label: 'Leaderboard Type*',
                                  icon: Icons.assessment_outlined,
                                ),
                                items: _leaderboardTypes
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _leaderboardType = v;
                                  if (v != 'Auto Input Score') _selectedHabit = null;
                                }),
                                validator: (v) => v == null ? 'Select leaderboard type' : null,
                                dropdownColor: Colors.white,
                                icon: Icon(Icons.arrow_drop_down, color: _primaryGreen),
                              ),
                            ],
                            if (_existLeaderboard && _leaderboardType == 'Auto Input Score') ...[
                              const SizedBox(height: 16),
                              FutureBuilder<List<String>>(
                                future: _repo.getHabitTitles(),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation(_primaryGreen),
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    );
                                  }
                                  final habits = snap.data!;
                                  return DropdownButtonFormField<String>(
                                    value: _selectedHabit,
                                    decoration: _inputDecoration(
                                      label: 'Habit to Auto-Track*',
                                      icon: Icons.fitness_center,
                                    ),
                                    items: habits
                                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                                        .toList(),
                                    onChanged: (h) => setState(() => _selectedHabit = h),
                                    validator: (v) => v == null ? 'Select a habit' : null,
                                    dropdownColor: Colors.white,
                                    icon: Icon(Icons.arrow_drop_down, color: _primaryGreen),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSaving)
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
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(_primaryGreen),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saving changes...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: !_isSaving ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded),
                SizedBox(width: 8),
                Text(
                  'SAVE CHANGES',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ) : null,
    );
  }
}