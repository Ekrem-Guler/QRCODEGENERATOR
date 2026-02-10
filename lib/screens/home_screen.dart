import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService.instance;
  late TabController _tabController;
  
  // Controllers for each QR type
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsPhoneController = TextEditingController();
  final TextEditingController _smsMessageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailSubjectController = TextEditingController();
  final TextEditingController _emailBodyController = TextEditingController();
  
  String _wifiEncryption = 'WPA';
  bool _isLoading = false;
  String? _errorMessage;
  Uint8List? _qrImageBytes;
  String? _generatedContent;
  String? _currentType;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<_QRType> _qrTypes = [
    _QRType('URL', Icons.link_rounded, const Color(0xFF6366F1)),
    _QRType('Text', Icons.text_fields_rounded, const Color(0xFF10B981)),
    _QRType('WiFi', Icons.wifi_rounded, const Color(0xFFF59E0B)),
    _QRType('Phone', Icons.phone_rounded, const Color(0xFF3B82F6)),
    _QRType('SMS', Icons.sms_rounded, const Color(0xFF8B5CF6)),
    _QRType('Email', Icons.email_rounded, const Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _qrTypes.length, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _tabController.addListener(() {
      setState(() {
        _qrImageBytes = null;
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _textController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _phoneController.dispose();
    _smsPhoneController.dispose();
    _smsMessageController.dispose();
    _emailController.dispose();
    _emailSubjectController.dispose();
    _emailBodyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateQR() async {
    String type = '';
    Map<String, String> data = {};
    
    switch (_tabController.index) {
      case 0: // URL
        type = 'url';
        data = {'url': _urlController.text.trim()};
        break;
      case 1: // Text
        type = 'text';
        data = {'text': _textController.text.trim()};
        break;
      case 2: // WiFi
        type = 'wifi';
        data = {
          'ssid': _wifiSsidController.text.trim(),
          'password': _wifiPasswordController.text,
          'encryption': _wifiEncryption,
        };
        break;
      case 3: // Phone
        type = 'phone';
        data = {'phone': _phoneController.text.trim()};
        break;
      case 4: // SMS
        type = 'sms';
        data = {
          'phone': _smsPhoneController.text.trim(),
          'message': _smsMessageController.text,
        };
        break;
      case 5: // Email
        type = 'email';
        data = {
          'email': _emailController.text.trim(),
          'subject': _emailSubjectController.text,
          'body': _emailBodyController.text,
        };
        break;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.generateQR(type: type, data: data);
      
      if (result['success'] == true && result['qrCode'] != null) {
        final dataUrl = result['qrCode'] as String;
        final base64Data = dataUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        
        setState(() {
          _qrImageBytes = bytes;
          _generatedContent = result['content'] ?? '';
          _currentType = type;
          _isLoading = false;
        });
        
        _animationController.forward(from: 0);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _shareQR() async {
    if (_qrImageBytes == null) return;
    
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code.png');
      await file.writeAsBytes(_qrImageBytes!);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Sharing QR Code',
      );
      
      _saveToHistory(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadQR() async {
    if (_qrImageBytes == null) return;
    
    try {
      // Check for permission is handled by Gal automatically
      await Gal.putImageBytes(_qrImageBytes!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Gallery!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _saveToHistory(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to gallery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_generatedContent == null) return;
    
    await Clipboard.setData(ClipboardData(text: _generatedContent!));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content copied to clipboard!'),
          backgroundColor: Color(0xFF6366F1),
        ),
      );
    }
  }

  Future<void> _saveToHistory({bool silent = false}) async {
    if (_qrImageBytes == null || _generatedContent == null || _currentType == null) return;
    
    try {
      await _dbService.insertHistory(QRHistoryItem(
        type: _currentType!,
        content: _generatedContent!,
        imageBytes: _qrImageBytes!,
        createdAt: DateTime.now(),
      ));
      
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to history!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTabBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildInputForm(),
                      const SizedBox(height: 24),
                      _buildGenerateButton(),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) _buildErrorMessage(),
                      if (_qrImageBytes != null) _buildQRDisplay(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 28),
              tooltip: 'History',
            ),
            const SizedBox(width: 16),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _qrTypes[_tabController.index].color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.qr_code_2_rounded,
            size: 48,
            color: _qrTypes[_tabController.index].color,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'QR Generator',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _qrTypes[_tabController.index].color,
        ),
        tabs: _qrTypes.map((type) => Tab(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.icon, size: 18),
                const SizedBox(width: 6),
                Text(type.name, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        )).toList(),
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildInputForm() {
    switch (_tabController.index) {
      case 0:
        return _buildTextField(_urlController, 'Enter URL', Icons.link_rounded, TextInputType.url);
      case 1:
        return _buildTextField(_textController, 'Enter text', Icons.text_fields_rounded, TextInputType.multiline, maxLines: 3);
      case 2:
        return _buildWifiForm();
      case 3:
        return _buildTextField(_phoneController, 'Phone number', Icons.phone_rounded, TextInputType.phone);
      case 4:
        return _buildSmsForm();
      case 5:
        return _buildEmailForm();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, TextInputType keyboardType, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.6)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _qrTypes[_tabController.index].color, width: 2),
          ),
        ),
        keyboardType: keyboardType,
        onSubmitted: (_) => _generateQR(),
      ),
    );
  }

  Widget _buildWifiForm() {
    return Column(
      children: [
        _buildTextField(_wifiSsidController, 'Network Name (SSID)', Icons.wifi_rounded, TextInputType.text),
        const SizedBox(height: 16),
        _buildTextField(_wifiPasswordController, 'Password (optional)', Icons.lock_rounded, TextInputType.visiblePassword),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _wifiEncryption,
              isExpanded: true,
              dropdownColor: const Color(0xFF1a1a2e),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(value: 'nopass', child: Text('No Password')),
              ],
              onChanged: (value) => setState(() => _wifiEncryption = value!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmsForm() {
    return Column(
      children: [
        _buildTextField(_smsPhoneController, 'Phone number', Icons.phone_rounded, TextInputType.phone),
        const SizedBox(height: 16),
        _buildTextField(_smsMessageController, 'Message (optional)', Icons.message_rounded, TextInputType.multiline, maxLines: 2),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        _buildTextField(_emailController, 'Email address', Icons.email_rounded, TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildTextField(_emailSubjectController, 'Subject (optional)', Icons.subject_rounded, TextInputType.text),
        const SizedBox(height: 16),
        _buildTextField(_emailBodyController, 'Body (optional)', Icons.text_snippet_rounded, TextInputType.multiline, maxLines: 2),
      ],
    );
  }

  Widget _buildGenerateButton() {
    final color = _qrTypes[_tabController.index].color;
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _generateQR,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Generate ${_qrTypes[_tabController.index].name} QR',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildQRDisplay() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _qrTypes[_tabController.index].color.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_qrImageBytes!, width: 250, height: 250, fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _generatedContent ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_qrTypes[_tabController.index].icon, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${_qrTypes[_tabController.index].name} QR Code',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: const Color(0xFF6366F1),
                  onPressed: _shareQR,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  color: const Color(0xFF10B981),
                  onPressed: _downloadQR,
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _QRType {
  final String name;
  final IconData icon;
  final Color color;
  
  _QRType(this.name, this.icon, this.color);
}
