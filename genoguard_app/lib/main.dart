import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: HealthScreen());
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  String status = 'Checking...';

  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    try {
      final r = await http.get(Uri.parse('http://localhost:3000/health'));
      final ok = jsonDecode(r.body)['status'] == 'ok';
      setState(() => status = ok ? 'API OK' : 'API error');
    } catch (e) {
      setState(() => status = 'Cannot reach API');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(status, style: const TextStyle(fontSize: 24))),
  );
}
