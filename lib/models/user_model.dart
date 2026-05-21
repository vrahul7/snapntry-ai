class UserModel {
  final String uid;
  final String email;
  final String companyName;
  final String contactName;
  final String role;
  final int credits;

  UserModel({
    required this.uid,
    required this.email,
    required this.companyName,
    required this.contactName,
    required this.role,
    required this.credits,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'companyName': companyName,
      'contactName': contactName,
      'role': role,
      'credits': credits,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      companyName: map['companyName'] ?? '',
      contactName: map['contactName'] ?? '',
      role: map['role'] ?? 'Client',
      credits: map['credits'] ?? 0,
    );
  }
}
