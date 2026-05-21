enum TryOnStatus { pending, processing, success, failed }

class TryOnModel {
  final String id;
  final String userId;
  final String apparelId;
  final String apparelTitle;
  final String apparelImageUrl;
  final String userPhotoUrl;
  final String? resultImageUrl;
  final TryOnStatus status;
  final DateTime createdAt;

  TryOnModel({
    required this.id,
    required this.userId,
    required this.apparelId,
    required this.apparelTitle,
    required this.apparelImageUrl,
    required this.userPhotoUrl,
    this.resultImageUrl,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'apparelId': apparelId,
      'apparelTitle': apparelTitle,
      'apparelImageUrl': apparelImageUrl,
      'userPhotoUrl': userPhotoUrl,
      'resultImageUrl': resultImageUrl,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TryOnModel.fromMap(Map<String, dynamic> map) {
    return TryOnModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      apparelId: map['apparelId'] ?? '',
      apparelTitle: map['apparelTitle'] ?? '',
      apparelImageUrl: map['apparelImageUrl'] ?? '',
      userPhotoUrl: map['userPhotoUrl'] ?? '',
      resultImageUrl: map['resultImageUrl'],
      status: TryOnStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TryOnStatus.pending,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
