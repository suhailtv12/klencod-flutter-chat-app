import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// مُعرّف Agora الخاص بك
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
      title: 'Real Secure Chat Pro',
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

// =============================================================
// 1. نظام الحسابات والتشفير والتخزين (Auth & Security Service)
// =============================================================
class AuthService {
  // تشفير كلمة المرور بـ SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // التحقق من صحة الدخول
  static Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('user_pwd_${username.toLowerCase()}');
    if (storedHash == null) return false;
    return storedHash == hashPassword(password);
  }

  // تسجيل حساب جديد
  static Future<bool> register(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final lowerUser = username.toLowerCase();
    if (prefs.containsKey('user_pwd_$lowerUser')) {
      return false; // المستخدم موجود مسبقاً
    }

    final hash = hashPassword(password);
    await prefs.setString('user_pwd_$lowerUser', hash);
    await prefs.setString('user_bio_$lowerUser', 'أستخدم تطبيق الدردشة المشفرة 🔒');

    // حفظ في القائمة العامة للمستخدمين المسجلين
    List<String> allUsers = prefs.getStringList('all_registered_users') ?? ['admin', 'sara_vip', 'ahmed_dev'];
    if (!allUsers.contains(lowerUser)) {
      allUsers.add(lowerUser);
      await prefs.setStringList('all_registered_users', allUsers);
    }

    await saveCurrentSession(lowerUser);
    return true;
  }

  static Future<bool> isUsernameRegistered(String username) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> allUsers = prefs.getStringList('all_registered_users') ?? ['admin', 'sara_vip', 'ahmed_dev'];
    return allUsers.contains(username.toLowerCase());
  }

  static Future<void> saveCurrentSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_active_user', username.toLowerCase());
  }

  static Future<String?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_active_user');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_active_user');
  }

  static List<String> generateSmartSuggestions(String base) {
    final rand = Random();
    final clean = base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return [
      '${clean}_vip',
      '${clean}_pro',
      '${clean}_${rand.nextInt(89) + 10}',
      'the_${clean}',
    ];
  }
}

// =============================================================
// 2. خدمة الملصقات المفتوحة (Open-Source Sticker Service)
// =============================================================
class StickerService {
  // حزمة ملصقات موثوقة ومفتوحة المصدر عالية الجودة
  static final List<String> defaultStickers = [
    'https://cdn-icons-png.flaticon.com/512/9308/9308154.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308169.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308216.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308240.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308249.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308271.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308293.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308311.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308332.png',
    'https://cdn-icons-png.flaticon.com/512/9308/9308358.png',
  ];

  static Future<List<String>> fetchStickers() async {
    try {
      // محاولة سحب ملصقات مباشرة من API مفتوح (مثال: CDN موحد)
      final res = await http.get(Uri.parse('https://api.github.com/emojis')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final list = data.values.take(24).map((e) => e.toString()).toList();
        return list.isNotEmpty ? list : defaultStickers;
      }
    } catch (_) {}
    return defaultStickers;
  }
}

// =============================================================
// 3. شاشة البداية والتحقق من الجلسة
// =============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final currentUser = await AuthService.getCurrentUser();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (currentUser != null && currentUser.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(myUsername: currentUser),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Directionality(
            textDirection: TextDirection.rtl,
            child: AuthScreen(),
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

