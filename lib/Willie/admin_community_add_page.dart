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

  // ─── state ───────────────────────────────────────────────────────────────
  String?  _eventType;
  bool     _existLeaderboard = false;
  String?  _leaderboardType;
  String?  _selectedHabit;                 // only “Step Counter”
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
        SnackBar(content: Text(msg),
            backgroundColor: success ? Colors.green : null),
      );

  // ─── UI ──────────────────────────────────────────────────────────────────
  Widget _imagePicker() => GestureDetector(
    onTap: _pickImage,
    child: Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
        color : Colors.grey.shade100,
      ),
      child: _pickedImage == null
          ? const Center(child: Icon(Icons.add_photo_alternate,size: 48))
          : ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Community Event'),
        backgroundColor: Colors.green,
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
                  _imagePicker(),
                  const SizedBox(height: 20),

                  // ── Title ────────────────────────────────────────────────
                  TextFormField(
                    controller: _titleC,
                    decoration: const InputDecoration(
                      labelText: 'Event Title*',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Event type ──────────────────────────────────────────
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

                  // ── Short desc ──────────────────────────────────────────
                  TextFormField(
                    controller: _shortDescC,
                    maxLength : 80,
                    decoration: const InputDecoration(
                      labelText: 'Brief Description*',
                      prefixIcon: Icon(Icons.short_text),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter a brief description' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Full desc ───────────────────────────────────────────
                  TextFormField(
                    controller: _descC,
                    maxLines  : 4,
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

                  // ── Dates ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon : const Icon(Icons.calendar_today),
                          label: Text(_startDate == null
                              ? 'Start Date*'
                              : fmt.format(_startDate!)),
                          onPressed: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon : const Icon(Icons.calendar_today),
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
                      padding: const EdgeInsets.only(top: 8),
                      child : Text('Start and End dates are required.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 16),

                  // ── Location ────────────────────────────────────────────
                  TextFormField(
                    controller: _locationC,
                    decoration: const InputDecoration(
                      labelText: 'Location*',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter location' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Capacity ────────────────────────────────────────────
                  TextFormField(
                    controller: _capacityC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Capacity*',
                      prefixIcon: Icon(Icons.people),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Enter capacity';
                      final n = int.tryParse(v);
                      if (n == null || n <= 0) return 'Enter a positive number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Terms ───────────────────────────────────────────────
                  TextFormField(
                    controller: _termsC,
                    maxLines  : 2,
                    decoration: const InputDecoration(
                      labelText: 'Terms & Conditions*',
                      prefixIcon: Icon(Icons.rule),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Enter T&C' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Leaderboard switch ─────────────────────────────────
                  SwitchListTile(
                    title : const Text('Enable Leaderboard'),
                    value : _existLeaderboard,
                    activeColor: Colors.green,
                    secondary: const Icon(Icons.leaderboard),
                    onChanged: (v) => setState(() {
                      _existLeaderboard = v;
                      if (!v) {
                        _leaderboardType = null;
                        _selectedHabit  = null;
                      }
                    }),
                  ),

                  // ── Leaderboard details ────────────────────────────────
                  if (_existLeaderboard) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _leaderboardType,
                      decoration: const InputDecoration(
                        labelText: 'Leaderboard Type*',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _leaderboardTypes
                          .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
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
                      decoration : const InputDecoration(
                        labelText: 'Habit Title*',
                        prefixIcon: Icon(Icons.fitness_center),
                        border: OutlineInputBorder(),
                      ),
                      onChanged  : (h) => setState(() => _selectedHabit = h),
                      validator  : (v) =>
                      v == null ? 'Select habit title' : null,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Save button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon : _saving
                          ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'SAVING…' : 'SAVE EVENT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
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
    super.dispose();
  }
}
