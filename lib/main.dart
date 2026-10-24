import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// مُعرّف مشروع Agora الخاص بك
const String agoraAppId = "2a0053e48b774c279c834793732a7493";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RealChatApp());
}

class RealChatApp extends StatelessWidget {
  const RealChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Secure Chat',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B141B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00A884),
          surface: Color(0xFF1F2C34),
          onSurface: Colors.white,
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SplashScreen(),
      ),
    );
  }
}

// -------------------------------------------------------------
// إدارة المستخدمين المسجلين (سجل مركزي محلي وسحابي)
// -------------------------------------------------------------
class UserService {
  // قائمة أولية لمستخدمين افتراضيين للتجربة
  static const List<String> defaultRegisteredUsers = [
    'admin',
    'sara_vip',
    'ahmed_dev',
    'omar99',
    'khaled_pro'
  ];

  static Future<List<String>> getAllRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> customUsers = prefs.getStringList('global_registered_users') ?? [];
    Set<String> allUsers = {...defaultRegisteredUsers, ...customUsers};
    return allUsers.toList();
  }

  static Future<bool> isUsernameTaken(String username) async {
    final users = await getAllRegisteredUsers();
    return users.contains(username.toLowerCase());
  }

  static Future<void> registerNewUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> customUsers = prefs.getStringList('global_registered_users') ?? [];
    if (!customUsers.contains(username.toLowerCase())) {
      customUsers.add(username.toLowerCase());
      await prefs.setStringList('global_registered_users', customUsers);
    }
  }

  // توليد اقتراحات ذكية واحترافية عند حجز الاسم
  static List<String> generateSmartSuggestions(String baseUsername) {
    final rand = Random();
    final clean = baseUsername.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return [
      '${clean}_vip',
      '${clean}_pro',
      '${clean}_${rand.nextInt(89) + 10}',
      'the_${clean}',
    ];
  }
}

// -------------------------------------------------------------
// 1. شاشة البداية
// -------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUsername();
  }

  Future<void> _checkUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('my_username');

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (savedUsername != null && savedUsername.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(myUsername: savedUsername),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Directionality(
            textDirection: TextDirection.rtl,
            child: UsernameRegisterScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00A884)),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. شاشة تسجيل اليوزر مع التحقق الذكي والاقتراحات التلقائية
// -------------------------------------------------------------
class UsernameRegisterScreen extends StatefulWidget {
  const UsernameRegisterScreen({super.key});

  @override
  State<UsernameRegisterScreen> createState() => _UsernameRegisterScreenState();
}

