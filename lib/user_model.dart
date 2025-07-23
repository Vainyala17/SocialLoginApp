
class UserModel {
  final String id;
  final String name;
  final String email;
  final String photo;
  final String loginType;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.photo,
    required this.loginType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photo': photo,
      'loginType': loginType,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photo: map['photo'] ?? '',
      loginType: map['loginType'] ?? '',
    );
  }
}