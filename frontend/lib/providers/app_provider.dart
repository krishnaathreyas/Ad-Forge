import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'dart:io';

class AppProvider with ChangeNotifier {
  // Navigation State
  final PageController pageController = PageController();
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  // App Data State
  Product? _scannedProduct;
  Product? get scannedProduct => _scannedProduct;
  String _marketingContext = '';
  String get marketingContext => _marketingContext;
  String? _generatedVideoUrl;
  String? get generatedVideoUrl => _generatedVideoUrl;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;
  String _generationStatus = '';
  String get generationStatus => _generationStatus;

  File? _storeImage;
  File? get storeImage => _storeImage;
  String? _selectedCity;
  String? get selectedCity => _selectedCity;

  String? _error;
  String? get error => _error;

  // Anticipation progress for pre-uploaded ad playback (0.0 to 1.0)
  double _adProgress = 0.0;
  double get adProgress => _adProgress;
  Timer? _anticipationTimer;
  String? _pendingVideoUrl; // URL fetched during anticipation
  bool _urlFetched = false; // Whether URL fetch has completed
  bool _urlFetchFailed = false; // Whether URL fetch failed

  Timer? _pollingTimer;

  final List<ActivityItem> _recentActivities = [];
  List<ActivityItem> get recentActivities => _recentActivities;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _anticipationTimer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  void goToTab(int index) {
    _selectedIndex = index;
    pageController.animateToPage(index,
        duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
    notifyListeners();
  }

  void setPageIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  Future<void> setScannedProduct(Product product) async {
    _scannedProduct = product;
    addActivity(ActivityItem(
        icon: Icons.qr_code_2,
        iconColor: Colors.green,
        title: 'Product Scanned',
        subtitle: product.name,
        time: 'Just now'));
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));

