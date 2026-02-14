import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/widgets/circular_usage_indicator.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = "";
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await _apiService.adminListUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editLimits(Map<String, dynamic> user) async {
    final storageController = TextEditingController(text: (user['max_storage_bytes'] ~/ (1024 * 1024)).toString());
    final runsController = TextEditingController(text: user['max_runs_count'].toString());
    String? storageError;
    String? runsError;

    final success = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Amend Quotas: ${user['email']}'),
            content: Container(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CURRENT ALLOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text('Storage: ${user['max_storage_bytes'] ~/ (1024 * 1024)} MB'),
                       Text('Runs: ${user['max_runs_count']}'),
                    ],
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: storageController,
                    decoration: InputDecoration(
                      labelText: 'New Storage Limit (MB)',
                      helperText: 'System Max: 5120 MB',
                      errorText: storageError,
                      border: const OutlineInputBorder(),
                      suffixText: 'MB',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      if (storageError != null) setDialogState(() => storageError = null);
                    },
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: runsController,
                    decoration: InputDecoration(
                      labelText: 'New AI Run Limit',
                      helperText: 'System Max: 1000 Runs',
                      errorText: runsError,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      if (runsError != null) setDialogState(() => runsError = null);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final storageMB = int.tryParse(storageController.text) ?? -1;
                  final newRuns = int.tryParse(runsController.text) ?? -1;
                  
                  final usedMB = (user['storage_used_bytes'] / (1024 * 1024)).ceil();
                  final usedRuns = user['runs_used_count'] as int;

                  bool hasError = false;
                  String? sErr;
                  String? rErr;

                  if (storageMB < 1 || storageMB > 5120) {
                    sErr = 'Storage must be 1 - 5120 MB';
                    hasError = true;
                  } else if (storageMB < usedMB) {
                    sErr = 'Min required: $usedMB MB (current usage)';
                    hasError = true;
                  }

                  if (newRuns < 1 || newRuns > 1000) {
                    rErr = 'Runs must be 1 - 1000';
                    hasError = true;
                  } else if (newRuns < usedRuns) {
                    rErr = 'Min required: $usedRuns (current usage)';
                    hasError = true;
                  }

                  if (hasError) {
                    setDialogState(() {
                      storageError = sErr;
                      runsError = rErr;
                    });
                  } else {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Confirm Changes'),
              ),
            ],
          );
        }
      ),
    );

    if (success == true) {
      try {
        final storageMB = int.parse(storageController.text);
        final newRuns = int.parse(runsController.text);
        final newStorage = storageMB * 1024 * 1024;
        
        await _apiService.adminUpdateLimits(
          user['email'], 
          maxStorage: newStorage, 
          maxRuns: newRuns
        );
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limits updated successfully')));
        _fetchUsers(); // Refresh list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) => 
      user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    ) 
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                : filteredUsers.isEmpty
                  ? const Center(child: Text('No users found matching search.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredUsers.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final storagePercent = (user['storage_used_bytes'] / user['max_storage_bytes']).clamp(0.0, 1.0);
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user['email'], 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _editLimits(user),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CircularUsageIndicator(
                                    label: "Storage",
                                    value: _formatBytes(user['storage_used_bytes']),
                                    total: _formatBytes(user['max_storage_bytes']),
                                    percent: storagePercent,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 24),
                                  CircularUsageIndicator(
                                    label: "AI Runs",
                                    value: "${user['runs_used_count']}",
                                    total: "${user['max_runs_count']}",
                                    percent: (user['max_runs_count'] > 0) 
                                      ? (user['runs_used_count'] / user['max_runs_count']).clamp(0.0, 1.0)
                                      : 0.0,
                                    size: 40,
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Joined: ${user['created_at'].split('T')[0]}', 
                                        style: const TextStyle(fontSize: 10, color: Colors.grey)
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (user['role'] == 'admin' ? Colors.red : Colors.grey).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          user['role'].toUpperCase(), 
                                          style: TextStyle(
                                            fontSize: 9, 
                                            fontWeight: FontWeight.bold,
                                            color: user['role'] == 'admin' ? Colors.red : Colors.grey
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
