import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class LmsDashboardScreen extends StatefulWidget {
  const LmsDashboardScreen({super.key});

  @override
  State<LmsDashboardScreen> createState() => _LmsDashboardScreenState();
}

class _LmsDashboardScreenState extends State<LmsDashboardScreen> {
  final Dio _dio = Dio();
  bool _isLoading = true;
  List<dynamic> _videos = [];
  Map<String, double> _downloadProgress = {};
  Map<String, String> _downloadStatus = {};
  Map<String, bool> _isDownloading = {};

  @override
  void initState() {
    super.initState();
    _fetchLmsData();
  }

  Future<void> _fetchLmsData() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final classId = user?.studentData?['classId'];
    if (classId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/api/lms/videos/class/$classId'));
      if (res.statusCode == 200) {
        setState(() {
          _videos = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("LMS Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startSmartDownload(String id, String url, String title) async {
    setState(() {
      _isDownloading[id] = true;
      _downloadProgress[id] = 0.0;
      _downloadStatus[id] = 'Starting...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      // Ensure safe filename
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filePath = '${dir.path}/$safeTitle.mp4';
      
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress[id] = received / total;
              _downloadStatus[id] = '${(received / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB';
            });
          }
        },
      );

      setState(() {
        _isDownloading[id] = false;
        _downloadStatus[id] = 'Complete. Saved offline.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title downloaded successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading[id] = false;
        _downloadStatus[id] = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LMS & Materials', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.school_rounded, size: 60, color: Colors.indigoAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Learning Materials',
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Access course videos and resources offline with our Smart Background Downloader.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Available Content',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_videos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('No materials uploaded for your class yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
              )
            else
              ..._videos.map((v) {
                final id = v['_id'];
                final isDownloading = _isDownloading[id] ?? false;
                final progress = _downloadProgress[id] ?? 0.0;
                final status = _downloadStatus[id] ?? 'Ready to download';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.video_library, color: Colors.redAccent),
                    ),
                    title: Text(v['title'] ?? 'Untitled', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(status, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                    ),
                    trailing: isDownloading
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(value: progress, color: Colors.deepPurple),
                              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.download_rounded, color: Colors.deepPurple, size: 28),
                            onPressed: () => _startSmartDownload(id, v['url'], v['title']),
                          ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
