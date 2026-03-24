import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, snapshot) {
            bool isOffline = false;
            if (snapshot.hasData) {
              final dynamic connectionData = snapshot.data;
              // Safely handle both older (v5) and newer (v6+) versions of connectivity_plus
              if (connectionData is List) {
                isOffline = connectionData.contains(ConnectivityResult.none);
              } else {
                isOffline = connectionData == ConnectivityResult.none;
              }
            }
            
            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: isOffline
                  ? Material(
                      elevation: 4,
                      child: Container(
                        width: double.infinity,
                        color: Colors.redAccent.shade700,
                        padding: const EdgeInsets.only(top: 40, bottom: 8), // Padding for status bar
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'You are offline. Waiting for connection...',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}
