enum NetworkStatus { verified, suspicious, unknown, blocked, trusted, flagged }

enum SecurityType { wpa2, wpa3, wep, open }

enum AccessPointAction { block, trust, flag, unflag, unblock, untrust }

enum AccessPointCategory { blocked, trusted, flagged }

class NetworkModel {
  final String id;
  final String name;
  final String? description;
  final NetworkStatus status;
  final SecurityType securityType;
  final int signalStrength; // 0-100
  final String macAddress;
  final double? latitude;
  final double? longitude;
  final DateTime lastSeen;
  final bool isConnected;
  final String? cityName;
  final String? address;
  final String? ipAddress; // Current IP address when connected
  final bool isUserManaged; // If user has manually categorized this AP
  final DateTime? lastActionDate;
  final bool isSaved; // If network is saved in device or app

  NetworkModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.securityType,
    required this.signalStrength,
    required this.macAddress,
    this.latitude,
    this.longitude,
    required this.lastSeen,
    this.isConnected = false,
    this.cityName,
    this.address,
    this.ipAddress,
    this.isUserManaged = false,
    this.lastActionDate,
    this.isSaved = false,
  });

  String get securityTypeString {
    switch (securityType) {
      case SecurityType.wpa2:
        return 'WPA2';
      case SecurityType.wpa3:
        return 'WPA3';
      case SecurityType.wep:
        return 'WEP';
      case SecurityType.open:
        return 'Open';
    }
  }

  bool get isSuspicious => status == NetworkStatus.suspicious;
  bool get isBlocked => status == NetworkStatus.blocked;
  bool get isTrusted => status == NetworkStatus.trusted;
  bool get isFlagged => status == NetworkStatus.flagged;
  bool get isSecured => securityType != SecurityType.open;
  
  String get displayLocation => cityName ?? (latitude != null && longitude != null ? 
    '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}' : 'Unknown location');
  
  String get statusDisplayName {
    switch (status) {
      case NetworkStatus.verified:
        return 'Verified';
      case NetworkStatus.suspicious:
        return 'Suspicious';
      case NetworkStatus.unknown:
        return 'Unknown';
      case NetworkStatus.blocked:
        return 'Blocked';
      case NetworkStatus.trusted:
        return 'Trusted';
      case NetworkStatus.flagged:
        return 'Flagged';
    }
  }
  
  // Create copy with updated status for user actions
  NetworkModel copyWith({
    String? id,
    String? name,
    String? description,
    NetworkStatus? status,
    SecurityType? securityType,
    int? signalStrength,
    String? macAddress,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    bool? isConnected,
    String? cityName,
    String? address,
    String? ipAddress,
    bool? isUserManaged,
    DateTime? lastActionDate,
    bool? isSaved,
  }) {
    return NetworkModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      securityType: securityType ?? this.securityType,
      signalStrength: signalStrength ?? this.signalStrength,
      macAddress: macAddress ?? this.macAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
      cityName: cityName ?? this.cityName,
      address: address ?? this.address,
      ipAddress: ipAddress ?? this.ipAddress,
      isUserManaged: isUserManaged ?? this.isUserManaged,
      lastActionDate: lastActionDate ?? this.lastActionDate,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  String get signalStrengthString {
    if (signalStrength > 70) return 'Strong';
    if (signalStrength > 40) return 'Medium';
    return 'Weak';
  }

  int get signalBars {
    if (signalStrength > 75) return 4;
    if (signalStrength > 50) return 3;
    if (signalStrength > 25) return 2;
    return 1;
  }

  factory NetworkModel.fromJson(Map<String, dynamic> json) {
    return NetworkModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      status: NetworkStatus.values.firstWhere(
        (e) => e.toString() == 'NetworkStatus.${json['status']}',
      ),
      securityType: SecurityType.values.firstWhere(
        (e) => e.toString() == 'SecurityType.${json['securityType']}',
      ),
      signalStrength: json['signalStrength'],
      macAddress: json['macAddress'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      lastSeen: DateTime.parse(json['lastSeen']),
      isConnected: json['isConnected'] ?? false,
      cityName: json['cityName'],
      address: json['address'],
      ipAddress: json['ipAddress'],
      isUserManaged: json['isUserManaged'] ?? false,
      lastActionDate: json['lastActionDate'] != null ? DateTime.parse(json['lastActionDate']) : null,
      isSaved: json['isSaved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.toString().split('.').last,
      'securityType': securityType.toString().split('.').last,
      'signalStrength': signalStrength,
      'macAddress': macAddress,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': lastSeen.toIso8601String(),
      'isConnected': isConnected,
      'cityName': cityName,
      'address': address,
      'ipAddress': ipAddress,
      'isUserManaged': isUserManaged,
      'lastActionDate': lastActionDate?.toIso8601String(),
      'isSaved': isSaved,
    };
  }
}