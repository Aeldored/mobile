import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/quiz_history_model.dart';
import '../../../data/services/quiz_history_service.dart';
import '../main_screen.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });
}

class QuizScreen extends StatefulWidget {
  final QuizHistoryService? historyService;

  const QuizScreen({super.key, this.historyService});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _selectedAnswerIndex = -1;
  int _score = 0;
  bool _hasAnswered = false;
  bool _quizCompleted = false;
  late List<QuizQuestion> _currentQuizQuestions;
  late DateTime _quizStartTime;
  final List<QuestionResult> _questionResults = [];

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  void _initializeQuiz() {
    // Randomly select 10 questions from the pool of 100
    final random = Random();
    final shuffledQuestions = List<QuizQuestion>.from(_allQuestions);
    shuffledQuestions.shuffle(random);
    _currentQuizQuestions = shuffledQuestions.take(_questionsPerQuiz).toList();
    _quizStartTime = DateTime.now();
    _questionResults.clear();
  }

  Future<bool> _onWillPop() async {
    // Navigate back to home instead of exiting the app
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainScreen.navigateToTab(context, 0);
    return false;
  }

  static const int _questionsPerQuiz = 10;
  
  final List<QuizQuestion> _allQuestions = [
    // Basic Wi-Fi Security (Questions 1-25)
    QuizQuestion(
      question: "What is an 'Evil Twin' Wi-Fi attack?",
      options: [
        "A virus that infects twin computers",
        "A fake Wi-Fi hotspot that mimics a legitimate network",
        "Two routers with the same password",
        "A network that only allows two devices"
      ],
      correctAnswerIndex: 1,
      explanation: "An Evil Twin attack involves creating a malicious Wi-Fi hotspot that appears to be a legitimate network to steal user data.",
    ),
    QuizQuestion(
      question: "Which of these is the BEST practice when connecting to public Wi-Fi?",
      options: [
        "Always use a VPN",
        "Only connect to networks with strong passwords",
        "Turn off auto-connect features",
        "All of the above"
      ],
      correctAnswerIndex: 3,
      explanation: "All these practices are essential for public Wi-Fi security - using VPNs, avoiding weak networks, and controlling auto-connections.",
    ),
    QuizQuestion(
      question: "What should you verify before connecting to a public Wi-Fi network?",
      options: [
        "The network name with venue staff",
        "That it requires a password",
        "The signal strength",
        "The number of connected devices"
      ],
      correctAnswerIndex: 0,
      explanation: "Always verify the legitimate network name with venue staff to avoid connecting to malicious Evil Twin networks.",
    ),
    QuizQuestion(
      question: "Which type of website should you AVOID accessing on public Wi-Fi?",
      options: [
        "News websites",
        "Banking and financial sites",
        "Social media platforms",
        "Weather websites"
      ],
      correctAnswerIndex: 1,
      explanation: "Banking and financial sites contain sensitive information that could be intercepted on unsecured public networks.",
    ),
    QuizQuestion(
      question: "What does WPA3 provide for Wi-Fi security?",
      options: [
        "Faster internet speeds",
        "Enhanced encryption and protection",
        "Better signal range",
        "Automatic network switching"
      ],
      correctAnswerIndex: 1,
      explanation: "WPA3 is the latest Wi-Fi security protocol providing stronger encryption and better protection against attacks.",
    ),
    QuizQuestion(
      question: "How can you identify a suspicious Wi-Fi network?",
      options: [
        "Generic names like 'Free_WiFi'",
        "Multiple networks with similar names",
        "Networks without passwords in public places",
        "All of the above"
      ],
      correctAnswerIndex: 3,
      explanation: "Suspicious networks often have generic names, duplicate names, or lack proper security in public areas.",
    ),
    QuizQuestion(
      question: "What should you do if you suspect you've connected to an Evil Twin network?",
      options: [
        "Continue browsing but avoid sensitive sites",
        "Disconnect immediately and change passwords",
        "Turn off Wi-Fi for a few minutes",
        "Switch to mobile data only"
      ],
      correctAnswerIndex: 1,
      explanation: "Immediately disconnect and change passwords for any accounts accessed, as your data may have been compromised.",
    ),
    QuizQuestion(
      question: "Which government agency in the Philippines handles cybersecurity guidelines?",
      options: [
        "DOT (Department of Tourism)",
        "DICT (Department of Information and Communications Technology)",
        "DTI (Department of Trade and Industry)",
        "DOF (Department of Finance)"
      ],
      correctAnswerIndex: 1,
      explanation: "DICT is responsible for ICT development and cybersecurity policies in the Philippines.",
    ),
    QuizQuestion(
      question: "What is the purpose of MAC address filtering in Wi-Fi security?",
      options: [
        "To block specific device types",
        "To allow only authorized devices to connect",
        "To improve internet speed",
        "To reduce network interference"
      ],
      correctAnswerIndex: 1,
      explanation: "MAC address filtering allows network administrators to control which devices can connect to the network.",
    ),
    QuizQuestion(
      question: "When using public Wi-Fi, you should avoid:",
      options: [
        "Checking email",
        "Online banking and shopping",
        "Reading news articles",
        "Watching videos"
      ],
      correctAnswerIndex: 1,
      explanation: "Avoid activities involving sensitive personal or financial information on public Wi-Fi networks due to security risks.",
    ),
    QuizQuestion(
      question: "What does SSID stand for?",
      options: [
        "Secure Service Identifier",
        "System Security Identity",
        "Service Set Identifier",
        "Secure Socket Interface"
      ],
      correctAnswerIndex: 2,
      explanation: "SSID stands for Service Set Identifier, which is the name of a Wi-Fi network that appears when you search for available networks.",
    ),
    QuizQuestion(
      question: "What is WEP encryption?",
      options: [
        "A modern, highly secure encryption standard",
        "An outdated, easily broken encryption protocol",
        "A type of firewall for Wi-Fi networks",
        "A network monitoring tool"
      ],
      correctAnswerIndex: 1,
      explanation: "WEP (Wired Equivalent Privacy) is an outdated encryption protocol that can be easily broken and should not be used.",
    ),
    QuizQuestion(
      question: "What is a VPN's primary function on public Wi-Fi?",
      options: [
        "Increase internet speed",
        "Block advertisements",
        "Encrypt your internet traffic",
        "Improve signal strength"
      ],
      correctAnswerIndex: 2,
      explanation: "A VPN encrypts your internet traffic, protecting your data from being intercepted on public Wi-Fi networks.",
    ),
    QuizQuestion(
      question: "What is packet sniffing?",
      options: [
        "A method to improve Wi-Fi speed",
        "Intercepting and analyzing network traffic",
        "A way to find hidden networks",
        "A technique to boost signal strength"
      ],
      correctAnswerIndex: 1,
      explanation: "Packet sniffing is the practice of intercepting and analyzing network traffic, often used maliciously on unsecured networks.",
    ),
    QuizQuestion(
      question: "What is the main difference between WPA2 and WPA3?",
      options: [
        "WPA3 has faster speeds",
        "WPA3 has stronger encryption and security features",
        "WPA3 works on older devices",
        "WPA3 has a longer range"
      ],
      correctAnswerIndex: 1,
      explanation: "WPA3 provides stronger encryption, better protection against password attacks, and enhanced security features compared to WPA2.",
    ),
    QuizQuestion(
      question: "What is a 'man-in-the-middle' attack?",
      options: [
        "When someone physically stands between two people",
        "An attack where someone intercepts communication between two parties",
        "A virus that spreads between devices",
        "A type of denial-of-service attack"
      ],
      correctAnswerIndex: 1,
      explanation: "A man-in-the-middle attack occurs when an attacker intercepts and potentially alters communication between two parties without their knowledge.",
    ),
    QuizQuestion(
      question: "What should you look for in a secure public Wi-Fi network?",
      options: [
        "No password required",
        "Generic network names",
        "Strong signal strength only",
        "WPA2/WPA3 encryption and verification from venue"
      ],
      correctAnswerIndex: 3,
      explanation: "Secure public Wi-Fi should use WPA2/WPA3 encryption and the network name should be verified with the venue staff.",
    ),
    QuizQuestion(
      question: "What is two-factor authentication (2FA)?",
      options: [
        "Using two different passwords",
        "An additional security layer beyond just a password",
        "Connecting to two different networks",
        "Using two different devices"
      ],
      correctAnswerIndex: 1,
      explanation: "Two-factor authentication adds an extra security layer by requiring a second form of verification beyond just a password.",
    ),
    QuizQuestion(
      question: "What is HTTPS?",
      options: [
        "A faster version of HTTP",
        "HTTP with security encryption",
        "A type of Wi-Fi network",
        "A web browser"
      ],
      correctAnswerIndex: 1,
      explanation: "HTTPS is HTTP with SSL/TLS encryption, providing secure communication over the internet.",
    ),
    QuizQuestion(
      question: "What is the purpose of a firewall on your device?",
      options: [
        "To speed up internet connection",
        "To block malicious network traffic",
        "To find Wi-Fi networks",
        "To improve battery life"
      ],
      correctAnswerIndex: 1,
      explanation: "A firewall monitors and controls incoming and outgoing network traffic, blocking potentially malicious connections.",
    ),
    QuizQuestion(
      question: "What is Wi-Fi Protected Setup (WPS)?",
      options: [
        "A security feature that should always be enabled",
        "A connection method that can be vulnerable to attacks",
        "A way to hide your network name",
        "A type of encryption protocol"
      ],
      correctAnswerIndex: 1,
      explanation: "WPS is a connection method that, while convenient, has known security vulnerabilities and should be disabled when not needed.",
    ),
    QuizQuestion(
      question: "What does it mean when a website shows a padlock icon in the address bar?",
      options: [
        "The website is loading slowly",
        "The website is using HTTPS encryption",
        "The website requires a password",
        "The website is blocked"
      ],
      correctAnswerIndex: 1,
      explanation: "A padlock icon indicates that the website is using HTTPS encryption, providing a secure connection.",
    ),
    QuizQuestion(
      question: "What is the recommended action for unsecured public Wi-Fi?",
      options: [
        "Use it freely for all activities",
        "Only use it for non-sensitive browsing or with a VPN",
        "Never connect to any public Wi-Fi",
        "Only use it for downloading files"
      ],
      correctAnswerIndex: 1,
      explanation: "Unsecured public Wi-Fi should only be used for non-sensitive activities or with a VPN for protection.",
    ),
    QuizQuestion(
      question: "What is network segmentation?",
      options: [
        "Dividing a network into smaller, isolated sections",
        "Connecting multiple networks together",
        "Increasing network speed",
        "Hiding the network name"
      ],
      correctAnswerIndex: 0,
      explanation: "Network segmentation involves dividing a network into smaller sections to limit access and improve security.",
    ),
    QuizQuestion(
      question: "What is the purpose of regularly updating your device's software?",
      options: [
        "To get new features only",
        "To fix security vulnerabilities and bugs",
        "To change the appearance",
        "To increase storage space"
      ],
      correctAnswerIndex: 1,
      explanation: "Regular software updates fix security vulnerabilities and bugs, keeping your device more secure.",
    ),
    
    // Intermediate Wi-Fi Security (Questions 26-50)
    QuizQuestion(
      question: "What is DNS spoofing in the context of Wi-Fi security?",
      options: [
        "Redirecting domain requests to malicious IP addresses",
        "Blocking access to all websites",
        "Speeding up domain name resolution",
        "Hiding your browsing history"
      ],
      correctAnswerIndex: 0,
      explanation: "DNS spoofing redirects legitimate domain requests to malicious IP addresses, potentially leading users to fake websites.",
    ),
    QuizQuestion(
      question: "What is a rogue access point?",
      options: [
        "A broken Wi-Fi router",
        "An unauthorized wireless access point on a network",
        "A router with weak signal",
        "A password-protected network"
      ],
      correctAnswerIndex: 1,
      explanation: "A rogue access point is an unauthorized wireless access point that can be used to gain network access or intercept traffic.",
    ),
    QuizQuestion(
      question: "What is Wi-Fi deauthentication attack?",
      options: [
        "Forgetting your Wi-Fi password",
        "Forcibly disconnecting devices from a Wi-Fi network",
        "Blocking internet access",
        "Changing network passwords"
      ],
      correctAnswerIndex: 1,
      explanation: "A deauthentication attack forcibly disconnects devices from a Wi-Fi network by sending fake deauthentication frames.",
    ),
    QuizQuestion(
      question: "What is KRACK attack?",
      options: [
        "A physical attack on routers",
        "An attack that exploits WPA2 key reinstallation",
        "A password cracking method",
        "A denial of service attack"
      ],
      correctAnswerIndex: 1,
      explanation: "KRACK (Key Reinstallation Attack) exploits a vulnerability in WPA2 by forcing key reinstallation, potentially allowing traffic decryption.",
    ),
    QuizQuestion(
      question: "What is the purpose of network monitoring tools?",
      options: [
        "To increase network speed",
        "To detect unauthorized access and suspicious activity",
        "To block all network traffic",
        "To hide network information"
      ],
      correctAnswerIndex: 1,
      explanation: "Network monitoring tools help detect unauthorized access, suspicious activity, and potential security threats on the network.",
    ),
    QuizQuestion(
      question: "What is a captive portal?",
      options: [
        "A secure VPN connection",
        "A web page that requires authentication before internet access",
        "A type of firewall",
        "A network encryption method"
      ],
      correctAnswerIndex: 1,
      explanation: "A captive portal is a web page displayed before users can access the internet, often requiring authentication or agreement to terms.",
    ),
    QuizQuestion(
      question: "What is the difference between open and closed Wi-Fi networks?",
      options: [
        "Open networks are faster than closed networks",
        "Open networks don't require passwords, closed networks do",
        "There is no difference",
        "Closed networks are always more expensive"
      ],
      correctAnswerIndex: 1,
      explanation: "Open networks don't require passwords for connection, while closed networks require authentication credentials.",
    ),
    QuizQuestion(
      question: "What is a mesh network?",
      options: [
        "A network with holes in it",
        "Multiple access points working together to provide coverage",
        "A network only for gaming",
        "A type of wired network"
      ],
      correctAnswerIndex: 1,
      explanation: "A mesh network uses multiple interconnected access points to provide seamless Wi-Fi coverage over a large area.",
    ),
    QuizQuestion(
      question: "What is band steering in Wi-Fi networks?",
      options: [
        "Changing the network password",
        "Automatically directing devices to the best frequency band",
        "Blocking certain devices",
        "Increasing signal strength"
      ],
      correctAnswerIndex: 1,
      explanation: "Band steering automatically directs devices to the optimal frequency band (2.4GHz or 5GHz) for better performance.",
    ),
    QuizQuestion(
      question: "What is the purpose of guest networks?",
      options: [
        "To provide faster internet to visitors",
        "To isolate visitor devices from the main network",
        "To block guest access to the internet",
        "To monitor guest activity"
      ],
      correctAnswerIndex: 1,
      explanation: "Guest networks isolate visitor devices from the main network, preventing access to internal resources while allowing internet access.",
    ),
    QuizQuestion(
      question: "What is Wi-Fi Protected Access (WPA) Personal vs Enterprise?",
      options: [
        "Personal is faster than Enterprise",
        "Personal uses pre-shared keys, Enterprise uses individual authentication",
        "Enterprise is only for businesses",
        "There is no difference"
      ],
      correctAnswerIndex: 1,
      explanation: "WPA Personal uses a shared password for all users, while WPA Enterprise uses individual user authentication through a authentication server.",
    ),
    QuizQuestion(
      question: "What is a beacon frame in Wi-Fi?",
      options: [
        "A signal that announces the presence of a Wi-Fi network",
        "A type of data packet",
        "A security warning",
        "An error message"
      ],
      correctAnswerIndex: 0,
      explanation: "Beacon frames are signals sent by access points to announce their presence and provide network information to potential clients.",
    ),
    QuizQuestion(
      question: "What is channel hopping in Wi-Fi security?",
      options: [
        "Switching between different Wi-Fi networks",
        "Monitoring multiple Wi-Fi channels for analysis",
        "Jumping over network obstacles",
        "Changing network passwords frequently"
      ],
      correctAnswerIndex: 1,
      explanation: "Channel hopping involves monitoring multiple Wi-Fi channels in sequence to capture traffic or detect networks across all channels.",
    ),
    QuizQuestion(
      question: "What is the purpose of disabling SSID broadcast?",
      options: [
        "To make the network completely secure",
        "To hide the network name from casual discovery",
        "To increase network speed",
        "To improve signal strength"
      ],
      correctAnswerIndex: 1,
      explanation: "Disabling SSID broadcast hides the network name from casual discovery, though it provides only minimal security improvement.",
    ),
    QuizQuestion(
      question: "What is a Wi-Fi pineapple device?",
      options: [
        "A fruit-shaped router",
        "A device used for wireless penetration testing",
        "A network speed booster",
        "A Wi-Fi range extender"
      ],
      correctAnswerIndex: 1,
      explanation: "A Wi-Fi Pineapple is a penetration testing device used to perform various wireless security assessments and attacks.",
    ),
    QuizQuestion(
      question: "What is the significance of the 2.4GHz vs 5GHz frequency bands?",
      options: [
        "2.4GHz is always faster than 5GHz",
        "5GHz offers higher speeds but shorter range than 2.4GHz",
        "There is no difference between them",
        "5GHz is only for enterprise networks"
      ],
      correctAnswerIndex: 1,
      explanation: "5GHz offers higher speeds and less congestion but has a shorter range compared to 2.4GHz, which has better range but lower speeds.",
    ),
    QuizQuestion(
      question: "What is Wi-Fi Direct?",
      options: [
        "A faster internet connection",
        "Direct device-to-device Wi-Fi communication without an access point",
        "A type of network cable",
        "A security protocol"
      ],
      correctAnswerIndex: 1,
      explanation: "Wi-Fi Direct allows devices to connect directly to each other without requiring a traditional access point or router.",
    ),
    QuizQuestion(
      question: "What is the purpose of Quality of Service (QoS) in Wi-Fi networks?",
      options: [
        "To increase security",
        "To prioritize certain types of network traffic",
        "To hide network activity",
        "To block unwanted devices"
      ],
      correctAnswerIndex: 1,
      explanation: "QoS prioritizes certain types of network traffic to ensure important applications get adequate bandwidth and performance.",
    ),
    QuizQuestion(
      question: "What is a honeynet in cybersecurity?",
      options: [
        "A sweet-themed network name",
        "A decoy network designed to attract and detect attackers",
        "A network for beekeepers",
        "A high-speed network connection"
      ],
      correctAnswerIndex: 1,
      explanation: "A honeynet is a decoy network designed to attract attackers, allowing security teams to study their methods and detect threats.",
    ),
    QuizQuestion(
      question: "What is wardriving?",
      options: [
        "Driving while using Wi-Fi",
        "Searching for Wi-Fi networks while driving around",
        "A type of network attack",
        "Installing Wi-Fi in cars"
      ],
      correctAnswerIndex: 1,
      explanation: "Wardriving is the practice of searching for Wi-Fi networks while moving around in a vehicle, often to map network locations.",
    ),
    QuizQuestion(
      question: "What is the purpose of network access control (NAC)?",
      options: [
        "To speed up network connections",
        "To control which devices can access the network",
        "To increase Wi-Fi range",
        "To reduce network costs"
      ],
      correctAnswerIndex: 1,
      explanation: "Network Access Control (NAC) systems control which devices can access the network based on security policies and device compliance.",
    ),
    QuizQuestion(
      question: "What is a rainbow table attack?",
      options: [
        "An attack using colorful displays",
        "Using precomputed hash tables to crack passwords",
        "A network flooding attack",
        "An attack on weather monitoring systems"
      ],
      correctAnswerIndex: 1,
      explanation: "A rainbow table attack uses precomputed hash tables to quickly crack password hashes without having to compute them in real-time.",
    ),
    QuizQuestion(
      question: "What is the purpose of intrusion detection systems (IDS) in networks?",
      options: [
        "To provide internet access",
        "To monitor and alert on suspicious network activity",
        "To block all network traffic",
        "To improve network speed"
      ],
      correctAnswerIndex: 1,
      explanation: "Intrusion Detection Systems monitor network traffic and alert administrators to suspicious or potentially malicious activity.",
    ),
    QuizQuestion(
      question: "What is a zero-day vulnerability?",
      options: [
        "A vulnerability discovered on day zero of the year",
        "A security flaw that is unknown to vendors and has no available patch",
        "A vulnerability that affects zero devices",
        "A flaw that takes zero time to exploit"
      ],
      correctAnswerIndex: 1,
      explanation: "A zero-day vulnerability is a security flaw that is unknown to the software vendor and has no available patch, making it particularly dangerous.",
    ),
    QuizQuestion(
      question: "What is the principle of least privilege?",
      options: [
        "Giving users minimum necessary access rights",
        "Providing maximum access to trusted users",
        "Treating all users equally",
        "Giving access based on seniority"
      ],
      correctAnswerIndex: 0,
      explanation: "The principle of least privilege means giving users only the minimum access rights necessary to perform their tasks.",
    ),
    
    // Advanced Wi-Fi Security & Enterprise (Questions 51-75)
    QuizQuestion(
      question: "What is 802.1X authentication?",
      options: [
        "A wireless speed standard",
        "Port-based network access control protocol",
        "A type of encryption algorithm",
        "A network cable standard"
      ],
      correctAnswerIndex: 1,
      explanation: "802.1X is a port-based network access control protocol that provides authentication for devices trying to connect to a network.",
    ),
    QuizQuestion(
      question: "What is RADIUS in network security?",
      options: [
        "The distance Wi-Fi signals can travel",
        "A centralized authentication server protocol",
        "A type of network topology",
        "A wireless frequency measurement"
      ],
      correctAnswerIndex: 1,
      explanation: "RADIUS (Remote Authentication Dial-In User Service) is a protocol for centralized authentication, authorization, and accounting.",
    ),
    QuizQuestion(
      question: "What is EAP in wireless security?",
      options: [
        "Extended Access Point",
        "Extensible Authentication Protocol",
        "Encrypted Application Protocol",
        "Emergency Access Procedure"
      ],
      correctAnswerIndex: 1,
      explanation: "EAP (Extensible Authentication Protocol) is a framework for authentication used in wireless networks and point-to-point connections.",
    ),
    QuizQuestion(
      question: "What is the difference between EAP-TLS and EAP-PEAP?",
      options: [
        "TLS is faster than PEAP",
        "TLS requires client certificates, PEAP typically uses username/password",
        "PEAP is more secure than TLS",
        "There is no difference"
      ],
      correctAnswerIndex: 1,
      explanation: "EAP-TLS requires client certificates for authentication, while EAP-PEAP typically uses username/password authentication within a secure tunnel.",
    ),
    QuizQuestion(
      question: "What is a wireless intrusion prevention system (WIPS)?",
      options: [
        "A system to improve Wi-Fi speed",
        "A system that detects and prevents wireless security threats",
        "A system to manage Wi-Fi passwords",
        "A system to extend Wi-Fi range"
      ],
      correctAnswerIndex: 1,
      explanation: "WIPS actively monitors wireless networks to detect, locate, and automatically mitigate wireless security threats.",
    ),
    QuizQuestion(
      question: "What is the purpose of certificate pinning?",
      options: [
        "To display certificates on walls",
        "To associate a specific certificate with a particular service",
        "To speed up certificate verification",
        "To hide certificate information"
      ],
      correctAnswerIndex: 1,
      explanation: "Certificate pinning associates a specific certificate or public key with a particular service to prevent man-in-the-middle attacks.",
    ),
    QuizQuestion(
      question: "What is Perfect Forward Secrecy (PFS)?",
      options: [
        "A perfect security system with no vulnerabilities",
        "Session keys remain secure even if long-term keys are compromised",
        "A method to forward secure messages",
        "A type of wireless encryption"
      ],
      correctAnswerIndex: 1,
      explanation: "Perfect Forward Secrecy ensures that session keys remain secure even if the long-term private keys are later compromised.",
    ),
    QuizQuestion(
      question: "What is a security information and event management (SIEM) system?",
      options: [
        "A system for managing Wi-Fi passwords",
        "A platform for collecting and analyzing security data",
        "A system for encrypting network traffic",
        "A system for blocking malicious websites"
      ],
      correctAnswerIndex: 1,
      explanation: "SIEM systems collect, analyze, and correlate security data from multiple sources to detect and respond to security threats.",
    ),
    QuizQuestion(
      question: "What is the concept of defense in depth?",
      options: [
        "Having one very strong security control",
        "Using multiple layers of security controls",
        "Placing security controls deep in the network",
        "Having backup security systems"
      ],
      correctAnswerIndex: 1,
      explanation: "Defense in depth involves using multiple layers of security controls so that if one fails, others provide protection.",
    ),
    QuizQuestion(
      question: "What is network segmentation with VLANs?",
      options: [
        "Dividing physical cables into segments",
        "Creating logical network divisions to isolate traffic",
        "Connecting multiple networks together",
        "Increasing network bandwidth"
      ],
      correctAnswerIndex: 1,
      explanation: "VLANs (Virtual Local Area Networks) create logical network divisions that can isolate traffic for security and performance reasons.",
    ),
    QuizQuestion(
      question: "What is the purpose of a demilitarized zone (DMZ) in network security?",
      options: [
        "A zone with no military equipment",
        "A network segment that isolates public-facing services",
        "A zone with disabled Wi-Fi",
        "An area with no network access"
      ],
      correctAnswerIndex: 1,
      explanation: "A DMZ is a network segment that isolates public-facing services from the internal network to reduce security risks.",
    ),
    QuizQuestion(
      question: "What is threat modeling in cybersecurity?",
      options: [
        "Creating 3D models of threats",
        "Systematically identifying and evaluating potential security threats",
        "Modeling network traffic patterns",
        "Creating models of network topology"
      ],
      correctAnswerIndex: 1,
      explanation: "Threat modeling is a process of systematically identifying, evaluating, and prioritizing potential security threats to a system.",
    ),
    QuizQuestion(
      question: "What is the difference between symmetric and asymmetric encryption?",
      options: [
        "Symmetric is faster, asymmetric uses different keys for encryption/decryption",
        "Asymmetric is always more secure",
        "Symmetric only works on wireless networks",
        "There is no difference"
      ],
      correctAnswerIndex: 0,
      explanation: "Symmetric encryption uses the same key for encryption and decryption and is faster, while asymmetric uses different keys and enables secure key exchange.",
    ),
    QuizQuestion(
      question: "What is a certificate authority (CA)?",
      options: [
        "An authority that issues network licenses",
        "An entity that issues digital certificates",
        "A government agency for cybersecurity",
        "An authority that manages IP addresses"
      ],
      correctAnswerIndex: 1,
      explanation: "A Certificate Authority is a trusted entity that issues digital certificates to verify the identity of certificate holders.",
    ),
    QuizQuestion(
      question: "What is the purpose of security orchestration, automation, and response (SOAR)?",
      options: [
        "To replace security analysts",
        "To automate and coordinate security incident response",
        "To organize security equipment",
        "To respond to customer complaints"
      ],
      correctAnswerIndex: 1,
      explanation: "SOAR platforms help automate, orchestrate, and coordinate security incident response processes to improve efficiency and effectiveness.",
    ),
    QuizQuestion(
      question: "What is behavioral analysis in network security?",
      options: [
        "Analyzing user behavior patterns to detect anomalies",
        "Studying network cable behavior",
        "Analyzing router performance",
        "Monitoring internet usage patterns"
      ],
      correctAnswerIndex: 0,
      explanation: "Behavioral analysis monitors normal user and system behavior patterns to detect anomalies that might indicate security threats.",
    ),
    QuizQuestion(
      question: "What is the concept of zero trust network architecture?",
      options: [
        "Trusting no one in the organization",
        "Never trust, always verify - assume no implicit trust",
        "Having zero network access",
        "Trusting only zero-day vulnerabilities"
      ],
      correctAnswerIndex: 1,
      explanation: "Zero trust architecture assumes no implicit trust and continuously validates every transaction and user access request.",
    ),
    QuizQuestion(
      question: "What is endpoint detection and response (EDR)?",
      options: [
        "A system for managing network endpoints",
        "Security tools that monitor and respond to threats on endpoints",
        "A system for detecting network cables",
        "A response system for power outages"
      ],
      correctAnswerIndex: 1,
      explanation: "EDR tools continuously monitor endpoint activities to detect, investigate, and respond to cybersecurity threats.",
    ),
    QuizQuestion(
      question: "What is the principle of fail-safe defaults?",
      options: [
        "Systems should default to secure states when they fail",
        "Systems should never fail",
        "Failed systems should be replaced immediately",
        "Default passwords should never change"
      ],
      correctAnswerIndex: 0,
      explanation: "Fail-safe defaults means that when a system fails or encounters an error, it should default to a secure state rather than an insecure one.",
    ),
    QuizQuestion(
      question: "What is threat intelligence in cybersecurity?",
      options: [
        "Intelligence about network threats",
        "Evidence-based knowledge about current and potential security threats",
        "Artificial intelligence for threats",
        "Intelligence agencies handling cyber threats"
      ],
      correctAnswerIndex: 1,
      explanation: "Threat intelligence is evidence-based knowledge about current and emerging security threats that can inform security decisions.",
    ),
    QuizQuestion(
      question: "What is the purpose of security baselines?",
      options: [
        "The lowest level of security acceptable",
        "Minimum security standards and configurations",
        "The starting point for security implementations",
        "Basic security training requirements"
      ],
      correctAnswerIndex: 1,
      explanation: "Security baselines establish minimum security standards and configurations that systems must meet to maintain security.",
    ),
    QuizQuestion(
      question: "What is penetration testing?",
      options: [
        "Testing network cable penetration through walls",
        "Authorized simulated attacks to test security defenses",
        "Testing password penetration strength",
        "Testing signal penetration through obstacles"
      ],
      correctAnswerIndex: 1,
      explanation: "Penetration testing involves authorized simulated attacks on systems to identify vulnerabilities and test security defenses.",
    ),
    QuizQuestion(
      question: "What is the difference between vulnerability assessment and penetration testing?",
      options: [
        "They are the same thing",
        "Vulnerability assessment identifies flaws, penetration testing exploits them",
        "Penetration testing is always automated",
        "Vulnerability assessment is more dangerous"
      ],
      correctAnswerIndex: 1,
      explanation: "Vulnerability assessment identifies and catalogues security flaws, while penetration testing actively exploits vulnerabilities to test defenses.",
    ),
    QuizQuestion(
      question: "What is a security control framework?",
      options: [
        "A physical frame for security equipment",
        "A structured set of guidelines for implementing security controls",
        "A framework for building secure networks",
        "A control system for security cameras"
      ],
      correctAnswerIndex: 1,
      explanation: "A security control framework provides a structured set of guidelines and standards for implementing and managing security controls.",
    ),
    QuizQuestion(
      question: "What is the purpose of security awareness training?",
      options: [
        "To train security professionals",
        "To educate users about security risks and best practices",
        "To increase awareness of new security products",
        "To train users on security software"
      ],
      correctAnswerIndex: 1,
      explanation: "Security awareness training educates users about security risks, threats, and best practices to reduce human-related security incidents.",
    ),
    
    // Philippine Context & Regulations (Questions 76-90)
    QuizQuestion(
      question: "What is the Cybercrime Prevention Act of 2012 in the Philippines?",
      options: [
        "A law about internet service providers",
        "Republic Act 10175 - comprehensive law addressing cybercrime",
        "A law about Wi-Fi security",
        "A regulation for social media use"
      ],
      correctAnswerIndex: 1,
      explanation: "Republic Act 10175, the Cybercrime Prevention Act of 2012, is a comprehensive Philippine law that addresses various cybercrimes and their penalties.",
    ),
    QuizQuestion(
      question: "Which agency enforces cybercrime laws in the Philippines?",
      options: [
        "Department of Justice (DOJ)",
        "National Bureau of Investigation (NBI)",
        "Philippine National Police (PNP)",
        "All of the above"
      ],
      correctAnswerIndex: 3,
      explanation: "The DOJ, NBI, and PNP all have roles in enforcing cybercrime laws in the Philippines, with specialized cybercrime units.",
    ),
    QuizQuestion(
      question: "What is the Data Privacy Act of 2012 in the Philippines?",
      options: [
        "Republic Act 10173 - law protecting personal data",
        "A law about internet privacy",
        "A regulation for social media",
        "A law about Wi-Fi passwords"
      ],
      correctAnswerIndex: 0,
      explanation: "Republic Act 10173, the Data Privacy Act of 2012, protects personal data and regulates data processing in the Philippines.",
    ),
    QuizQuestion(
      question: "What is the National Privacy Commission (NPC) in the Philippines?",
      options: [
        "A commission for internet regulation",
        "The agency responsible for data privacy compliance",
        "A commission for national security",
        "An agency for cybercrime investigation"
      ],
      correctAnswerIndex: 1,
      explanation: "The National Privacy Commission is the Philippine agency responsible for ensuring compliance with data privacy laws and regulations.",
    ),
    QuizQuestion(
      question: "What penalties can be imposed under the Philippine Cybercrime Prevention Act?",
      options: [
        "Only fines",
        "Only imprisonment",
        "Both fines and imprisonment",
        "Only warnings"
      ],
      correctAnswerIndex: 2,
      explanation: "The Cybercrime Prevention Act provides for both fines and imprisonment as penalties, depending on the severity of the cybercrime.",
    ),
    QuizQuestion(
      question: "What is considered illegal access under Philippine cybercrime law?",
      options: [
        "Using public Wi-Fi",
        "Accessing computer systems without authorization",
        "Accessing social media",
        "Using someone else's internet connection with permission"
      ],
      correctAnswerIndex: 1,
      explanation: "Illegal access under Philippine law refers to accessing computer systems, networks, or data without proper authorization.",
    ),
    QuizQuestion(
      question: "What is the role of DICT in Philippine cybersecurity?",
      options: [
        "Only internet regulation",
        "Policy development and coordination of cybersecurity initiatives",
        "Only telecommunications regulation",
        "Arresting cybercriminals"
      ],
      correctAnswerIndex: 1,
      explanation: "DICT develops policies and coordinates cybersecurity initiatives across government agencies and the private sector in the Philippines.",
    ),
    QuizQuestion(
      question: "What is the Philippine cybersecurity framework based on?",
      options: [
        "Local development only",
        "International standards and best practices adapted for Philippine context",
        "Only US standards",
        "Only European standards"
      ],
      correctAnswerIndex: 1,
      explanation: "The Philippine cybersecurity framework is based on international standards and best practices adapted to the local Philippine context.",
    ),
    QuizQuestion(
      question: "What is required for organizations handling personal data in the Philippines?",
      options: [
        "Registration with NPC if they meet certain criteria",
        "Government permit only",
        "International certification",
        "Nothing is required"
      ],
      correctAnswerIndex: 0,
      explanation: "Organizations that meet specific criteria for personal data processing must register with the National Privacy Commission.",
    ),
    QuizQuestion(
      question: "What is the Philippine government's stance on critical information infrastructure?",
      options: [
        "It doesn't regulate it",
        "It has specific protection requirements and designation processes",
        "It only protects government systems",
        "It only provides guidelines"
      ],
      correctAnswerIndex: 1,
      explanation: "The Philippine government has specific requirements and processes for protecting critical information infrastructure.",
    ),
    QuizQuestion(
      question: "What is the purpose of the National Computer Emergency Response Team (NCERT)?",
      options: [
        "To provide internet service",
        "To coordinate national cybersecurity incident response",
        "To sell computer equipment",
        "To train computer technicians"
      ],
      correctAnswerIndex: 1,
      explanation: "NCERT coordinates national cybersecurity incident response and provides cybersecurity services to government agencies.",
    ),
    QuizQuestion(
      question: "What are the data breach notification requirements in the Philippines?",
      options: [
        "No notification required",
        "Notification to NPC and affected individuals within specific timeframes",
        "Only internal notification required",
        "Only police notification required"
      ],
      correctAnswerIndex: 1,
      explanation: "Philippine law requires notification to the NPC and affected individuals within specific timeframes when data breaches occur.",
    ),
    QuizQuestion(
      question: "What is considered cybersquatting under Philippine law?",
      options: [
        "Using too much internet bandwidth",
        "Registering domain names similar to existing trademarks for profit",
        "Staying too long on websites",
        "Using public computers for extended periods"
      ],
      correctAnswerIndex: 1,
      explanation: "Cybersquatting involves registering, trafficking, or using domain names similar to existing trademarks with bad faith intent to profit.",
    ),
    QuizQuestion(
      question: "What rights do data subjects have under the Philippine Data Privacy Act?",
      options: [
        "No specific rights",
        "Rights to be informed, access, correct, erase, and object to processing",
        "Only the right to complain",
        "Only the right to access their data"
      ],
      correctAnswerIndex: 1,
      explanation: "Data subjects have various rights including being informed, accessing their data, requesting corrections, erasure, and objecting to processing.",
    ),
    QuizQuestion(
      question: "What is the statute of limitations for cybercrime cases in the Philippines?",
      options: [
        "There is no time limit",
        "Varies depending on the specific cybercrime committed",
        "Always 5 years",
        "Always 10 years"
      ],
      correctAnswerIndex: 1,
      explanation: "The statute of limitations varies depending on the specific cybercrime, with different timeframes for different offenses.",
    ),
    
    // Emerging Threats & Future Tech (Questions 91-100)
    QuizQuestion(
      question: "What is Wi-Fi 6E?",
      options: [
        "The 6th version of Wi-Fi",
        "Wi-Fi 6 extended to the 6GHz band",
        "A security protocol",
        "A type of router"
      ],
      correctAnswerIndex: 1,
      explanation: "Wi-Fi 6E extends Wi-Fi 6 capabilities to the 6GHz frequency band, providing more spectrum and reduced congestion.",
    ),
    QuizQuestion(
      question: "What security improvements does Wi-Fi 7 promise?",
      options: [
        "No security improvements, only speed",
        "Enhanced encryption and improved security features",
        "Only password protection",
        "Removal of all security features"
      ],
      correctAnswerIndex: 1,
      explanation: "Wi-Fi 7 includes enhanced security features building upon WPA3 and other improvements for better protection.",
    ),
    QuizQuestion(
      question: "What is the Internet of Things (IoT) security challenge?",
      options: [
        "IoT devices are always secure",
        "Many IoT devices have weak security and are hard to update",
        "IoT only affects home devices",
        "IoT devices don't connect to Wi-Fi"
      ],
      correctAnswerIndex: 1,
      explanation: "IoT devices often have weak default security, infrequent updates, and can create security vulnerabilities in networks.",
    ),
    QuizQuestion(
      question: "What is artificial intelligence's role in cybersecurity?",
      options: [
        "AI makes cybersecurity unnecessary",
        "AI can enhance threat detection but also enable new attack methods",
        "AI only creates cyber threats",
        "AI has no role in cybersecurity"
      ],
      correctAnswerIndex: 1,
      explanation: "AI can significantly enhance threat detection and response capabilities, but can also be used by attackers to create more sophisticated threats.",
    ),
    QuizQuestion(
      question: "What is the concept of quantum-safe cryptography?",
      options: [
        "Cryptography that quantum computers can easily break",
        "Encryption methods designed to resist quantum computer attacks",
        "Cryptography only for quantum computers",
        "A type of physical security"
      ],
      correctAnswerIndex: 1,
      explanation: "Quantum-safe cryptography refers to encryption methods designed to be secure against both conventional and quantum computer attacks.",
    ),
    QuizQuestion(
      question: "What is edge computing's impact on network security?",
      options: [
        "It eliminates all security concerns",
        "It creates new security challenges by distributing computing resources",
        "It only improves security",
        "It has no impact on security"
      ],
      correctAnswerIndex: 1,
      explanation: "Edge computing distributes computing resources closer to users, creating new security challenges in managing distributed infrastructure.",
    ),
    QuizQuestion(
      question: "What are deepfakes in the context of cybersecurity?",
      options: [
        "Very secure encryption methods",
        "AI-generated fake audio/video content used in social engineering attacks",
        "Deep network analysis tools",
        "Advanced firewall systems"
      ],
      correctAnswerIndex: 1,
      explanation: "Deepfakes are AI-generated synthetic media that can be used in social engineering and disinformation attacks.",
    ),
    QuizQuestion(
      question: "What is 5G's impact on Wi-Fi security?",
      options: [
        "5G replaces Wi-Fi completely",
        "5G and Wi-Fi will coexist, creating new security considerations",
        "5G makes Wi-Fi more secure",
        "5G has no relationship to Wi-Fi"
      ],
      correctAnswerIndex: 1,
      explanation: "5G and Wi-Fi will coexist and complement each other, creating new security considerations for hybrid connectivity scenarios.",
    ),
    QuizQuestion(
      question: "What is supply chain security in technology?",
      options: [
        "Security for shipping technology products",
        "Ensuring security throughout the technology development and delivery process",
        "Security for supply chain management software",
        "Physical security of warehouses"
      ],
      correctAnswerIndex: 1,
      explanation: "Supply chain security involves ensuring security throughout the entire process of technology development, manufacturing, and delivery.",
    ),
    QuizQuestion(
      question: "What is the importance of security by design?",
      options: [
        "Designing beautiful security interfaces",
        "Building security considerations into systems from the beginning",
        "Designing security logos and branding",
        "Creating security documentation design"
      ],
      correctAnswerIndex: 1,
      explanation: "Security by design means building security considerations and protections into systems from the initial design phase rather than adding them later.",
    ),
  ];

