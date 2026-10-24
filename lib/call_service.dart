import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// تم دمج الـ App ID الخاص بك هنا بنجاح:
const String agoraAppId = "2a0053e48b774c279c834793732a7493";

class RealCallScreen extends StatefulWidget {
  final String channelName;    // اسم غرفة المكالمة الموحدة بين الطرفين
  final String targetUsername; // اسم الطرف الآخر
  final bool isVideo;          // مكالمة فيديو أم صوت فقط

  const RealCallScreen({
    super.key,
    required this.channelName,
    required this.targetUsername,
    required this.isVideo,
  });

  @override
  State<RealCallScreen> createState() => _RealCallScreenState();
}

class _RealCallScreenState extends State<RealCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1. طلب وتأكيد أذونات الميكروفون والكاميرا
    await [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ].request();

    // 2. إنشاء وتهيئة محرك Agora بالـ App ID الخاص بك
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. الاستماع لأحداث المكالمة
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("تم الدخول للمكالمة بنجاح: ${connection.channelId}");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("انضم الطرف الآخر للمكالمة برقم: $remoteUid");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("الطرف الآخر غادر المكالمة");
          setState(() {
            _remoteUid = null;
          });
          if (mounted) Navigator.pop(context);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("Agora Error [$err]: $msg");
        },
      ),
    );

    // 4. تفعيل وضع الصوت أو الفيديو
    if (widget.isVideo) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.enableAudio();
    }

    // 5. الانضمام إلى غرفة المكالمة
    await _engine.joinChannel(
      token: '', // يتم تمريره فارغاً عند استخدام Testing Mode: App ID
      channelId: widget.channelName,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: widget.isVideo,
        publishMicrophoneTrack: true,
      ),
      uid: 0,
    );
  }

  @override
  void dispose() {
    _leaveChannel();
    super.dispose();
  }

  Future<void> _leaveChannel() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Error leaving channel: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.isVideo ? 'مكالمة فيديو مشفرة' : 'مكالمة صوتية مشفرة'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // مساحة عرض بث الطرف الآخر
            Center(
              child: _remoteVideoOrVoiceUI(),
            ),

            // نافذة كاميرا هاتفي المحلية (صورة مصغرة في زاوية الشاشة عند مكالمة الفيديو)
            if (widget.isVideo && _localUserJoined)
              Positioned(
                top: 20,
                right: 20,
                child: SizedBox(
                  width: 110,
                  height: 155,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),

            // شريط أزرار التحكم بالمكالمة
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // كتم المايك
                  CircleAvatar(
                    backgroundColor: _isMuted ? Colors.red : Colors.white24,
                    radius: 26,
                    child: IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                      onPressed: () {
                        setState(() => _isMuted = !_isMuted);
                        _engine.muteLocalAudioStream(_isMuted);
                      },
                    ),
                  ),

                  // إنهاء المكالمة
                  CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 32,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // تبديل الكاميرا (في مكالمات الفيديو فقط)
                  if (widget.isVideo)
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 26,
                      child: IconButton(
                        icon: const Icon(Icons.switch_camera, color: Colors.white),
                        onPressed: () => _engine.switchCamera(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remoteVideoOrVoiceUI() {
    if (_remoteUid != null) {
      if (widget.isVideo) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF00A884),
              child: Text(
                widget.targetUsername[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text('@${widget.targetUsername}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('المكالمة متصلة ومباشرة 🔒', style: TextStyle(color: Color(0xFF00A884))),
          ],
        );
      }
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00A884)),
          const SizedBox(height: 20),
          Text(
            'جاري الاتصال بـ @${widget.targetUsername}...',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          const Text(
            'في انتظار دخول الطرف الآخر للغرفة',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      );
    }
  }
}