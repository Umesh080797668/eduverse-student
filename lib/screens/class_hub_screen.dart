import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ClassHubScreen extends StatefulWidget {
  const ClassHubScreen({super.key});

  @override
  State<ClassHubScreen> createState() => _ClassHubScreenState();
}

class _ClassHubScreenState extends State<ClassHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _resources = [];
  bool _isLoading = true;
  String? _classId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user?.studentData == null || user!.studentData!['classId'] == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _classId = user.studentData!['classId'];
    try {
      final futures = await Future.wait([
        ApiService.getNotices(_classId!),
        ApiService.getResources(_classId!)
      ]);

      if (mounted) {
        setState(() {
          _notices = futures[0];
          _resources = futures[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading class hub data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Hub'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notices', icon: Icon(Icons.campaign)),
            Tab(text: 'Resources', icon: Icon(Icons.folder_shared)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classId == null
              ? const Center(child: Text('You are not assigned to a class.'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNoticesList(),
                    _buildResourcesList(),
                  ],
                ),
    );
  }

  Widget _buildNoticesList() {
    if (_notices.isEmpty) return const Center(child: Text('No notices posted.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        final date = DateTime.parse(notice['createdAt']);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notice['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    if (notice['priority'] == 'high')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                        child: const Text('IMPORTANT', style: TextStyle(color: Colors.red, fontSize: 10)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(notice['content']),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(date),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResourcesList() {
    if (_resources.isEmpty) return const Center(child: Text('No resources available.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _resources.length,
      itemBuilder: (context, index) {
        final res = _resources[index];
        final type = res['type'] ?? 'file';
        IconData icon;
        Color color;

        if (type == 'pdf') {
          icon = Icons.picture_as_pdf;
          color = Colors.red;
        } else if (type == 'image') {
          icon = Icons.image;
          color = Colors.purple;
        } else {
          icon = Icons.insert_drive_file;
          color = Colors.blue;
        }

        return Card(
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(res['title']),
            subtitle: Text(res['description'] ?? 'No description'),
            trailing: const Icon(Icons.download),
            onTap: () async {
              if (res['url'] != null) {
                final uri = Uri.parse(res['url']);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
                }
              }
            },
          ),
        );
      },
    );
  }
}
