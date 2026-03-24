import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> receiverData;
  
  const ChatScreen({super.key, required this.receiverData});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate a unique chat room ID for these two users
  String _getChatRoomId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); // Sorting ensures the ID is identical no matter who opens the chat
    return ids.join('_');
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      String message = _messageController.text.trim();
      _messageController.clear(); // Clear instantly for better UX

      String currentUid = _auth.currentUser!.uid;
      String currentEmail = _auth.currentUser!.email!;
      String receiverUid = widget.receiverData['uid'];

      String chatRoomId = _getChatRoomId(currentUid, receiverUid);

      try {
        // Save message exactly to the shared chat room
        await _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .add({
          'senderId': currentUid,
          'senderEmail': currentEmail,
          'receiverId': receiverUid,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')),
          );
        }
      }
    }
  }

  Widget _buildMessageList() {
    String currentUid = _auth.currentUser!.uid;
    String chatRoomId = _getChatRoomId(currentUid, widget.receiverData['uid']);

    return StreamBuilder<QuerySnapshot>(
      // Listen to this specific chat room and order by time
      stream: _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading messages.'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Say hi! 👋',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            bool isMe = data['senderId'] == currentUid;
            Timestamp? timestamp = data['timestamp'] as Timestamp?;

            return _buildMessageBubble(data['message'], isMe, timestamp);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(String message, bool isMe, Timestamp? timestamp) {
    String timeString = "";
    if (timestamp != null) {
      DateTime dateTime = timestamp.toDate();
      timeString = DateFormat('hh:mm a').format(dateTime); // e.g. 10:30 AM
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(left: 16, right: 16, top: 8),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF2575FC) : Colors.grey.shade200,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
          if (timeString.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 4),
              child: Text(
                timeString,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF2575FC),
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(widget.receiverData['email'] ?? 'Chat'),
        backgroundColor: const Color(0xFF2575FC),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
