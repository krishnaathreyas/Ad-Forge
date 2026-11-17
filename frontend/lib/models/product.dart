class Product {
  final String id; // This will be used as the SKU / QR identifier
  final String name;
  final String brand;
  final String category;
  final String description;
  final List<String> features;
  final String imageUrl;
  final double price;
  final String? adUrl; // Pre-uploaded advertisement video URL

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.description,
    required this.features,
    required this.imageUrl,
    required this.price,
    this.adUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      features: List<String>.from(json['features'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      adUrl: json['adUrl'],
    );
  }

  /// Centralized product-to-video mapping.
  /// QR identifiers → S3 ad video URLs.
  /// To add a new product, simply add a new entry here.
  static List<Product> get sampleProducts => [
        Product(
          id: 'PROD-S24ULTRA',
          name: 'Galaxy S24 Ultra',
          brand: 'Samsung',
          category: 'Smartphone',
          description: 'Premium smartphone with AI-powered camera and S Pen.',
          features: [
            'AI-Enhanced Camera',
            'S Pen Integration',
            '5G Connectivity',
          ],
          imageUrl: '',
          price: 1299.99,
          adUrl: 'https://adforge.s3.ap-south-1.amazonaws.com/ads/s24.mp4',
        ),
        Product(
          id: 'PROD-WW12T504DAB',
          name: 'Bespoke AI™ EcoBubble™ Washer',
          brand: 'Samsung',
          category: 'Home Appliance',
          description: 'Smart washing machine with AI-powered energy savings.',
          features: [
            'EcoBubble Technology',
            'AI Energy Mode',
            'SpaceMax Design',
          ],
          imageUrl: '',
          price: 899.99,
          adUrl: 'https://adforge.s3.ap-south-1.amazonaws.com/ads/wm.mp4',
        ),
        Product(
          id: 'PROD-QN900D-TV',
          name: 'Samsung Neo QLED 8K TV',
          brand: 'Samsung',
          category: 'Television',
          description:
              'Experience stunning detail with 8K resolution and AI upscaling.',
          features: [
            '8K Resolution',
            'Quantum Matrix Technology',
            'AI Upscaling',
          ],
          imageUrl: '',
          price: 4999.99,
          adUrl: 'https://adforge.s3.ap-south-1.amazonaws.com/ads/tv.mp4',
        ),
      ];

  /// Look up a product by its QR identifier. Returns null if not found.
  static Product? findByQrId(String qrId) {
    try {
      return sampleProducts.firstWhere((p) => p.id == qrId);
    } catch (_) {
      return null;
    }
  }
}

class AdResult {
  final String message;
  final String? videoUrl;
  final ProductInfo? productInfo;
  final String status;

  AdResult({
    required this.message,
    this.videoUrl,
    this.productInfo,
    required this.status,
  });

  factory AdResult.fromJson(Map<String, dynamic> json) {
    return AdResult(
      message: json['message'] ?? '',
      videoUrl: json['videoUrl'],
      productInfo: json['productInfo'] != null
          ? ProductInfo.fromJson(json['productInfo'])
          : null,
      status: json['status'] ?? 'Failed',
    );
  }
}

class ProductInfo {
  final String productName;
  final String? language;
  final String? userContext;

  ProductInfo({
    required this.productName,
    this.language,
    this.userContext,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      productName: json['productName'] ?? '',
      language: json['language'],
      userContext: json['userContext'],
    );
  }
}
