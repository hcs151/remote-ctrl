import 'package:flutter/material.dart';
import '../p2p_connection.dart';
import 'screen_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _roomCtrl = TextEditingController();
  final _p2p = P2PConnection();
  String _status = '就绪';
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _p2p.onStateChange = (s) => setState(() => _status = s);
    _p2p.onError = (e) => setState(() => _status = '错误: $e');
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _p2p.disconnect();
    super.dispose();
  }

  /// 主控端：连接到被控端
  void _startControl() async {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) return;

    setState(() => _status = '正在连接...');
    await _p2p.connect(room);

    if (_p2p.remoteStream == null) {
      // 等一会儿看流过来没
      await Future.delayed(const Duration(seconds: 3));
    }

    if (_p2p.remoteStream != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScreenPage(p2p: _p2p),
        ),
      );
    }
  }

  /// 被控端：等待被控
  void _startBeControlled() async {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) return;

    setState(() => _status = '等待被控...');
    await _p2p.initLocalStream(screen: true);
    await _p2p.waitConnect(room);
    setState(() => _connected = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程控制'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'P2P 远程控制',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: '房间号',
                hintText: '输入相同的房间号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startControl,
                    icon: const Icon(Icons.touch_app),
                    label: const Text('控制对方'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startBeControlled,
                    icon: const Icon(Icons.screen_share),
                    label: const Text('被对方控'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _connected ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: _connected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '服务器: xs.free.je | TURN: OpenRelay',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