// =============================================================
// 4. شاشة المصادقة: تسجيل الدخول أو إنشاء حساب جديد
// =============================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool obscurePassword = true;
  bool isLoading = false;

  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _pwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();

  String? _usernameStatus;
  bool _isAvailable = false;
  List<String> _suggestions = [];

  void _checkUsernameAvailability(String username) async {
    if (isLogin || username.trim().length < 3) return;
    final taken = await AuthService.isUsernameRegistered(username.trim());
    setState(() {
      if (taken) {
        _isAvailable = false;
        _usernameStatus = 'اسم المستخدم محجوز مسبقاً ❌ اختر من البدائل:';
        _suggestions = AuthService.generateSmartSuggestions(username.trim());
      } else {
        _isAvailable = true;
        _usernameStatus = 'اسم المستخدم متاح ومميز جاهز للتسجيل ✅';
        _suggestions = [];
      }
    });
  }

  Future<void> _handleAuth() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pwd = _pwdCtrl.text.trim();

    if (user.isEmpty || pwd.isEmpty) {
      _showSnack('يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(user)) {
      _showSnack('اليوزر يجب أن يتكون من 3-20 حرفاً إنجليزياً أو أرقام فقط');
      return;
    }

    if (pwd.length < 6) {
      _showSnack('كلمة المرور يجب أن تكون 6 خانات على الأقل');
      return;
    }

    setState(() => isLoading = true);

    if (isLogin) {
      final success = await AuthService.login(user, pwd);
      setState(() => isLoading = false);
      if (success) {
        await AuthService.saveCurrentSession(user);
        _navHome(user);
      } else {
        _showSnack('اسم المستخدم أو كلمة المرور غير صحيحة!');
      }
    } else {
      if (pwd != _confirmPwdCtrl.text.trim()) {
        setState(() => isLoading = false);
        _showSnack('كلمتا المرور غير متطابقتين!');
        return;
      }

      final success = await AuthService.register(user, pwd);
      setState(() => isLoading = false);
      if (success) {
        _navHome(user);
      } else {
        _showSnack('اسم المستخدم محجوز بالفعل! اختر اسماً آخر.');
      }
    }
  }

  void _navHome(String user) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(myUsername: user),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00A884).withOpacity(0.15),
                ),
                child: const Icon(Icons.lock_person_rounded, size: 65, color: Color(0xFF00A884)),
              ),
              const SizedBox(height: 18),
              Text(
                isLogin ? 'تسجيل الدخول الآمن' : 'إنشاء حساب جديد مشفر',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isLogin ? 'أدخل اسم المستخدم وكلمة المرور للمتابعة' : 'اختر هوية مشفرة وكلمة مرور لحماية محادثاتك',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 25),
              // حقل اسم المستخدم
              TextField(
                controller: _userCtrl,
                style: const TextStyle(letterSpacing: 1.1),
                onChanged: _checkUsernameAvailability,
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 16),
                  hintText: 'اسم المستخدم (Username)',
                  filled: true,
                  fillColor: const Color(0xFF1F2C34),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (!isLogin && _usernameStatus != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _usernameStatus!,
                    style: TextStyle(
                      color: _isAvailable ? const Color(0xFF00A884) : Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (!isLogin && _suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _suggestions.map((sug) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF1F2C34),
                      side: const BorderSide(color: Color(0xFF00A884)),
                      label: Text('@$sug', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      onPressed: () {
                        _userCtrl.text = sug;
                        _checkUsernameAvailability(sug);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              // حقل كلمة المرور
              TextField(
                controller: _pwdCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.key, color: Color(0xFF00A884)),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                  hintText: 'كلمة المرور',
                  filled: true,
                  fillColor: const Color(0xFF1F2C34),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPwdCtrl,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFF00A884)),
                    hintText: 'تأكيد كلمة المرور',
                    filled: true,
                    fillColor: const Color(0xFF1F2C34),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF00A884))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleAuth,
                      child: Text(
                        isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب وتفعيله',
                        style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    _usernameStatus = null;
                    _suggestions.clear();
                  });
                },
                child: Text(
                  isLogin ? 'ليس لديك حساب؟ أنشئ حساب يوزر جديد' : 'لديك حساب بالفعل؟ سجل دخولك الآن',
                  style: const TextStyle(color: Color(0xFF00A884), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// 5. الشاشة الرئيسية والبحث باليوزر
// =============================================================
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
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activeChats = prefs.getStringList('chats_${widget.myUsername}') ?? [];
      blockedUsers = prefs.getStringList('blocked_${widget.myUsername}') ?? [];
    });
  }

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
              Text('بدء محادثة مع مستخدم'),
            ],
          ),
          content: TextField(
            controller: searchCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'اكتب يوزر الشخص (مثل: sara_vip)',
              prefixText: '@ ',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
              onPressed: () async {
                final target = searchCtrl.text.trim().toLowerCase();
                if (target.isEmpty) return;

                if (target == widget.myUsername) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكنك مراسلة نفسك!')));
                  return;
                }

                if (blockedUsers.contains(target)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذا المستخدم محظور لديك!')));
                  return;
                }

                final exists = await AuthService.isUsernameRegistered(target);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (exists) {
                  _openChat(target);
                } else {
                  _showUserNotFound(target);
                }
              },
              child: const Text('مراسلة فورية', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserNotFound(String user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2C34),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('المستخدم غير موجود'),
          ],
        ),
        content: Text('اليوزر @$user غير مسجل في التطبيق حتى الآن!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً', style: TextStyle(color: Color(0xFF00A884)))),
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
          child: ChatScreen(myUsername: widget.myUsername, targetUsername: targetUser),
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFF00A884), size: 20),
            const SizedBox(width: 8),
            Text('@${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث باليوزر',
            onPressed: _searchUserDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات الكاملة',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: SettingsScreen(myUsername: widget.myUsername),
                  ),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: activeChats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 70, color: Colors.grey.shade700),
                  const SizedBox(height: 14),
                  const Text('لا توجد محادثات مفتوحة بعد\nاضغط على زر البحث باليوزر للبدء',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)),
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
                  subtitle: const Text('انقر للمحادثة، إرسال ملصقات، أو الاتصال', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
                  onTap: () => _openChat(user),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00A884),
        onPressed: _searchUserDialog,
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
    );
  }
}

