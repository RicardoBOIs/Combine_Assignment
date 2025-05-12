import 'package:flutter/material.dart';

import 'package:assignment_test/YenHan/tip_repository.dart';
import 'tips_education.dart';
// Define theme colors for consistency
const Color primaryGreen = Color(0xFF4CAF50);
const Color accentGreen = Color(0xFF8BC34A);
const Color lightGreen = Color(0xFFDCEDC8);
const Color darkGreen = Color(0xFF2E7D32);
const Color textColor = Color(0xFF333333);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load tips from Firestore when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTips();
    });
  }

  // Refresh tips from Firestore
  Future<void> _refreshTips() async {
    setState(() {
      _isLoading = true;
    });

    await TipRepository.instance.initFromFirestore();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showAddTipDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _title = TextEditingController();
    final _desc = TextEditingController();
    final _url = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Add New Tip',
          style: TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: const Icon(Icons.title, color: accentGreen),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _desc,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: const Icon(Icons.description, color: accentGreen),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Enter description' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _url,
                  decoration: InputDecoration(
                    labelText: 'Reference URL',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: const Icon(Icons.link, color: accentGreen),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter URL' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                setState(() {
                  _isLoading = true;
                });

                final tip = Tip(
                  title: _title.text.trim(),
                  subtitle: _desc.text.trim(),
                  reference: _url.text.trim(),
                );

                await TipRepository.instance.addTip(tip);

                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });

                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tip added successfully ✔'),
                    backgroundColor: darkGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTip(Tip tip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Tip', style: TextStyle(color: darkGreen)),
        content: Text('Are you sure you want to delete "${tip.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    bool success = await TipRepository.instance.deleteTip(tip.title);
    if (success) {
      TipRepository.instance.tips.remove(tip);
      await _refreshTips();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tip deleted successfully'
              : 'Failed to delete tip'),
          backgroundColor: success ? darkGreen : Colors.red,
        ),
      );
    }
  }


  Future<void> _showEditTipDialog(Tip tip) async {
    final _formKey = GlobalKey<FormState>();
    final _title = TextEditingController(text: tip.title);
    final _desc = TextEditingController(text: tip.subtitle);
    final _url = TextEditingController(text: tip.reference);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Edit Tip',
          style: TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: const Icon(Icons.title, color: accentGreen),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter title' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _desc,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: const Icon(Icons.description, color: accentGreen),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Enter description' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _url,
                  decoration: InputDecoration(
                    labelText: 'Reference URL',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: const Icon(Icons.link, color: accentGreen),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: primaryGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter URL' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                setState(() {
                  _isLoading = true;
                });

                // Update the tip properties
                final updatedTip = Tip(
                  title: _title.text.trim(),
                  subtitle: _desc.text.trim(),
                  reference: _url.text.trim(),
                );

                await TipRepository.instance.addTip(tip);


                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });

                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tip updated successfully ✔'),
                    backgroundColor: darkGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tips = TipRepository.instance.tips;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTips,
            tooltip: 'Refresh Tips',
          )

        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightGreen.withOpacity(0.5), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
          ),
        )
            : tips.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No tips available yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddTipDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Tip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _refreshTips,
          color: primaryGreen,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tips.length,
            itemBuilder: (_, i) => Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: accentGreen,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  tips[i].title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: darkGreen,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      tips[i].subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reference: ${tips[i].reference}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: accentGreen),
                      onPressed: () => _showEditTipDialog(tips[i]),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTip(tips[i]),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                onTap: () {
                  // Show detailed tip view
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        tips[i].title,
                        style: const TextStyle(
                          color: darkGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tips[i].subtitle,
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reference:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              tips[i].reference,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add New Tip'),
        onPressed: _showAddTipDialog,
        elevation: 4,
      ),
    );
  }
}