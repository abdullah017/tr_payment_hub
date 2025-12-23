/// Alıcı bilgisi
class BuyerInfo {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String phone;
  final String? identityNumber;
  final String ip;
  final String city;
  final String country;
  final String address;
  final String? zipCode;

  const BuyerInfo({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.phone,
    this.identityNumber,
    required this.ip,
    required this.city,
    required this.country,
    required this.address,
    this.zipCode,
  });

  String get fullName => '$name $surname';
}