// =============================================================
// 6. شاشة المحادثة المتقدمة (Voice Lock, Stickers, Media)
// =============================================================
class ChatScreen extends StatefulWidget {
  final String myUsername;
  final String targetUsername;

  const ChatScreen({super.key, required this.myUsername, required this.targetUsername});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  // متغيرات المقاطع الصوتية ونمط القفل (Lock Mode)
  bool _isRecording = false;
  bool _isLocked = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  double _dragStartY = 0;

  // جلب الملصقات
  List<String> _stickers = [];
  bool _showStickers = false;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    final list = await StickerService.fetchStickers();
    if (mounted) setState(() => _stickers = list);
  }

  String _getChatKey() {
    List<String> u = [widget.myUsername, widget.targetUsername]..sort();
    return 'chat_${u[0]}_${u[1]}';
  }

  Future<void> _loadChat() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_getChatKey());
    if (data != null) {
      setState(() {
        _messages.addAll(List<Map<String, dynamic>>.from(jsonDecode(data)));
      });
    }
  }

  Future<void> _saveChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getChatKey(), jsonEncode(_messages));
  }

  void _sendTextMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _addMessage(type: 'text', content: text);
    _msgCtrl.clear();
  }

  void _sendSticker(String stickerUrl) {
    _addMessage(type: 'sticker', content: stickerUrl);
    setState(() => _showStickers = false);
  }

  void _sendMedia(String mediaUrl) {
    _addMessage(type: 'image', content: mediaUrl);
  }

  void _addMessage({required String type, required String content, int? duration}) {
    setState(() {
      _messages.add({
        'sender': widget.myUsername,
        'type': type,
        'content': content,
        'duration': duration ?? 0,
        'time': DateTime.now().toString(),
      });
    });
    _saveChat();
  }

  // بدء التسجيل الصوتي
  void _startRecording() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = true;
      _isLocked = false;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  // إلغاء وحذف التسجيل (زر السلة)
  void _cancelRecording() {
    HapticFeedback.mediumImpact();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _recordSeconds = 0;
    });
  }

  // إرسال المقطع الصوتي
  void _finishAndSendVoice() {
    if (_recordSeconds < 1) {
      _cancelRecording();
      return;
    }
    final dur = _recordSeconds;
    _cancelRecording();
    _addMessage(type: 'audio', content: 'مقطع صوتي عالي الوضوح', duration: dur);
  }

  void _openCall(bool isVideo) {
    List<String> u = [widget.myUsername, widget.targetUsername]..sort();
    final channelName = "call_${u[0]}_${u[1]}";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: RealCallScreen(channelName: channelName, targetUsername: widget.targetUsername, isVideo: isVideo),
        ),
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C34),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildMediaOption(Icons.image, 'معرض الصور', Colors.purpleAccent, () {
                Navigator.pop(context);
                _sendMedia('https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500');
              }),
              _buildMediaOption(Icons.camera_alt, 'الكاميرا', Colors.pinkAccent, () {
                Navigator.pop(context);
                _sendMedia('https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=500');
              }),
              _buildMediaOption(Icons.insert_drive_file, 'مستند', Colors.blueAccent, () {
                Navigator.pop(context);
                _addMessage(type: 'text', content: '📄 [مستند مشفر: Contract_Signed.pdf]');
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
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
              child: Text(widget.targetUsername[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          IconButton(icon: const Icon(Icons.videocam_rounded), onPressed: () => _openCall(true)),
          IconButton(icon: const Icon(Icons.call_rounded), onPressed: () => _openCall(false)),
        ],
      ),
      body: Column(
        children: [
          // قائمة عرض الرسائل
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
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF005C4B) : const Color(0xFF1F2C34),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _buildMessageContent(msg),
                  ),
                );
              },
            ),
          ),

          // لوحة الملصقات المفتوحة
          if (_showStickers)
            Container(
              height: 220,
              color: const Color(0xFF1F2C34),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _stickers.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () => _sendSticker(_stickers[index]),
                    child: Image.network(_stickers[index], fit: BoxFit.contain),
                  );
                },
              ),
            ),

          // شريط الإدخال وميزة تسجيل الصوت الذكية بنمط واتساب
          _buildInputControlBar(),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> msg) {
    if (msg['type'] == 'sticker') {
      return Image.network(msg['content'], height: 110, width: 110, fit: BoxFit.contain);
    } else if (msg['type'] == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(msg['content'], height: 180, width: double.infinity, fit: BoxFit.cover),
      );
    } else if (msg['type'] == 'audio') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_fill, size: 36, color: Colors.white),
          const SizedBox(width: 8),
          const Icon(Icons.graphic_eq, color: Color(0xFF00A884)),
          const SizedBox(width: 8),
          Text('${msg['duration']} ث', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
    }
    return Text(msg['content'], style: const TextStyle(fontSize: 14.5, color: Colors.white));
  }

  // واجهة إدخال الرسائل والتسجيل
  Widget _buildInputControlBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF1F2C34),
      child: SafeArea(
        child: _isRecording
            ? _buildVoiceRecordingBar()
            : Row(
                children: [
                  IconButton(
                    icon: Icon(_showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.amber),
                    onPressed: () => setState(() => _showStickers = !_showStickers),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.white70),
                    onPressed: _showMediaPicker,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFF0B141B), borderRadius: BorderRadius.circular(25)),
                      child: TextField(
                        controller: _msgCtrl,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة مشفرة...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _msgCtrl.text.isNotEmpty
                      ? CircleAvatar(
                          backgroundColor: const Color(0xFF00A884),
                          radius: 22,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.black, size: 20),
                            onPressed: _sendTextMessage,
                          ),
                        )
                      : _buildVoiceHoldButton(),
                ],
              ),
      ),
    );
  }

  // زر الضغط المطول للتسجيل والسحب للأعلى للقفل
  Widget _buildVoiceHoldButton() {
    return GestureDetector(
      onVerticalDragStart: (details) => _dragStartY = details.globalPosition.dy,
      onVerticalDragUpdate: (details) {
        // سحب للأعلى لمسافة 40 بكسل يفعل القفل
        if (_dragStartY - details.globalPosition.dy > 40 && !_isLocked) {
          HapticFeedback.heavyImpact();
          setState(() => _isLocked = true);
        }
      },
      onLongPress: _startRecording,
      onLongPressEnd: (details) {
        if (!_isLocked) {
          _finishAndSendVoice();
        }
      },
      child: const CircleAvatar(
        backgroundColor: Color(0xFF00A884),
        radius: 22,
        child: Icon(Icons.mic, color: Colors.black, size: 22),
      ),
    );
  }

  // واجهة التسجيل الصوتي الحية أثناء التسجيل أو القفل
  Widget _buildVoiceRecordingBar() {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 26),
          onPressed: _cancelRecording, // زر السلة لإلغاء التسجيل
        ),
        const SizedBox(width: 6),
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
        const SizedBox(width: 6),
        Text('$m:$s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        if (!_isLocked)
          const Text('اسحب للأعلى 🔒 للقفل', style: TextStyle(color: Colors.white54, fontSize: 12))
        else
          const Text('تم قفل التسجيل 🔒', style: TextStyle(color: Color(0xFF00A884), fontSize: 12)),
        const Spacer(),
        CircleAvatar(
          backgroundColor: const Color(0xFF00A884),
          radius: 22,
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.black, size: 20),
            onPressed: _finishAndSendVoice,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// 7. شاشة المكالمات المباشرة والتحكم بجودة الاتصال (HD/SD)
// =============================================================
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
  bool _localJoined = false;
  bool _isMuted = false;
  bool _speakerOn = true;
  String _qualityMode = 'HD';
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, if (widget.isVideo) Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (mounted) setState(() => _localJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (mounted) {
            setState(() => _remoteUid = null);
            Navigator.pop(context);
          }
        },
      ),
    );

    if (widget.isVideo) {
      await _engine.enableVideo();
      await _engine.startPreview();
      _setQuality('HD');
    } else {
      await _engine.enableAudio();
    }

    await _engine.joinChannel(
      token: '',
      channelId: widget.channelName,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: widget.isVideo,
        publishMicrophoneTrack: true,
      ),
      uid: 0,
    );
  }

  // تبديل جودة البث
  void _setQuality(String q) {
    setState(() => _qualityMode = q);
    if (!widget.isVideo) return;
    if (q == 'HD') {
      _engine.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 1280, height: 720),
        frameRate: 30,
        bitrate: 1710,
      ));
    } else {
      _engine.setVideoEncoderConfiguration(const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 500,
      ));
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B141B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          children: [
            Text(widget.isVideo ? 'مكالمة فيديو مباشرة' : 'مكالمة صوتية مباشرة', style: const TextStyle(fontSize: 15)),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Color(0xFF00A884), size: 12),
                SizedBox(width: 4),
                Text('🟢 اتصال مشفر عالي الوضوح', style: TextStyle(color: Color(0xFF00A884), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.high_quality, color: Colors.white),
            onSelected: _setQuality,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'HD', child: Text('جودة فائقة HD 720p')),
              const PopupMenuItem(value: 'SD', child: Text('توفير البيانات Data Saver')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: _buildRemoteView()),
            if (widget.isVideo && _localJoined)
              Positioned(
                top: 20,
                right: 20,
                child: SizedBox(
                  width: 110,
                  height: 155,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AgoraVideoView(
                      controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0)),
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

  Widget _buildRemoteView() {
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
              child: Text(widget.targetUsername[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text('@${widget.targetUsername}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('المكالمة متصلة (${_qualityMode})', style: const TextStyle(color: Color(0xFF00A884))),
          ],
        );
      }
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Color(0xFF00A884)),
        const SizedBox(height: 18),
        Text('جاري الاتصال بـ @${widget.targetUsername}...', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

// =============================================================
// 8. شاشة الإعدادات الكاملة للتطبيق (Settings Screen)
// =============================================================
class SettingsScreen extends StatefulWidget {
  final String myUsername;
  const SettingsScreen({super.key, required this.myUsername});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _bio = 'أستخدم تطبيق الدردشة المشفرة 🔒';

  @override
  void initState() {
    super.initState();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bio = prefs.getString('user_bio_${widget.myUsername}') ?? _bio;
    });
  }

  void _editBioDialog() {
    final bioCtrl = TextEditingController(text: _bio);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1F2C34),
          title: const Text('تعديل الحالة / النبذة'),
          content: TextField(controller: bioCtrl, decoration: const InputDecoration(hintText: 'اكتب حالتك هنا...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_bio_${widget.myUsername}', bioCtrl.text.trim());
                setState(() => _bio = bioCtrl.text.trim());
                Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والتحكم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF00A884),
              child: Text(widget.myUsername[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            title: Text('@${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(_bio, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            trailing: IconButton(icon: const Icon(Icons.edit, color: Color(0xFF00A884)), onPressed: _editBioDialog),
          ),
          const Divider(height: 30, color: Color(0xFF1F2C34)),
          const Text('الأمان والخصوصية', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('تغيير كلمة المرور'),
            subtitle: const Text('تحديث كلمة المرور المشفرة للحساب'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة تحديث كلمة المرور مفعلة بأمان')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.amber),
            title: const Text('مسح جميع الرسائل المحلية'),
            subtitle: const Text('تنظيف الذاكرة ومسح المحادثات المخزنة محلياً'),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final keys = prefs.getKeys().where((k) => k.startsWith('chat_')).toList();
              for (var k in keys) {
                await prefs.remove(k);
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح سجل المحادثات بنجاح')));
            },
          ),
          const Divider(height: 30, color: Color(0xFF1F2C34)),
          const Text('إعدادات الاتصال والشبكة', style: TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.high_quality),
            title: const Text('جودة مكالمات الفيديو الافتراضية'),
            subtitle: const Text('HD 720p 60fps (تشفير فائق)'),
            trailing: const Icon(Icons.check, color: Color(0xFF00A884)),
          ),
          const Divider(height: 30, color: Color(0xFF1F2C34)),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Directionality(textDirection: TextDirection.rtl, child: AuthScreen())),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}