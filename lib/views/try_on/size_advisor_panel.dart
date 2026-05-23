import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../config/theme.dart';

/// AI Size Advisor Panel — analyzes model photo and recommends a size from the
/// product's size chart using Gemini Vision via the `analyzeBodyDimensions` Cloud Function.
class SizeAdvisorPanel extends StatefulWidget {
  final String modelImageUrl;
  final String apparelTitle;

  const SizeAdvisorPanel({
    super.key,
    required this.modelImageUrl,
    required this.apparelTitle,
  });

  @override
  State<SizeAdvisorPanel> createState() => _SizeAdvisorPanelState();
}

class _SizeAdvisorPanelState extends State<SizeAdvisorPanel>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _hasScanResult = false;
  String? _recommendedSize;
  String? _alternativeSize;
  int _confidence = 0;
  String? _buildType;
  String? _analysisText;
  String? _errorText;

  // Pulsing animation for scan button
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Default size chart — override with real Firestore data later
  static const Map<String, Map<String, dynamic>> _defaultSizeChart = {
    'XS': {'chest': 36, 'shoulder': 16, 'waist': 28},
    'S':  {'chest': 38, 'shoulder': 17, 'waist': 30},
    'M':  {'chest': 40, 'shoulder': 18, 'waist': 32},
    'L':  {'chest': 42, 'shoulder': 19, 'waist': 34},
    'XL': {'chest': 44, 'shoulder': 20, 'waist': 36},
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    if (widget.modelImageUrl.isEmpty || !widget.modelImageUrl.startsWith('http')) {
      setState(() {
        _errorText = 'Upload a photo first to enable AI size scan.';
        _hasScanResult = true;
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _hasScanResult = false;
      _errorText = null;
    });

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('analyzeBodyDimensions');
      final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
        'personImageUrl': widget.modelImageUrl,
        'sizeChart': _defaultSizeChart,
      });
      final data = result.data;
      if (mounted) {
        setState(() {
          _recommendedSize = (data['recommendedSize'] as String?) ?? 'M';
          _alternativeSize = data['alternativeSize'] as String?;
          _confidence = ((data['fitConfidence'] as num?) ?? 75).toInt();
          _buildType = data['buildType'] as String?;
          _analysisText = data['analysis'] as String?;
          _isScanning = false;
          _hasScanResult = true;
        });
      }
    } catch (e) {
      debugPrint('Size advisor error: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _hasScanResult = true;
          _errorText = 'Size scan unavailable. Check connectivity.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 0,
          ),
        ],
      ),
      child: _hasScanResult ? _buildResultView() : _buildScanPrompt(),
    );
  }

  Widget _buildScanPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.straighten_rounded,
                color: Color(0xFF00D4FF),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Size Advisor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Gemini scans your photo to recommend the perfect size',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Scan button
        _isScanning
            ? _buildScanningState()
            : ScaleTransition(
                scale: _pulseAnim,
                child: GestureDetector(
                  onTap: _runScan,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Scan for Recommended Size',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildScanningState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00D4FF).withValues(alpha: 0.3)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF00D4FF),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Gemini is analyzing body proportions…',
            style: TextStyle(color: Color(0xFF00D4FF), fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Estimating best fit from size chart',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_errorText != null) {
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorText!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() { _hasScanResult = false; _errorText = null; }),
            child: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 18),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with re-scan option
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00D4FF), size: 16),
                SizedBox(width: 6),
                Text(
                  'AI Size Result',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() { _hasScanResult = false; }),
              child: const Text(
                'Re-scan',
                style: TextStyle(color: Color(0xFF00D4FF), fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main size recommendation
        Row(
          children: [
            // Recommended size badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _recommendedSize ?? 'M',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Recommended Size',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Best Fit: Size $_recommendedSize',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Confidence bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _confidence / 100.0,
                            minHeight: 6,
                            backgroundColor: AppTheme.glassBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_confidence%',
                        style: const TextStyle(
                          color: Color(0xFF00D4FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_buildType != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Build: ${_buildType![0].toUpperCase()}${_buildType!.substring(1)}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Analysis text
        if (_analysisText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Text(
              _analysisText!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5),
            ),
          ),
        ],

        // Alternative size suggestion
        if (_alternativeSize != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                'Also try Size $_alternativeSize if you prefer a relaxed fit.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
