import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';
import 'glucose_screen.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dexcom Glucose Viewer',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? latestBloodSugar;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    checkDexcomConnection();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    linkStream.listen((String? link) {
      if (link != null && link.contains("code=")) {
        String authCode = Uri.parse(link).queryParameters["code"]!;
        exchangeCodeForToken(authCode);
      }
    }, onError: (err) {
      print("❌ Error handling deep link: $err");
    });
  }

  Future<void> exchangeCodeForToken(String authCode) async {
    const String clientId = "NRa7mw9Pr1zRN5774LCg5QO78pYTIxZC";
    const String clientSecret = "D9Xos0uceEDFv873";
    const String redirectUri = "com.example.dexcomflutter://callback";

    final Uri tokenUri = Uri.parse("https://sandbox-api.dexcom.com/v2/oauth2/token");

    final response = await http.post(
      tokenUri,
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        "client_id": clientId,
        "client_secret": clientSecret,
        "code": authCode,
        "grant_type": "authorization_code",
        "redirect_uri": redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await storage.write(key: "access_token", value: data["access_token"]);
      setState(() {
        isConnected = true;
      });
      fetchLatestBloodSugar(data["access_token"]);
    } else {
      print("❌ Error exchanging code: ${response.body}");
    }
  }

  Future<void> checkDexcomConnection() async {
    final accessToken = await storage.read(key: "access_token");
    if (accessToken != null) {
      setState(() {
        isConnected = true;
      });
      fetchLatestBloodSugar(accessToken);
    }
  }

  Future<void> disconnectFromDexcom() async {
    await storage.delete(key: "access_token");
    setState(() {
      isConnected = false;
      latestBloodSugar = null;
    });
    print("🔌 Disconnected from Dexcom");
  }

  Future<void> loginWithDexcom() async {
    const String clientId = "NRa7mw9Pr1zRN5774LCg5QO78pYTIxZC";
    const String redirectUri = "com.example.dexcomflutter://callback";
    const String authUrl =
        "https://sandbox-api.dexcom.com/v2/oauth2/login?client_id=$clientId&redirect_uri=$redirectUri&response_type=code&scope=offline_access%20egvs";

    if (await canLaunchUrl(Uri.parse(authUrl))) {
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
    } else {
      print("❌ Could not launch Dexcom Login URL");
    }
  }

  Future<void> fetchLatestBloodSugar(String token) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime startTime = now.subtract(const Duration(hours: 24));

    final String formattedStartTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(startTime);
    final String formattedEndTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now);

    final Uri glucoseUri = Uri.parse(
      "https://sandbox-api.dexcom.com/v3/users/self/egvs?startDate=$formattedStartTime&endDate=$formattedEndTime",
    );

    final response = await http.get(
      glucoseUri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["records"].isNotEmpty) {
        setState(() {
          latestBloodSugar = "${data["records"].first["value"]} mg/dL";
        });
      }
    } else {
      print("❌ Error fetching glucose data: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dexcom Connection")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isConnected)
              Column(
                children: [
                  const Text("✅ Connected to Dexcom",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    latestBloodSugar != null
                        ? "Your blood sugar: $latestBloodSugar"
                        : "Fetching latest glucose data...",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const GlucoseScreen()),
                      );
                    },
                    child: const Text("View Glucose Data"),
                  ),
                  ElevatedButton(
                    onPressed: disconnectFromDexcom,
                    child: const Text("Disconnect from Dexcom"),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: loginWithDexcom,
                child: const Text("Connect to Dexcom"),
              ),
          ],
        ),
      ),
    );
  }
}