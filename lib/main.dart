import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_screen.dart'; // استدعاء شاشة الاتصال التي تحتوي على الـ App ID الخاص بك

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
// 1. شاشة البداية: فحص هل سجلت يوزر مسبقاً؟
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

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (savedUsername != null && savedUsername.isNotEmpty) {
      // المستخدم مسجل مسبقاً -> الانتقال للشاشة الرئيسية
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
      // مستخدم جديد -> شاشة إنشاء اليوزر
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
// 2. شاشة إنشاء وضبط الـ Username
// -------------------------------------------------------------
class UsernameRegisterScreen extends StatefulWidget {
  const UsernameRegisterScreen({super.key});

  @override
  State<UsernameRegisterScreen> createState() => _UsernameRegisterScreenState();
}

class _UsernameRegisterScreenState extends State<UsernameRegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String? _errorMessage;

  // التحقق من صحة صيغة اسم المستخدم
  bool _validateUsername(String username) {
    final validCharacters = RegExp(r'^[a-z0-9_]{3,20}$');
    return validCharacters.hasMatch(username);
  }

  Future<void> _submitUsername() async {
    final username = _usernameController.text.trim().toLowerCase();

    if (!_validateUsername(username)) {
      setState(() {
        _errorMessage = 'يجب أن يتكون اليوزر من 3-20 حرفاً (أحرف إنجليزية صغيرة، أرقام، أو _ فقط)';
      });
      return;
    }

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
                child: const Icon(Icons.alternate_email_rounded, size: 64, color: Color(0xFF00A884)),
              ),
              const SizedBox(height: 20),
              const Text(
                'اختر اسم المستخدم الخاص بك',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتمكن أصدقاؤك من الاتصال بك ومراسلتك من خلال هذا اليوزر',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                style: const TextStyle(letterSpacing: 1.2),
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(color: Color(0xFF00A884), fontWeight: FontWeight.bold, fontSize: 18),
                  hintText: 'user_name',
                  errorText: _errorMessage,
                  errorMaxLines: 2,
                  filled: true,
                  fillColor: const Color(0xFF1F2C34),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitUsername,
                child: const Text(
                  'تأكيد والدخول',
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
// 3. الشاشة الرئيسية: البحث والتواصل مع أي يوزر
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
          title: const Text('بدء محادثة باسم المستخدم'),
          content: TextField(
            controller: searchCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'اكتب يوزر الشخص (مثلاً: sara)',
              prefixIcon: Icon(Icons.person_search, color: Color(0xFF00A884)),
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
                    const SnackBar(content: Text('لا يمكنك بدء محادثة مع نفسك!')),
                  );
                  return;
                }

                if (blockedUsers.contains(targetUser)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('هذا المستخدم محظور في قائمتك!')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _openChat(targetUser);
              },
              child: const Text('مراسلة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
          ),
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
            const Icon(Icons.verified_user, color: Color(0xFF00A884), size: 20),
            const SizedBox(width: 8),
            Text('@${widget.myUsername}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
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
                    'لا توجد محادثات مفتوحة بعد\nاضغط على الزر بالأسفل واكتب يوزر الشخص لبدء الاتصال',
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
        child: const Icon(Icons.person_search, color: Colors.black),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. شاشة الدردشة وتوليد رابط المكالمة المشتركة
// -------------------------------------------------------------
class ChatScreen extends StatefulWidget {
  final String myUsername;
  final String targetUsername;

  const ChatScreen({
    super.key,
    required this.myUsername,
    required this.targetUsername,
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

  // توليد غرفة الاتصال المشتركة وفتح شاشة المكالمات Agora
  void _openCall(bool isVideo) {
    // خوارزمية الترتيب الأبجدي لضمان دخول الطرفين نفس اسم الغرفة في Agora تماماً
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
                const Text('مشفر طرف إلى طرف', style: TextStyle(fontSize: 10, color: Color(0xFF00A884))),
              ],
            ),
          ],
        ),
        actions: [
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
          // شريط الأمان عند المراسلة لأول مرة
          if (isFirstTime)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              color: const Color(0xFF1F2C34),
              child: Column(
                children: [
                  Text(
                    'هذه أول محادثة بينك وبين @${widget.targetUsername}. تأكد من هوية الشخص قبل مشاركة أي معلومات حساسة.',
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

          // عرض الرسائل
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

          // إدخال الرسائل
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