    // If the product has a pre-uploaded ad video, play it directly
    if (product.adUrl != null && product.adUrl!.isNotEmpty) {
      await playProductAd(product);
    } else {
      // Otherwise go to context screen for AI-generated ad
      goToTab(2);
    }
  }

  /// Play a pre-uploaded advertisement video with an 8-second anticipation screen.
  /// Fetches the presigned S3 URL from the backend in parallel with the progress animation.
  /// Video playback starts only after the progress bar reaches 100%.
  Future<void> playProductAd(Product product) async {
    // Guard against duplicate invocations
    if (_isGenerating) return;

    _isGenerating = true;
    _generationStatus = 'Preparing your advertisement...';
    _generatedVideoUrl = null;
    _error = null;
    _adProgress = 0.0;
    _pendingVideoUrl = null;
    _urlFetched = false;
    _urlFetchFailed = false;
    notifyListeners();

    goToTab(3);

    // Start fetching the presigned URL in the background
    _fetchAdUrl(product);

    // Start the 8-second anticipation progress animation
    const anticipationDuration = Duration(seconds: 8);
    const tickInterval = Duration(milliseconds: 80); // ~12.5 FPS updates
    final totalTicks = anticipationDuration.inMilliseconds ~/ tickInterval.inMilliseconds;
    int currentTick = 0;

    _anticipationTimer?.cancel();
    _anticipationTimer = Timer.periodic(tickInterval, (timer) {
      currentTick++;
      _adProgress = (currentTick / totalTicks).clamp(0.0, 1.0);

      // Update status text at milestones
      if (_adProgress < 0.3) {
        _generationStatus = 'Preparing your advertisement...';
      } else if (_adProgress < 0.6) {
        _generationStatus = 'Loading ${product.name} ad...';
      } else if (_adProgress < 0.9) {
        _generationStatus = 'Almost ready...';
      } else {
        _generationStatus = 'Finalizing...';
      }

      notifyListeners();

      // When progress reaches 100%, complete the anticipation
      if (currentTick >= totalTicks) {
        timer.cancel();
        _anticipationTimer = null;
        _onAnticipationComplete(product);
      }
    });
  }

  /// Fetch the ad video URL in the background during anticipation.
  Future<void> _fetchAdUrl(Product product) async {
    try {
      final videoUrl = await ApiService.getAdVideoUrl(productId: product.id);
      _pendingVideoUrl = videoUrl;
      _urlFetched = true;
      _urlFetchFailed = videoUrl == null;
      print("✅ Ad URL fetched for ${product.name}: ${videoUrl != null ? 'success' : 'null'}");
    } catch (e) {
      _urlFetched = true;
      _urlFetchFailed = true;
      print("❌ Failed to fetch ad URL for ${product.id}: $e");
    }
    // Don't notifyListeners here — let the anticipation timer drive UI updates.
    // If the timer has already finished, _onAnticipationComplete will handle it.
    if (_anticipationTimer == null && _isGenerating) {
      _onAnticipationComplete(product);
    }
  }

  /// Called when the anticipation progress bar reaches 100%.
  /// Waits for URL fetch if still pending, then starts video or shows error.
  void _onAnticipationComplete(Product product) {
    // If URL hasn't been fetched yet, wait for it
    if (!_urlFetched) {
      _generationStatus = 'Finalizing...';
      notifyListeners();
      return; // _fetchAdUrl will call this again when done
    }

    if (_urlFetchFailed || _pendingVideoUrl == null) {
      _isGenerating = false;
      _error = 'Could not load advertisement for ${product.name}. Please try again.';
      _generationStatus = '';
      _adProgress = 0.0;
      print("❌ Ad video URL unavailable for ${product.id}");
    } else {
      _generatedVideoUrl = _pendingVideoUrl;
      _isGenerating = false;
      _generationStatus = 'Complete!';
      _adProgress = 1.0;
      addActivity(ActivityItem(
          icon: Icons.play_circle_outline,
          iconColor: Colors.green,
          title: 'Ad Loaded',
          subtitle: product.name,
          time: 'Just now'));
      print("✅ Playing pre-uploaded ad for ${product.name}");
    }
    notifyListeners();
  }

  void setMarketingContext(String context) {
    _marketingContext = context;
    notifyListeners();
  }

  // Methods for existing features (keeping store image for UI purposes)
  void setStoreImage(File? image) {
    _storeImage = image;
    notifyListeners();
  }

  void setSelectedCity(String? city) {
    _selectedCity = city;
    notifyListeners();
  }

  // UPDATED: Now passes language to backend
  Future<bool> startVideoGeneration() async {
    if (_scannedProduct == null) return false;
    _isGenerating = true;
    _generatedVideoUrl = null;
    _generationStatus = "Kicking off the ad-forge engine...";
    notifyListeners();

    // Add a print statement here to see what's being passed
    print("--- API Call to startVideoGenerationJob ---");
    print("Product: ${_scannedProduct!.name}");
    print("Context: $_marketingContext");
    print("------------------------------------------");

    // UPDATED: Now includes language parameter
    final jobId = await ApiService.startVideoGenerationJob(
      product: _scannedProduct!,
      context: _marketingContext,
    );

    if (jobId != null) {
      goToTab(3); // Immediately go to the results screen to show progress
      _generationStatus = "Blueprint created, generating video clips...";
      notifyListeners();
      _startPolling(jobId);
      return true;
    } else {
      _generationStatus = "Failed to start generation job.";
      _isGenerating = false;
      _error = "Could not start the job. Check backend connection.";
      notifyListeners();
      return false;
    }
  }

  void _startPolling(String jobId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Timeout after 5 minutes
      if (timer.tick > 20) {
        _generationStatus =
            "Generation is taking too long. Please try again later.";
        _isGenerating = false;
        timer.cancel();
        notifyListeners();
        return;
      }

      final statusResult = await ApiService.checkJobStatus(jobId: jobId);

      if (statusResult != null) {
        final status = statusResult['status'];
        if (status == 'COMPLETE') {
          _generatedVideoUrl = statusResult['finalVideoUrl'];
          _isGenerating = false;
          _generationStatus = "Complete!";
          timer.cancel();
          addActivity(ActivityItem(
              icon: Icons.play_circle_outline,
              iconColor: Colors.green,
              title: 'New Ad Generated',
              subtitle: _scannedProduct?.name ?? 'Custom Product',
              time: 'Just now'));
          print("Final Video URL: $_generatedVideoUrl");
        } else if (status == 'FAILED') {
          _generationStatus = "Video generation failed.";
          _error = statusResult['errorMessage'] ??
              "The backend process failed during generation.";
          _isGenerating = false;
          timer.cancel();
        } else {
          _generationStatus = "Status: ${status ?? 'Processing...'}";
        }
      } else {
        _generationStatus = "Error checking status. Retrying...";
      }
      notifyListeners();
    });
  }

  // UPDATED: Reset now includes language
  void resetFlow() {
    _pollingTimer?.cancel();
    _anticipationTimer?.cancel();
    _scannedProduct = null;
    _marketingContext = '';
    _generatedVideoUrl = null;
    _isGenerating = false;
    _generationStatus = '';
    _error = null;
    _storeImage = null;
    _selectedCity = null;
    _adProgress = 0.0;
    _pendingVideoUrl = null;
    _urlFetched = false;
    _urlFetchFailed = false;
    goToTab(0);
    notifyListeners();
  }

  void addActivity(ActivityItem activity) {
    _recentActivities.insert(0, activity);
    if (_recentActivities.length > 5) _recentActivities.removeLast();
    notifyListeners();
  }
}

class ActivityItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
