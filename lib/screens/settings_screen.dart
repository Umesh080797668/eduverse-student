import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = '1.0.0';
  bool _checkingUpdate = false;
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = packageInfo.version;
      });
    } catch (e) {
      debugPrint('Error loading version info: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      // Clear cache to ensure fresh data
      await _updateService.clearUpdateCache();
      debugPrint('Update cache cleared before checking for updates');

      // Check for updates
      final updateInfo = await _updateService.checkForUpdates(showNotification: false);

      if (!mounted) return;

      if (updateInfo != null) {
        // Show update available dialog
        _showUpdateAvailableDialog(updateInfo);
      } else {
        // Show already up-to-date message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('You are using the latest version'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  void _showUpdateAvailableDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.system_update_alt,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Update Available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${updateInfo.version} is now available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'What\'s New:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                updateInfo.releaseNotes,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstallUpdate(updateInfo);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstallUpdate(UpdateInfo updateInfo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        updateInfo: updateInfo,
        updateService: _updateService,
      ),
    );
  }

  void _showReportProblemDialog() {
    final TextEditingController issueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.report_problem_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Report a Problem',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please describe the issue you\'re experiencing:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: issueController,
                maxLines: 4,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe the problem in detail...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (issueController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please describe the issue'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              final auth = Provider.of<AuthProvider>(context, listen: false);
              final userEmail = auth.currentUser?.email;

              if (userEmail == null || userEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('User email not found. Please log in again.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              
              // Send report to API
              try {
                await ApiService.submitProblemReport(
                  userEmail: userEmail,
                  issueDescription: issueController.text.trim(),
                  appVersion: _currentVersion,
                  device: Theme.of(context).platform == TargetPlatform.android 
                      ? 'Android' 
                      : Theme.of(context).platform == TargetPlatform.iOS 
                      ? 'iOS' 
                      : 'Unknown',
                  studentId: auth.currentUser?.studentId,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Problem report submitted successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit problem report: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Send Report'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Privacy Policy',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Privacy Matters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildPrivacySection(
                'Data Collection',
                'We collect only essential information needed to provide our services, including '
                    'your name, email, and attendance records. We do not collect unnecessary personal data.',
              ),
              _buildPrivacySection(
                'Data Usage',
                'Your data is used solely for attendance tracking and reporting purposes. '
                    'We do not sell or share your information with third parties without your explicit consent.',
              ),
              _buildPrivacySection(
                'Data Security',
                'We implement industry-standard security measures to protect your data, including '
                    'encryption, secure authentication, and regular security audits.',
              ),
              _buildPrivacySection(
                'Data Retention',
                'Your data is stored as long as your account is active. You can request data deletion '
                    'at any time by contacting our support team.',
              ),
              _buildPrivacySection(
                'Your Rights',
                'You have the right to access, modify, or delete your personal data. You can export '
                    'your data at any time using the export feature in settings.',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Last Updated: January 2026',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeatureRequestDialog() {
    final TextEditingController featureController = TextEditingController();
    final TextEditingController bidPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Request a Feature',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Describe the feature you would like:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: featureController,
                maxLines: 4,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe the feature in detail...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bid Price (LKR):',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bidPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount you\'re willing to pay',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  prefixText: 'LKR ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The bid price helps prioritize feature development.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (featureController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please describe the feature'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              if (bidPriceController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a bid price'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              final bidPrice = double.tryParse(bidPriceController.text.trim());
              if (bidPrice == null || bidPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              final auth = Provider.of<AuthProvider>(context, listen: false);
              final userEmail = auth.currentUser?.email;

              if (userEmail == null || userEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('User email not found. Please log in again.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              
              // Send feature request to API
              try {
                await ApiService.submitFeatureRequest(
                  userEmail: userEmail,
                  featureDescription: featureController.text.trim(),
                  bidPrice: bidPrice,
                  appVersion: _currentVersion,
                  device: Theme.of(context).platform == TargetPlatform.android 
                      ? 'Android' 
                      : Theme.of(context).platform == TargetPlatform.iOS 
                      ? 'iOS' 
                      : 'Unknown',
                  studentId: auth.currentUser?.studentId,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Feature request submitted successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit feature request: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Terms and Conditions',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Agreement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _buildTermsSection(
                '1. Service Description',
                'This application provides student attendance tracking and payment management services. '
                    'The service is provided "as is" and we reserve the right to modify it at any time.',
              ),
              _buildTermsSection(
                '2. User Responsibilities',
                'You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account. '
                    'You agree to use this service only for its intended purpose.',
              ),
              _buildTermsSection(
                '3. Acceptable Use',
                'You agree not to use this application for any illegal or unauthorized purposes. '
                    'You must comply with all applicable laws and regulations.',
              ),
              _buildTermsSection(
                '4. Limitation of Liability',
                'We are not liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the service.',
              ),
              _buildTermsSection(
                '5. Changes to Terms',
                'We may update these terms at any time. Your continued use of the application constitutes acceptance of the updated terms.',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Last Updated: January 2026',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark theme'),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme(value);
            },
          ),

          const Divider(),

          // Support Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Support',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined),
            title: const Text('Report a Problem'),
            subtitle: const Text('Report issues or bugs'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showReportProblemDialog,
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Request a Feature'),
            subtitle: const Text('Suggest new features'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showFeatureRequestDialog,
          ),

          const Divider(),

          // About Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: Text(_currentVersion),
            trailing: const Icon(Icons.info_outline),
          ),
          ListTile(
            leading: _checkingUpdate
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : const Icon(Icons.system_update_alt),
            title: const Text('Check for Updates'),
            subtitle: const Text('Download the latest version'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _checkingUpdate ? null : _checkForUpdates,
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showPrivacyPolicy,
          ),
          ListTile(
            title: const Text('Terms and Conditions'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showTermsAndConditions,
          ),
        ],
      ),
    );
  }
}

// Download Progress Dialog Widget
class _DownloadProgressDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final UpdateService updateService;

  const _DownloadProgressDialog({
    required this.updateInfo,
    required this.updateService,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _statusMessage = 'Preparing download...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await widget.updateService.downloadAndInstallUpdate(
        widget.updateInfo.downloadUrl,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              if (progress < 0.01) {
                _statusMessage = 'Starting download...';
              } else if (progress < 1.0) {
                _statusMessage = 'Downloading... ${(progress * 100).toStringAsFixed(0)}%';
              } else {
                _statusMessage = 'Download complete. Installing...';
              }
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(
        'Downloading Update',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: _hasError
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ]
          : null,
    );
  }
}
