import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PulseType { chat, sms, weather }

class PulseEvent {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final PulseType type;
  final Map<String, dynamic> metadata;

  PulseEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.type,
    this.metadata = const {},
  });
}

class PulseService {
  final _eventController = StreamController<List<PulseEvent>>.broadcast();
  Stream<List<PulseEvent>> get pulseStream => _eventController.stream;

  List<PulseEvent> _allEvents = [];

  void start() {
    _listenToChats();
    _listenToSMS();
    _fetchWeather();
    // Refresh weather every 10 minutes
    Timer.periodic(const Duration(minutes: 10), (_) => _fetchWeather());
  }

  void _listenToChats() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      final chatEvents = snapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) {
            final data = doc.data();
            return PulseEvent(
              id: doc.id,
              title: data['email'] ?? 'New Chat',
              subtitle: 'Tap to message',
              timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              type: PulseType.chat,
              metadata: data,
            );
          }).toList();
      
      _updateEvents(PulseType.chat, chatEvents);
    });
  }

  void _listenToSMS() async {
    final telephony = Telephony.instance;
    bool? permissionsGranted = await telephony.requestSmsPermissions;
    if (permissionsGranted == true) {
      // Get initial SMS history
      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ID, SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final smsEvents = messages.map((sms) {
        return PulseEvent(
          id: 'sms_${sms.id}',
          title: sms.address ?? 'Unknown SMS',
          subtitle: sms.body ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
          type: PulseType.sms,
        );
      }).toList();

      _updateEvents(PulseType.sms, smsEvents);
    }
  }

  Future<void> _fetchWeather() async {
    try {
      // Using Open-Meteo (No API key required for basic usage)
      final response = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=28.6139&longitude=77.2090&current_weather=true'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.statusCode == 200 ? response.body : '{}');
        final current = data['current_weather'];
        
        final weatherEvent = PulseEvent(
          id: 'weather_status',
          title: 'Live Weather Update',
          subtitle: '${current['temperature']}°C - Wind: ${current['windspeed']} km/h',
          timestamp: DateTime.now(),
          type: PulseType.weather,
        );

        _updateEvents(PulseType.weather, [weatherEvent]);
      }
    } catch (e) {
      print('Weather Fetch Error: $e');
    }
  }

  void _updateEvents(PulseType type, List<PulseEvent> newEvents) {
    // Remove old events of this type
    _allEvents.removeWhere((e) => e.type == type);
    // Add new ones
    _allEvents.addAll(newEvents);
    // Sort by timestamp
    _allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    _eventController.add(List.from(_allEvents));
  }

  void dispose() {
    _eventController.close();
  }
}