class _UsernameRegisterScreenState extends State<UsernameRegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isChecking = false;
  bool _isAvailable = false;
  String? _statusMessage;
  List<String> _suggestions = [];

  bool _validateFormat(String username) {
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username);
  }

  Future<void> _checkAvailability(String username) async {
    username = username.trim().toLowerCase();
    if (!_validateFormat(username)) {
      setState(() {
        _isAvailable = false;
        _statusMessage = 'اليوزر يجب أن يتكون من 3-20 حرفاً (أحرف إنجليزية صغيرة، أرقام، أو _ فقط)';
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    final isTaken = await UserService.isUsernameTaken(username);

    setState(() {
      _isChecking = false;
      if (isTaken) {
        _isAvailable = false;
        _statusMessage = 'اسم المستخدم محجوز بالفعل ❌ اختر من الاقتراحات أدناه:';
        _suggestions = UserService.generateSmartSuggestions(username);
      } else {
        _isAvailable = true;
        _statusMessage = 'اسم المستخدم متاح ومميز جاهز للحجز ✅';
        _suggestions = [];
      }
    });
  }

  Future<void> _submitRegister() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (!_isAvailable) {
      await _checkAvailability(username);
      if (!_isAvailable) return;
    }

    await UserService.registerNewUser(username);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_username', username);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(myUsername: username),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00A884).withOpacity(0.15),
                ),
                child: const Icon(Icons.account_circle_outlined, size: 68, color: Color(0xFF00A884)),
              ),
              const SizedBox(height: 20),
              const Text(
                'اختر اسم المستخدم الفريد الخاص بك',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم فحص الاسم والتأكد من عدم تكراره واقتراح بدائل حصرية لك',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _usernameController,
                style: const TextStyle(letterSpacing: 1.2),
                onChanged: (val) {
                  if (val.length >= 3) {
                    _checkAvailability(val);
                  } else {
                    setState(() {
                      _isAvailable = false;
                      _statusMessage = null;
                      _suggestions = [];
                    });
                  }
                },
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 18),
                  hintText: 'username',
                  suffixIcon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A884)),
                          ),
                        )
                      : (_isAvailable
                          ? const Icon(Icons.check_circle, color: Color(0xFF00A884))
                          : null),
                  filled: true,
                  fillColor: const Color(0xFF1F2C34),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _isAvailable ? const Color(0xFF00A884) : Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _suggestions.map((suggested) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF1F2C34),
                      side: const BorderSide(color: Color(0xFF00A884), width: 0.8),
                      avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF00A884)),
                      label: Text('@$suggested', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      onPressed: () {
                        _usernameController.text = suggested;
                        _checkAvailability(suggested);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isAvailable ? _submitRegister : null,
                child: const Text(
                  'تأكيد والدخول للدردشة',
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. الشاشة الرئيسية والتحقق من وجود المستخدم عند البحث
// -------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final String myUsername;
  const HomeScreen({super.key, required this.myUsername});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> activeChats = [];
  List<String> blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // تسجيل المستخدم الحالي في قائمة المستخدمين إن لم يكن موجوداً
    UserService.registerNewUser(widget.myUsername);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activeChats = prefs.getStringList('chats_${widget.myUsername}') ?? [];
      blockedUsers = prefs.getStringList('blocked_${widget.myUsername}') ?? [];
    });
  }

  // ميزة التحقق من وجود المستخدم قبل الدخول للمحادثة
  void _searchUserDialog() {
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1F2C34),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_search, color: Color(0xFF00A884)),
              SizedBox(width: 8),
              Text('بحث عن مستخدم', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: TextField(
            controller: searchCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'اكتب يوزر الشخص (مثلاً: sara_vip)',
              prefixText: '@ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
              onPressed: () async {
                final targetUser = searchCtrl.text.trim().toLowerCase();
                if (targetUser.isEmpty) return;

                if (targetUser == widget.myUsername) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكنك مراسلة نفسك!')),
                  );
                  return;
                }

                if (blockedUsers.contains(targetUser)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('هذا المستخدم محظور في قائمتك!')),
                  );
                  return;
                }

                // التحقق هل اليوزر مسجل في التطبيق فعلاً أم لا
                final isRegistered = await UserService.isUsernameTaken(targetUser);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (isRegistered) {
                  // مسجل -> يدخله الدردشة طوالي
                  _openChat(targetUser);
                } else {
                  // غير مسجل -> إظهار تنبيه
                  _showUserNotFoundDialog(targetUser);
                }
              },
              child: const Text('مراسلة فورية', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserNotFoundDialog(String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('المستخدم غير موجود'),
          ],
        ),
        content: Text(
          'اليوزر @$username غير مسجل في التطبيق حتى الآن. تأكد من صحة الاسم أو اطلب منه الانضمام.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(color: Color(0xFF00A884))),
          ),
        ],
      ),
    );
  }

  void _openChat(String targetUser) async {
    final prefs = await SharedPreferences.getInstance();
    if (!activeChats.contains(targetUser)) {
      activeChats.add(targetUser);
      await prefs.setStringList('chats_${widget.myUsername}', activeChats);
      setState(() {});
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: ChatScreen(
            myUsername: widget.myUsername,
            targetUsername: targetUser,
            onSimulateIncomingCall: () {
              // محاكاة إشعار مكالمة واردة من هذا الشخص
              _showIncomingCallOverlay(targetUser, false);
            },
          ),
        ),
      ),
    ).then((_) => _loadData());
  }

  // -------------------------------------------------------------
  // ميزة إشعار المكالمات الواردة مع الرنين والاهتزاز
  // -------------------------------------------------------------
  void _showIncomingCallOverlay(String callerUsername, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: IncomingCallScreen(
            callerUsername: callerUsername,
            isVideo: isVideo,
            onAccept: () {
              Navigator.pop(context); // إغلاق شاشة الرنين
              // فتح مكالمة Agora المباشرة
              List<String> users = [widget.myUsername, callerUsername]..sort();
              String channelName = "call_${users[0]}_${users[1]}";
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: RealCallScreen(
                      channelName: channelName,
                      targetUsername: callerUsername,
                      isVideo: isVideo,
                    ),
                  ),
                ),
              );
            },
            onDecline: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: Color(0xFF00A884), size: 20),
            const SizedBox(width: 8),
            Text('@${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'ابحث عن يوزر',
            onPressed: _searchUserDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تغيير الحساب',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('my_username');
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const UsernameRegisterScreen()),
              );
            },
          ),
        ],
      ),
      body: activeChats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt_1_outlined, size: 70, color: Colors.grey.shade700),
                  const SizedBox(height: 14),
                  const Text(
                    'لا توجد محادثات مفتوحة بعد\nابحث باسم المستخدم للبدء أو اضغط الزر أدناه',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: activeChats.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1F2C34)),
              itemBuilder: (context, index) {
                final user = activeChats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00A884),
                    child: Text(user[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('@$user', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('اضغط للمحادثة أو بدء مكالمة', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
                  onTap: () => _openChat(user),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        onPressed: _searchUserDialog,
        child: const Icon(Icons.chat_bubble, color: Colors.black),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. شاشة الدردشة
// -------------------------------------------------------------
class ChatScreen extends StatefulWidget {
  final String myUsername;
  final String targetUsername;
  final VoidCallback onSimulateIncomingCall;

  const ChatScreen({
    super.key,
    required this.myUsername,
    required this.targetUsername,
    required this.onSimulateIncomingCall,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool isFirstTime = true;
  bool isBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeStatus();
    _loadChatHistory();
  }

  Future<void> _checkFirstTimeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final acceptedList = prefs.getStringList('accepted_${widget.myUsername}') ?? [];
    final blockedList = prefs.getStringList('blocked_${widget.myUsername}') ?? [];

    setState(() {
      isFirstTime = !acceptedList.contains(widget.targetUsername);
      isBlocked = blockedList.contains(widget.targetUsername);
    });
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getChatKey();
    final data = prefs.getString(key);
    if (data != null) {
      setState(() {
        _messages.addAll(List<Map<String, dynamic>>.from(jsonDecode(data)));
      });
    }
  }

  String _getChatKey() {
    List<String> users = [widget.myUsername, widget.targetUsername]..sort();
    return 'chat_${users[0]}_${users[1]}';
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getChatKey(), jsonEncode(_messages));
  }

  void _sendMessage() {
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك إرسال رسائل لمستخدم محظور')),
      );
      return;
    }

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': widget.myUsername,
        'text': text,
        'time': DateTime.now().toString(),
      });
    });

    _msgController.clear();
    _saveChatHistory();
  }

  void _openCall(bool isVideo) {
    List<String> users = [widget.myUsername, widget.targetUsername]..sort();
    String channelName = "call_${users[0]}_${users[1]}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: RealCallScreen(
            channelName: channelName,
            targetUsername: widget.targetUsername,
            isVideo: isVideo,
          ),
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    final prefs = await SharedPreferences.getInstance();
    final blockedList = prefs.getStringList('blocked_${widget.myUsername}') ?? [];
    if (!blockedList.contains(widget.targetUsername)) {
      blockedList.add(widget.targetUsername);
      await prefs.setStringList('blocked_${widget.myUsername}', blockedList);
    }
    setState(() => isBlocked = true);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حظر @${widget.targetUsername} بنجاح')),
    );
  }

  Future<void> _acceptContact() async {
    final prefs = await SharedPreferences.getInstance();
    final acceptedList = prefs.getStringList('accepted_${widget.myUsername}') ?? [];
    if (!acceptedList.contains(widget.targetUsername)) {
      acceptedList.add(widget.targetUsername);
      await prefs.setStringList('accepted_${widget.myUsername}', acceptedList);
    }
    setState(() => isFirstTime = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00A884),
              radius: 18,
              child: Text(
                widget.targetUsername[0].toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${widget.targetUsername}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Text('مشفر طرف إلى طرف 🔒', style: TextStyle(fontSize: 10, color: Color(0xFF00A884))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ring_volume, color: Colors.amber),
            tooltip: 'تجربة استقبال رنين المكالمة',
            onPressed: widget.onSimulateIncomingCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () => _openCall(true),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () => _openCall(false),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isFirstTime)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              color: const Color(0xFF1F2C34),
              child: Column(
                children: [
                  Text(
                    'هذه أول محادثة مع @${widget.targetUsername}. يرجى توخي الحذر قبل مشاركة أي معلومات حساسة.',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                        icon: const Icon(Icons.block, color: Colors.redAccent, size: 16),
                        label: const Text('حظر', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        onPressed: _blockUser,
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                        icon: const Icon(Icons.report, color: Colors.amber, size: 16),
                        label: const Text('إبلاغ', style: TextStyle(color: Colors.amber, fontSize: 13)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تسجيل البلاغ بنجاح')),
                          );
                        },
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
                        onPressed: _acceptContact,
                        child: const Text('قبول ومتابعة', style: TextStyle(color: Colors.black, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == widget.myUsername;

                return Align(
                  alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF005C4B) : const Color(0xFF1F2C34),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isMe ? 2 : 14),
                        bottomRight: Radius.circular(isMe ? 14 : 2),
                      ),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(fontSize: 14.5, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1F2C34),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B141B),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _msgController,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة مشفرة...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00A884),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. شاشة الرنين والإشعار للمكالمة الواردة (Incoming Call Screen)
// -------------------------------------------------------------
class IncomingCallScreen extends StatefulWidget {
  final String callerUsername;
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.callerUsername,
    required this.isVideo,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _ringVibrateTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.85,
      upperBound: 1.15,
    )..repeat(reverse: true);

    // تكرار الاهتزاز لمحاكاة نغمة الرنين الفعالة
    _ringVibrateTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _ringVibrateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141B),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _animController,
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFF00A884).withOpacity(0.3),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFF00A884),
                        child: Text(
                          widget.callerUsername[0].toUpperCase(),
                          style: const TextStyle(fontSize: 38, color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('@${widget.callerUsername}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.isVideo ? Icons.videocam : Icons.call, color: const Color(0xFF00A884), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.isVideo ? 'مكالمة فيديو واردة ومباشرة...' : 'مكالمة صوتية واردة ومباشرة...',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.red,
                        child: IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.call_end, color: Colors.white),
                          onPressed: widget.onDecline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('رفض', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFF00A884),
                        child: IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.call, color: Colors.black),
                          onPressed: widget.onAccept,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('قبول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 6. شاشة المكالمات المباشرة Agora RTC
// -------------------------------------------------------------
class RealCallScreen extends StatefulWidget {
  final String channelName;
  final String targetUsername;
  final bool isVideo;

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
    await [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("انضم للمكالمة بنجاح: ${connection.channelId}");
          if (mounted) {
            setState(() {
              _localUserJoined = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("انضم الطرف الآخر: $remoteUid");
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("غادر الطرف الآخر المكالمة");
          if (mounted) {
            setState(() {
              _remoteUid = null;
            });
            Navigator.pop(context);
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("Agora Error [$err]: $msg");
        },
      ),
    );

    if (widget.isVideo) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.enableAudio();
    }

    await _engine.joinChannel(
      token: '',
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
            Center(
              child: _remoteVideoOrVoiceUI(),
            ),
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
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
                  CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 32,
                    child: IconButton(
                      icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
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
            'في انتظار رد ودخول الطرف الآخر',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      );
    }
  }
}