class UserModel {
  final String id;
  final String name;
  final String email;
  final String photo;
  final String loginType;
  final String? dob;
  final String? gender;
  final String? phone;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.photo,
    required this.loginType,
    this.dob,
    this.gender,
    this.phone,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'photo': photo,
    'loginType': loginType,
    'dob': dob,
    'gender': gender,
    'phone': phone,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'],
    name: map['name'],
    email: map['email'],
    photo: map['photo'],
    loginType: map['loginType'],
    dob: map['dob'],
    gender: map['gender'],
    phone: map['phone'],
  );
}
