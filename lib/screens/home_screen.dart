import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/pulse_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PulseService _pulseService = PulseService();

  @override
  void initState() {
    super.initState();
    _pulseService.start();
  }

  @override
  void dispose() {
    _pulseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101214), // Modern dark theme
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF2575FC),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFF2575FC), blurRadius: 10, spreadRadius: 2),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('Real-Time Pulse', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PulseEvent>>(
        stream: _pulseService.pulseStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2575FC)),
            );
          }

          final events = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildPulseCard(context, event);
            },
          );
        },
      ),
    );
  }

  Widget _buildPulseCard(BuildContext context, PulseEvent event) {
    IconData icon;
    Color color;

    switch (event.type) {
      case PulseType.chat:
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFF2575FC);
        break;
      case PulseType.sms:
        icon = Icons.sms_rounded;
        color = const Color(0xFF6A11CB);
        break;
      case PulseType.weather:
        icon = Icons.cloud_rounded;
        color = const Color(0xFFFF9800);
        break;
    }

    return Card(
      color: const Color(0xFF1D2024),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          event.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            event.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        trailing: Text(
          _formatTime(event.timestamp),
          style: const TextStyle(color: Colors.white24, fontSize: 11),
        ),
        onTap: () {
          if (event.type == PulseType.chat) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(receiverData: event.metadata),
              ),
            );
          }
          // Add logic for SMS or Weather details if needed
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}';
  }
}
