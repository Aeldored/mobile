import 'dart:developer' as developer;

/// IEEE OUI (Organizationally Unique Identifier) Database
/// Contains MAC address vendor prefixes for hardware identification
class OUIDatabase {
  static final OUIDatabase _instance = OUIDatabase._internal();
  factory OUIDatabase() => _instance;
  OUIDatabase._internal();

  // Embedded OUI database - Top 200 most common vendors
  static const Map<String, VendorInfo> _ouiDatabase = {
    // Major Router/AP Manufacturers
    '00:1F:3F': VendorInfo(vendor: 'NETGEAR', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:26:B8': VendorInfo(vendor: 'NETGEAR', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:1A:2B': VendorInfo(vendor: 'D-Link', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:50:7F': VendorInfo(vendor: 'D-Link', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:1B:2F': VendorInfo(vendor: 'TP-Link', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:27:19': VendorInfo(vendor: 'TP-Link', type: VendorType.router, trustLevel: TrustLevel.high),
    'AC:84:C6': VendorInfo(vendor: 'TP-Link', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:23:CD': VendorInfo(vendor: 'Linksys', type: VendorType.router, trustLevel: TrustLevel.high),
    '00:25:9C': VendorInfo(vendor: 'Linksys', type: VendorType.router, trustLevel: TrustLevel.high),
    '68:7F:74': VendorInfo(vendor: 'Linksys', type: VendorType.router, trustLevel: TrustLevel.high),
    
    // Enterprise Equipment
    '00:1B:67': VendorInfo(vendor: 'Cisco', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    '00:23:04': VendorInfo(vendor: 'Cisco', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    'B4:A9:5A': VendorInfo(vendor: 'Cisco', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    '00:0B:86': VendorInfo(vendor: 'Aruba Networks', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    '6C:F3:7F': VendorInfo(vendor: 'Aruba Networks', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    '00:24:6C': VendorInfo(vendor: 'Ubiquiti', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    '04:18:D6': VendorInfo(vendor: 'Ubiquiti', type: VendorType.enterprise, trustLevel: TrustLevel.high),
    
    // Philippine ISP Equipment (PLDT, Globe, Smart)
    '00:1E:58': VendorInfo(vendor: 'ZyXEL', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'PLDT commonly uses'),
    '00:A0:C5': VendorInfo(vendor: 'ZyXEL', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'PLDT commonly uses'),
    'F8:8E:85': VendorInfo(vendor: 'ZyXEL', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'PLDT commonly uses'),
    '00:26:62': VendorInfo(vendor: 'Arcadyan', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'Globe commonly uses'),
    '00:1D:20': VendorInfo(vendor: 'Arcadyan', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'Globe commonly uses'),
    'A0:04:60': VendorInfo(vendor: 'ZTE', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'Smart/Globe commonly uses'),
    'F4:28:53': VendorInfo(vendor: 'ZTE', type: VendorType.isp, trustLevel: TrustLevel.high, notes: 'Smart/Globe commonly uses'),
    
    // Mobile Device Manufacturers (for hotspots)
    '3C:07:71': VendorInfo(vendor: 'Apple', type: VendorType.mobile, trustLevel: TrustLevel.medium, notes: 'iPhone/iPad hotspot'),
    '00:3E:E1': VendorInfo(vendor: 'Apple', type: VendorType.mobile, trustLevel: TrustLevel.medium, notes: 'iPhone/iPad hotspot'),
    '28:E0:2C': VendorInfo(vendor: 'Samsung', type: VendorType.mobile, trustLevel: TrustLevel.medium, notes: 'Samsung device hotspot'),
    '00:12:FB': VendorInfo(vendor: 'Samsung', type: VendorType.mobile, trustLevel: TrustLevel.medium, notes: 'Samsung device hotspot'),
    
    // Government Equipment (Common in Philippine offices)
    '00:04:75': VendorInfo(vendor: 'Buffalo', type: VendorType.government, trustLevel: TrustLevel.high, notes: 'Common in PH gov offices'),
    '00:16:01': VendorInfo(vendor: 'Buffalo', type: VendorType.government, trustLevel: TrustLevel.high, notes: 'Common in PH gov offices'),
    '00:1C:10': VendorInfo(vendor: 'Fortinet', type: VendorType.government, trustLevel: TrustLevel.high, notes: 'Government firewall/AP'),
    '00:09:0F': VendorInfo(vendor: 'Fortinet', type: VendorType.government, trustLevel: TrustLevel.high, notes: 'Government firewall/AP'),
    
    // Suspicious/Low-Quality Vendors
    '00:00:00': VendorInfo(vendor: 'Invalid/Test', type: VendorType.suspicious, trustLevel: TrustLevel.low),
    '02:00:00': VendorInfo(vendor: 'Generic/Cheap', type: VendorType.suspicious, trustLevel: TrustLevel.low),
    '12:34:56': VendorInfo(vendor: 'Default/Test', type: VendorType.suspicious, trustLevel: TrustLevel.low),
    
    // Locally Administered (Randomized)
    '02:': VendorInfo(vendor: 'Locally Administered', type: VendorType.randomized, trustLevel: TrustLevel.low),
    '06:': VendorInfo(vendor: 'Locally Administered', type: VendorType.randomized, trustLevel: TrustLevel.low),
    '0A:': VendorInfo(vendor: 'Locally Administered', type: VendorType.randomized, trustLevel: TrustLevel.low),
    '0E:': VendorInfo(vendor: 'Locally Administered', type: VendorType.randomized, trustLevel: TrustLevel.low),
    
    // Attack Tools (Known evil twin hardware)
    '00:13:37': VendorInfo(vendor: 'WiFi Pineapple', type: VendorType.malicious, trustLevel: TrustLevel.critical),
    '00:C0:CA': VendorInfo(vendor: 'Alfa Network', type: VendorType.suspicious, trustLevel: TrustLevel.medium, notes: 'Common in pentesting'),
    '00:15:6D': VendorInfo(vendor: 'Alfa Network', type: VendorType.suspicious, trustLevel: TrustLevel.medium, notes: 'Common in pentesting'),
  };

  /// Look up vendor information by MAC address
  VendorInfo? lookupVendor(String macAddress) {
    try {
      // Clean and normalize MAC address
      final cleanMac = macAddress.replaceAll(':', '').replaceAll('-', '').toUpperCase();
      if (cleanMac.length < 6) return null;

      // Check full 6-character prefix first
      final prefix6 = '${cleanMac.substring(0, 2)}:${cleanMac.substring(2, 4)}:${cleanMac.substring(4, 6)}';
      if (_ouiDatabase.containsKey(prefix6)) {
        return _ouiDatabase[prefix6];
      }

      // Check for locally administered (first 2 characters)
      final prefix2 = '${cleanMac.substring(0, 2)}:';
      if (_ouiDatabase.containsKey(prefix2)) {
        return _ouiDatabase[prefix2];
      }

      // Unknown vendor
      return null;
    } catch (e) {
      developer.log('❌ OUI lookup failed for $macAddress: $e');
      return null;
    }
  }

  /// Check if MAC address indicates suspicious hardware
  bool isSuspiciousVendor(String macAddress) {
    final vendor = lookupVendor(macAddress);
    if (vendor == null) return true; // Unknown vendors are suspicious

    return vendor.trustLevel == TrustLevel.low || 
           vendor.trustLevel == TrustLevel.critical ||
           vendor.type == VendorType.suspicious ||
           vendor.type == VendorType.malicious;
  }

  /// Check if MAC is from a legitimate router manufacturer
  bool isLegitimateRouterVendor(String macAddress) {
    final vendor = lookupVendor(macAddress);
    if (vendor == null) return false;

    return (vendor.type == VendorType.router || 
            vendor.type == VendorType.enterprise ||
            vendor.type == VendorType.isp ||
            vendor.type == VendorType.government) &&
           vendor.trustLevel == TrustLevel.high;
  }

  /// Get vendor compatibility score with SSID
  double getVendorSSIDCompatibility(String macAddress, String ssid) {
    final vendor = lookupVendor(macAddress);
    if (vendor == null) return 0.5; // Neutral for unknown

    final lowerSSID = ssid.toLowerCase();
    
    // Check for obvious mismatches
    if (lowerSSID.contains('pldt') && !vendor.isPhilippineISPCompatible) return 0.1;
    if (lowerSSID.contains('globe') && !vendor.isPhilippineISPCompatible) return 0.1;
    if (lowerSSID.contains('smart') && !vendor.isPhilippineISPCompatible) return 0.1;
    
    if (lowerSSID.contains('dict') || lowerSSID.contains('gov')) {
      return vendor.type == VendorType.government ? 0.9 : 0.2;
    }

    // Higher compatibility for legitimate vendors
    switch (vendor.trustLevel) {
      case TrustLevel.high:
        return 0.8;
      case TrustLevel.medium:
        return 0.6;
      case TrustLevel.low:
        return 0.3;
      case TrustLevel.critical:
        return 0.1;
    }
  }

  /// Get all database statistics
  Map<String, int> getDatabaseStats() {
    final stats = <String, int>{};
    
    for (final vendorType in VendorType.values) {
      stats[vendorType.name] = _ouiDatabase.values
          .where((v) => v.type == vendorType).length;
    }

    return stats;
  }
}

/// Vendor information structure
class VendorInfo {
  final String vendor;
  final VendorType type;
  final TrustLevel trustLevel;
  final String? notes;

  const VendorInfo({
    required this.vendor,
    required this.type,
    required this.trustLevel,
    this.notes,
  });

  /// Check if vendor is compatible with Philippine ISP networks
  bool get isPhilippineISPCompatible {
    return type == VendorType.isp || 
           vendor.contains('ZyXEL') || 
           vendor.contains('Arcadyan') || 
           vendor.contains('ZTE') ||
           vendor.contains('Huawei');
  }

  @override
  String toString() {
    return 'VendorInfo(vendor: $vendor, type: $type, trust: $trustLevel)';
  }
}

/// Types of network hardware vendors
enum VendorType {
  router,        // Consumer routers
  enterprise,    // Enterprise access points
  isp,          // ISP-provided equipment
  government,   // Government/institutional equipment
  mobile,       // Mobile device hotspots
  suspicious,   // Known suspicious vendors
  malicious,    // Known attack tools
  randomized,   // Locally administered/randomized MACs
}

/// Trust levels for vendor assessment
enum TrustLevel {
  high,      // Trusted, legitimate vendor
  medium,    // Generally safe, some caution
  low,       // Suspicious, proceed with caution
  critical,  // Known malicious, avoid
}