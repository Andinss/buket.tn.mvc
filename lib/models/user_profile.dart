class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String role;
  final String phoneNumber;
  final String address;
  final String city;
  final String postalCode;
  final String paymentMethod;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.postalCode = '',
    this.paymentMethod = 'Credit Card',
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'buyer',
      phoneNumber: data['phoneNumber'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'Credit Card',
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'email': email,
    'role': role,
    'phoneNumber': phoneNumber,
    'address': address,
    'city': city,
    'postalCode': postalCode,
    'paymentMethod': paymentMethod,
  };
}