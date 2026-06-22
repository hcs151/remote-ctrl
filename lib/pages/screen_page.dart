import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../p2p_connection.dart';

/// 远程屏幕查看页面（主控端）
class ScreenPage extends StatefulWidget {
  final P2PConnection p2p;

  const ScreenPage({super.key, required this.p2p});

  @override
  State<ScreenPage> createState() => _ScreenPageState();
}

class _ScreenPageState extends State<ScreenPage> {
  final _videoRenderer = RTCVideoRenderer();
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _videoRenderer.initialize();
    final stream = widget.p2p.remoteStream;
    if (stream != null) {
      _videoRenderer.srcObject = stream;
      setState(() => _videoReady = true);
    }
  }

  @override
  void dispose() {
    _videoRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程屏幕'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: () {
              widget.p2p.disconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _videoReady
          ? InteractiveViewer(
              child: RTCVideoView(_videoRenderer),
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          // 全屏切换
          if (MediaQuery.of(context).orientation == Orientation.portrait) {
            // 触发全屏逻辑（依赖设备orientation）
          }
        },
        child: const Icon(Icons.fullscreen),
      ),
    );
  }
}
