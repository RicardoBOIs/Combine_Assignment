// edit_event_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'community_repository_service.dart';
import 'community_main_model.dart';

/// Admin page to edit or delete an existing event
class EditEventPage extends StatefulWidget {
  final CommunityMain event;
  const EditEventPage({Key? key, required this.event}) : super(key: key);

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
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
            primary: Colors.green,
            onPrimary: Colors.white,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a leaderboard type.'))
      );
      return;
    }
    if (_existLeaderboard &&
        _leaderboardType == 'Auto Input Score' &&
        _selectedHabit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a habit title.'))
      );
      return;
    }
    if (!_formKey.currentState!.validate() ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all required fields.'))
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully!'))
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating event: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }



  Widget _buildImagePicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
            color: Colors.grey.shade100,
          ),
          child: _pickedImage == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate,
                    size: 48, color: Colors.grey.shade700),
                const SizedBox(height: 8),
                Text('Tap to select image',
                    style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          )
              : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_pickedImage!.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      if (_pickedImage != null)
        TextButton.icon(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Remove Image',
              style: TextStyle(color: Colors.red)),
          onPressed: () => setState(() => _pickedImage = null),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit "${widget.event.title}"'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveChanges,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title*',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _eventType,
                    decoration: const InputDecoration(
                      labelText: 'Type of Event*',
                      prefixIcon: Icon(Icons.event),
                      border: OutlineInputBorder(),
                    ),
                    items: _eventTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _eventType = v),
                    validator: (v) => v == null ? 'Select event type' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shortDescController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Brief Description*',
                      prefixIcon: Icon(Icons.short_text),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty
                        ? 'Enter a brief description'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Full Description*',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_startDate == null
                              ? 'Start Date*'
                              : fmt.format(_startDate!)),
                          onPressed: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_endDate == null
                              ? 'End Date*'
                              : fmt.format(_endDate!)),
                          onPressed: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  if (_startDate == null || _endDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Start and End dates are required.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location*',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Enter location' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity*',
                      prefixIcon: Icon(Icons.people),
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Terms & Conditions*',
                      prefixIcon: Icon(Icons.rule),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter terms & conditions' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Leaderboard'),
                    value: _existLeaderboard,
                    onChanged: (v) => setState(() {
                      _existLeaderboard = v;
                      if (!v) {
                        _leaderboardType = null;
                        _selectedHabit = null;
                      }
                    }),
                    secondary: const Icon(Icons.leaderboard),
                    activeColor: Colors.green,
                  ),
                  if (_existLeaderboard) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _leaderboardType,
                      decoration: const InputDecoration(
                        labelText: 'Leaderboard Type*',
                        prefixIcon: Icon(Icons.assessment_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _leaderboardTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _leaderboardType = v;
                        if (v != 'Auto Input Score') _selectedHabit = null;
                      }),
                      validator: (v) => v == null ? 'Select leaderboard type' : null,
                    ),
                  ],
                  if (_existLeaderboard && _leaderboardType == 'Auto Input Score') ...[
                    const SizedBox(height: 16),
                    FutureBuilder<List<String>>(
                      future: _repo.getHabitTitles(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final habits = snap.data!;
                        return DropdownButtonFormField<String>(
                          value: _selectedHabit,
                          decoration: const InputDecoration(
                            labelText: 'Habit to Auto-Track*',
                            prefixIcon: Icon(Icons.fitness_center),
                            border: OutlineInputBorder(),
                          ),
                          items: habits
                              .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                              .toList(),
                          onChanged: (h) => setState(() => _selectedHabit = h),
                          validator: (v) => v == null ? 'Select a habit' : null,
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
