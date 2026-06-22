import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

/// P2P连接管理器 - WebRTC + 信令
class P2PConnection {
  // ======== 服务配置 ========
  static const _signalServer = 'http://xs.free.je/signal.php';
  static const _turnUrl = 'turn:openrelay.metered.ca:80';
  static const _turnUser = 'openrelayproject';
  static const _turnPass = 'openrelayproject';

  // ======== WebRTC ========
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _roomId;
  int _side = 0; // 0=主控端, 1=被控端

  // ======== 回调 ========
  Function(MediaStream stream)? onRemoteStream;
  Function(String state)? onStateChange;
  Function(String error)? onError;

  /// 初始化本地媒体
  Future<void> initLocalStream({bool screen = false}) async {
    if (screen) {
      _localStream = await navigator.mediaDevices.getDisplayMedia({});
    } else {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': true,
        'audio': true,
      });
    }
  }

  /// 创建PeerConnection
  Future<void> _createPC() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {
          'urls': _turnUrl,
          'username': _turnUser,
          'credential': _turnPass,
        },
      ],
      'iceTransportPolicy': 'all',
    };

    _pc = await createPeerConnection(config);

    // 本地流加入
    if (_localStream != null) {
      _pc!.addStream(_localStream!);
    }

    // ICE候选
    _pc!.onIceCandidate = (candidate) {
      _sendSignal('candidate', jsonEncode({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }));
    };

    // 远端流
    _pc!.onAddStream = (stream) {
      _remoteStream = stream;
      onRemoteStream?.call(stream);
    };

    // 连接状态
    _pc!.onConnectionState = (state) {
      onStateChange?.call('连接: $state');
    };
  }

  // ======== 信令通信 ========

  Future<Map<String, dynamic>> _sendSignal(String action,
      [String? data]) async {
    final uri = Uri.parse(_signalServer).replace(queryParameters: {
      'action': action,
      'room': _roomId ?? '',
      if (data != null) 'data': data,
      if (action == 'candidate' || action == 'get_candidates')
        'side': _side.toString(),
    });

    final resp = await http.get(uri);
    return jsonDecode(resp.body);
  }

  // ======== 主控端：发起连接 ========

  Future<void> connect(String roomId) async {
    _roomId = roomId;
    _side = 0;

    await _createPC();
    onStateChange?.call('创建房间...');

    final createRes = await _sendSignal('create');
    if (createRes['ok'] != true) {
      onError?.call('创建房间失败');
      return;
    }

    // 创建Offer
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await _sendSignal('offer', jsonEncode({
      'sdp': offer.sdp,
      'type': offer.type,
    }));

    onStateChange?.call('等待被控端加入...');

    // 轮询Answer
    _pollSignal();
  }

  void _pollSignal() async {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        // 拉取Answer
        final answerRes = await _sendSignal('get_answer');
        if (answerRes['answer'] != null) {
          timer.cancel();
          final answerData = jsonDecode(answerRes['answer']);
          await _pc!.setRemoteDescription(RTCSessionDescription(
            answerData['sdp'],
            answerData['type'],
          ));
          onStateChange?.call('已连接 ✓');
        }

        // 拉取远端候选
        final candRes = await _sendSignal('get_candidates');
        final candidates = candRes['candidates'] ?? [];
        for (var c in candidates) {
          final cObj = jsonDecode(c);
          await _pc!.addCandidate(RTCIceCandidate(
            cObj['candidate'],
            cObj['sdpMid'],
            cObj['sdpMLineIndex'],
          ));
        }
      } catch (e) {
        // 继续轮询
      }
    });
  }

  // ======== 被控端：等待连接 ========

  Future<void> waitConnect(String roomId) async {
    _roomId = roomId;
    _side = 1;

    await _createPC();
    onStateChange?.call('等待主控端...');

    // 轮询Offer
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final offerRes = await _sendSignal('get_offer');
        if (offerRes['offer'] != null) {
          timer.cancel();
          final offerData = jsonDecode(offerRes['offer']);
          await _pc!.setRemoteDescription(RTCSessionDescription(
            offerData['sdp'],
            offerData['type'],
          ));

          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);

          await _sendSignal('answer', jsonEncode({
            'sdp': answer.sdp,
            'type': answer.type,
          }));

          onStateChange?.call('已连接 ✓');

          // 持续拉取候选
          _pollCandidates();
        }
      } catch (e) {
        // 继续轮询
      }
    });
  }

  void _pollCandidates() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final candRes = await _sendSignal('get_candidates');
        final candidates = candRes['candidates'] ?? [];
        for (var c in candidates) {
          final cObj = jsonDecode(c);
          await _pc!.addCandidate(RTCIceCandidate(
            cObj['candidate'],
            cObj['sdpMid'],
            cObj['sdpMLineIndex'],
          ));
        }
      } catch (_) {}
    });
  }

  // ======== 获取远端视频流 ========

  MediaStream? get remoteStream => _remoteStream;

  // ======== 断开 ========

  Future<void> disconnect() async {
    await _sendSignal('close');
    await _pc?.close();
    _pc = null;
    _localStream?.dispose();
    _remoteStream?.dispose();
    onStateChange?.call('已断开');
  }
}
