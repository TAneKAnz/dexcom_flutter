import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class GlucoseScreen extends StatefulWidget {
  const GlucoseScreen({super.key});

  @override
  State<GlucoseScreen> createState() => _GlucoseScreenState();
}

class _GlucoseScreenState extends State<GlucoseScreen> {
  final String glucoseUrl = "https://sandbox-api.dexcom.com/v2/users/self/glucose";
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> glucoseData = [];
  bool isLoading = true;

  Future<void> fetchGlucoseData() async {
    final String? accessToken = await storage.read(key: "access_token");
    if (accessToken == null) return;

    DateTime now = DateTime.now().toUtc();
    DateTime startTime = now.subtract(const Duration(hours: 24));

    String formattedStartTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(startTime);
    String formattedEndTime = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now);

    final Uri glucoseUri = Uri.parse(
      "https://sandbox-api.dexcom.com/v3/users/self/egvs?startDate=$formattedStartTime&endDate=$formattedEndTime", // ✅ Updated to v3
    );

    final response = await http.get(
      glucoseUri,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        glucoseData = List<Map<String, dynamic>>.from(data["records"]);
        isLoading = false;
      });
    } else {
      print("❌ Error fetching glucose data: ${response.body}");
      setState(() {
        isLoading = false;
      });
    }
  }





  @override
  void initState() {
    super.initState();
    fetchGlucoseData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Glucose Data")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : glucoseData.isEmpty
              ? const Center(child: Text("No glucose data available"))
              : ListView.builder(
                  itemCount: glucoseData.length,
                  itemBuilder: (context, index) {
                    final data = glucoseData[index];

                    String timestamp = data.containsKey('timestamp')
                        ? data['timestamp']
                        : data.containsKey('systemTime')
                            ? data['systemTime']
                            : data.containsKey('displayTime')
                                ? data['displayTime']
                                : 'Unknown Time';

                    return ListTile(
                      title: Text("Blood Sugar: ${data['value']} mg/dL"),
                      subtitle: Text("Time: $timestamp"),
                    );
                  },
                ),
    );
  }
}
