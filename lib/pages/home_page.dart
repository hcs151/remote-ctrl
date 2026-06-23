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

  void _startControl() async {
    final room = _roomCtrl.text.trim();
    if (room.isEmpty) return;
    setState(() => _status = '正在连接...');
    final connected = await _p2p.connect(room);
    if (connected && mounted) {
      setState(() => _connected = true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScreenPage(p2p: _p2p),
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _connected = false);
          _p2p.disconnect();
        }
      });
    } else if (mounted) {
      setState(() => _status = '连接失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程控制'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: '房间号',
                hintText: '输入房间号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _connected ? null : _startControl,
              icon: const Icon(Icons.screen_share),
              label: const Text('开始控制'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(_status, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