  void _selectAnswer(int answerIndex) {
    if (_hasAnswered) return;

    final currentQuestion = _currentQuizQuestions[_currentQuestionIndex];
    final isCorrect = answerIndex == currentQuestion.correctAnswerIndex;

    setState(() {
      _selectedAnswerIndex = answerIndex;
      _hasAnswered = true;
      
      if (isCorrect) {
        _score++;
      }
    });

    // Record the question result
    _questionResults.add(QuestionResult(
      question: currentQuestion.question,
      options: currentQuestion.options,
      correctAnswerIndex: currentQuestion.correctAnswerIndex,
      selectedAnswerIndex: answerIndex,
      isCorrect: isCorrect,
      explanation: currentQuestion.explanation,
    ));
  }

  void _nextQuestion() {
    setState(() {
      if (_currentQuestionIndex < _currentQuizQuestions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswerIndex = -1;
        _hasAnswered = false;
      } else {
        _quizCompleted = true;
        _saveQuizSession();
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = -1;
      _score = 0;
      _hasAnswered = false;
      _quizCompleted = false;
      // Generate a new random set of questions
      _initializeQuiz();
    });
  }

  Future<void> _saveQuizSession() async {
    if (widget.historyService == null) return;

    try {
      final completedAt = DateTime.now();
      final timeTaken = completedAt.difference(_quizStartTime);
      final percentage = (_score / _currentQuizQuestions.length * 100);
      
      String performanceLevel;
      if (percentage >= 80) {
        performanceLevel = 'Excellent';
      } else if (percentage >= 60) {
        performanceLevel = 'Good';
      } else {
        performanceLevel = 'Needs Work';
      }

      final session = QuizSession(
        id: 'quiz_${completedAt.millisecondsSinceEpoch}',
        completedAt: completedAt,
        score: _score,
        totalQuestions: _currentQuizQuestions.length,
        correctAnswers: _score,
        incorrectAnswers: _currentQuizQuestions.length - _score,
        timeTaken: timeTaken,
        percentage: percentage,
        performanceLevel: performanceLevel,
        questionResults: _questionResults,
      );

      await widget.historyService!.addSession(session);
    } catch (e) {
      // Handle error silently, don't interrupt user experience
      // Could add logging service here in production
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quizCompleted) {
      return _buildResultsScreen();
    }

    final currentQuestion = _currentQuizQuestions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _currentQuizQuestions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wi-Fi Security Quiz'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_currentQuizQuestions.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Score: $_score',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ],
            ),
          ),

          // Question and answers
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      currentQuestion.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Answer options
                  ...List.generate(currentQuestion.options.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAnswerOption(
                        index,
                        currentQuestion.options[index],
                        currentQuestion.correctAnswerIndex,
                      ),
                    );
                  }),

                  // Explanation (shown after answering)
                  if (_hasAnswered) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                              ? Colors.green[300]!
                              : Colors.red[300]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? Colors.green[600]
                                    : Colors.red[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? 'Correct!'
                                    : 'Incorrect',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentQuestion.explanation,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Next button
          if (_hasAnswered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < _currentQuizQuestions.length - 1 ? 'Next Question' : 'View Results',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildAnswerOption(int index, String option, int correctIndex) {
    Color? backgroundColor;
    Color? borderColor;
    Color? textColor;

    if (_hasAnswered) {
      if (index == correctIndex) {
        backgroundColor = Colors.green[100];
        borderColor = Colors.green[400];
        textColor = Colors.green[800];
      } else if (index == _selectedAnswerIndex) {
        backgroundColor = Colors.red[100];
        borderColor = Colors.red[400];
        textColor = Colors.red[800];
      }
    } else if (_selectedAnswerIndex == index) {
      backgroundColor = AppColors.primary.withValues(alpha: 0.1);
      borderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor ?? Colors.transparent,
                border: Border.all(
                  color: borderColor ?? Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor ?? Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor ?? Colors.black87,
                  fontWeight: _hasAnswered && index == correctIndex 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final percentage = (_score / _currentQuizQuestions.length * 100).round();
    String resultMessage;
    Color resultColor;
    IconData resultIcon;

    if (percentage >= 80) {
      resultMessage = "Excellent! You're well-versed in Wi-Fi security.";
      resultColor = Colors.green;
      resultIcon = Icons.emoji_events;
    } else if (percentage >= 60) {
      resultMessage = "Good job! You have a solid understanding of Wi-Fi security.";
      resultColor = Colors.blue;
      resultIcon = Icons.thumb_up;
    } else {
      resultMessage = "Keep learning! Review the educational materials to improve your Wi-Fi security knowledge.";
      resultColor = Colors.orange;
      resultIcon = Icons.school;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Results'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              resultIcon,
              size: 80,
              color: resultColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Quiz Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Score',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score/${_currentQuizQuestions.length}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: resultColor,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: resultColor,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: resultColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                resultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _restartQuiz,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Retake Quiz',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue Learning',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}