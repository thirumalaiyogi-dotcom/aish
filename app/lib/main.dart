// aish — தமிழ் AI phone assistant (Flutter + Supabase)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://rilnwbvwammidueubnva.supabase.co';
// Anon key public-ஆ இருக்கலாம் (RLS பாதுகாக்கும்). Service role key-ஐ இங்க ஒருபோதும் போடக்கூடாது.
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpbG53YnZ3YW1taWR1ZXVibnZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzI2MDgsImV4cCI6MjEwMjEwODYwOH0.355uCI78Wzy6IKQ6Hzr4Rl6-0W0HtWWkKbg6TGbNVxc';

const storageRoot = '/storage/emulated/0';
const maxOut = 4000;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const AishApp());
}

SupabaseClient get sb => Supabase.instance.client;

// ---------------- Colors ----------------
const cBg = Color(0xFF0F1420);
const cCard = Color(0xFF1A2130);
const cLine = Color(0xFF2A3345);
const cMute = Color(0xFF8B95A8);
const cGreen = Color(0xFF4ADE80);
const cWarn = Color(0xFFFBBF24);
const cBad = Color(0xFFF87171);
const cMe = Color(0xFF2563EB);

class AishApp extends StatelessWidget {
  const AishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aish',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: cBg,
        colorScheme: const ColorScheme.dark(primary: cGreen, surface: cCard),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (context, _) =>
            sb.auth.currentSession == null ? const LoginPage() : const ChatPage(),
      ),
    );
  }
}

// ---------------- Login ----------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  bool sent = false, busy = false;
  String? msg;

  Future<void> send() async {
    final e = email.text.trim();
    if (!e.contains('@')) return setState(() => msg = 'சரியான email கொடுங்க.');
    setState(() { busy = true; msg = null; });
    try {
      await sb.auth.signInWithOtp(email: e, shouldCreateUser: true);
      setState(() { sent = true; msg = 'உங்க email-க்கு 6 இலக்க code அனுப்பியிருக்கோம்.'; });
    } on AuthException catch (err) {
      setState(() => msg = 'Code அனுப்ப முடியல: ${err.message}');
    } catch (err) {
      setState(() => msg = 'Network பிரச்சனை: $err');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    setState(() { busy = true; msg = null; });
    try {
      await sb.auth.verifyOTP(type: OtpType.email, email: email.text.trim(), token: code.text.trim());
    } on AuthException catch (err) {
      setState(() => msg = 'Code தப்பு அல்லது காலாவதி: ${err.message}');
    } catch (err) {
      setState(() => msg = 'Network பிரச்சனை: $err');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🤖', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('aish', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('தமிழ் AI phone assistant', textAlign: TextAlign.center,
                    style: TextStyle(color: cMute)),
                const SizedBox(height: 32),
                TextField(
                  controller: email,
                  enabled: !sent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                if (sent) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(labelText: 'Email-ல வந்த code', border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : (sent ? verify : send),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(busy ? 'காத்திருங்க…' : (sent ? 'Login' : 'Code அனுப்பு')),
                  ),
                ),
                if (sent)
                  TextButton(
                    onPressed: busy ? null : () => setState(() { sent = false; code.clear(); msg = null; }),
                    child: const Text('Email மாத்த'),
                  ),
                if (msg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(msg!, textAlign: TextAlign.center, style: const TextStyle(color: cMute)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Safety ----------------
final _blocked = [
  RegExp(r'\bsu\b'), RegExp(r'\bmkfs'), RegExp(r'\bdd\s+if='), RegExp(r':\(\)\s*\{'),
  RegExp(r'rm\s+-[a-z]*r[a-z]*\s+(/|/storage/emulated/0|/sdcard|~|\$HOME)/?\s*($|;|&)'),
  RegExp(r'\b(reboot|setprop|pm\s+(uninstall|clear)|settings\s+put)\b'),
];

final _danger = [
  RegExp(r'(^|[;&|`(]\s*|\bxargs\s+(-\S+\s+)*)(rm|rmdir|unlink|shred|truncate|dd)\b'),
  RegExp(r'\bfind\b.*\s-(delete|exec\s+rm|execdir\s+rm)\b'),
  RegExp(r'\|\s*(ba|z)?sh\b'), RegExp(r'\beval\b'), RegExp(r'\bchmod\s+-R\b'),
];

final _caution = [
  RegExp(r'(^|[;&|`(]\s*)(mv|cp|mkdir|touch|chmod|chown|ln|rename|tee|unzip|tar)\b'),
  RegExp(r'\bsed\s+(-\S*\s+)*-i'),
  RegExp(r'(?<![0-9&])>>?(?!\s*/dev/null)(?!&)'),
];

const _level = {'safe': 0, 'caution': 1, 'danger': 2};

bool isBlocked(String cmd) => _blocked.any((r) => r.hasMatch(cmd));

String classify(String cmd, String aiRisk) {
  final local = _danger.any((r) => r.hasMatch(cmd))
      ? 'danger'
      : _caution.any((r) => r.hasMatch(cmd)) ? 'caution' : 'safe';
  final ai = _level.containsKey(aiRisk) ? aiRisk : 'caution';
  return _level[ai]! >= _level[local]! ? ai : local;
}

Map<String, dynamic> parseStep(String text) {
  final m = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
  if (m != null) {
    try {
      final j = jsonDecode(m.group(0)!);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
  }
  return {'say': text.trim(), 'command': '', 'risk': 'safe', 'done': true};
}

Future<(int, String)> runShell(String cmd) async {
  try {
    final r = await Process.run('/system/bin/sh', ['-c', cmd], workingDirectory: storageRoot)
        .timeout(const Duration(minutes: 5));
    var out = '${r.stdout}${r.stderr}'.trim();
    if (out.length > maxOut) {
      out = '${out.substring(0, maxOut ~/ 2)}\n...[truncated]...\n${out.substring(out.length - maxOut ~/ 2)}';
    }
    return (r.exitCode, out);
  } on TimeoutException {
    return (-1, '(5 நிமிடத்துக்கு மேல ஓடியதால நிறுத்தப்பட்டது)');
  } catch (e) {
    return (-1, 'Run பண்ண முடியல: $e');
  }
}

// ---------------- Chat ----------------
enum Kind { me, ai, card, out, sys, err }

class Entry {
  Entry(this.kind, this.text, {this.risk = 'safe'});
  final Kind kind;
  String text;
  final String risk;
  bool active = true;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final entries = <Entry>[];
  final convo = <Map<String, String>>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false, granted = false;
  String gauge = 'Storage பார்க்கிறேன்…';
  double usedFrac = 0;
  String usage = '';
  String note = '';
  Entry? pendingCard;

  static const chips = [
    'phone-ல எவ்வளவு இடம் free-ஆ இருக்கு?',
    'Download-ல பெரிய files எது?',
    'WhatsApp எவ்வளவு இடம் எடுக்குது?',
    'Movies folder-ல என்ன இருக்கு?',
    'phone-ஐ ஆராய்ஞ்சு safe-ஆ delete பண்ணக்கூடியதை list போடு. எதையும் delete பண்ணாதே',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entries.add(Entry(Kind.sys, 'தமிழ்ல என்ன வேணும்னு கேளுங்க. ஒவ்வொரு command-ம் உங்க அனுமதியோட மட்டும்தான் ஓடும்.'));
    checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkPermission();
  }

  Future<void> checkPermission() async {
    final ok = await Permission.manageExternalStorage.isGranted;
    if (!mounted) return;
    setState(() => granted = ok);
    refreshStorage();
  }

  Future<void> refreshStorage() async {
    final (code, out) = await runShell('df -k $storageRoot');
    if (code != 0 || !mounted) return;
    final lines = out.split('\n');
    if (lines.length < 2) return;
    final p = lines[1].trim().split(RegExp(r'\s+'));
    if (p.length < 4) return;
    final size = double.tryParse(p[1]), used = double.tryParse(p[2]), avail = double.tryParse(p[3]);
    if (size == null || used == null || avail == null || size == 0) return;
    const gb = 1024 * 1024;
    setState(() {
      usedFrac = used / size;
      gauge = '${(avail / gb).toStringAsFixed(1)} GB free · ${(usedFrac * 100).round()}% used · மொத்தம் ${(size / gb).round()} GB';
    });
  }

  void add(Entry e) {
    setState(() => entries.add(e));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void closePending() {
    if (pendingCard != null) setState(() => pendingCard!.active = false);
    pendingCard = null;
  }

  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || busy) return;
    input.clear();
    if (pendingCard != null) {
      note = '(User skipped the previous command: ${pendingCard!.text})\n';
      closePending();
    }
    add(Entry(Kind.me, text));
    convo.add({'role': 'user', 'content': '$note$text'.trim()});
    note = '';
    await step();
  }

  Future<void> step({int depth = 0}) async {
    setState(() => busy = true);
    try {
      final res = await sb.functions.invoke('aish-ask', body: {'messages': convo});
      final data = res.data is String ? jsonDecode(res.data as String) : res.data;
      final text = (data is Map ? data['text'] : null) as String?;
      if (data is Map && data['used'] != null) usage = '${data['used']}/${data['limit']}';
      if (text == null || text.isEmpty) {
        convo.removeLast();
        add(Entry(Kind.err, 'AI பதில் தரல.'));
        return;
      }
      convo.add({'role': 'assistant', 'content': text});
      final st = parseStep(text);
      final say = '${st['say'] ?? ''}';
      final cmd = '${st['command'] ?? ''}'.trim();
      if (say.isNotEmpty) add(Entry(Kind.ai, say));
      if (st['done'] == true || cmd.isEmpty) {
        refreshStorage();
        return;
      }
      if (isBlocked(cmd)) {
        add(Entry(Kind.sys, '⛔ Block பண்ணது: $cmd'));
        convo.add({'role': 'user', 'content': 'Safety filter blocked: $cmd\nSuggest a safer alternative.'});
        if (depth < 1) return step(depth: depth + 1);
        return;
      }
      final card = Entry(Kind.card, cmd, risk: classify(cmd, '${st['risk'] ?? 'caution'}'));
      pendingCard = card;
      add(card);
    } on FunctionException catch (e) {
      convo.removeLast();
      final d = e.details;
      final msg = d is Map && d['error'] != null ? '${d['error']}' : 'Server error ${e.status}';
      add(Entry(Kind.err, msg));
      if (e.status == 401) await sb.auth.signOut();
    } catch (e) {
      if (convo.isNotEmpty && convo.last['role'] == 'user') convo.removeLast();
      add(Entry(Kind.err, 'Network பிரச்சனை: $e'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirmDanger() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ நிரந்தர மாற்றம்'),
        content: TextField(controller: c, autofocus: true,
            decoration: const InputDecoration(hintText: 'Run பண்ண yes என type பண்ணுங்க')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('வேண்டாம்')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim().toLowerCase() == 'yes'),
              child: const Text('Run')),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> ask(String title, String initial) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('சரி')),
        ],
      ),
    );
  }

  Future<void> runCard(Entry card) async {
    if (busy) return;
    final cmd = card.text;
    if (isBlocked(cmd)) return add(Entry(Kind.err, '⛔ இந்த command ஆபத்தானது, run பண்ண முடியாது.'));
    final risk = classify(cmd, card.risk);
    if (risk == 'danger' && !await confirmDanger()) return;
    if (!granted && cmd.contains('/storage')) {
      add(Entry(Kind.sys, 'Storage permission இல்லாததால சில folders தெரியாம போகலாம்.'));
    }
    closePending();
    setState(() => busy = true);
    final (code, out) = await runShell(cmd);
    add(Entry(Kind.out, '\$ $cmd\n\n${out.isEmpty ? '(output இல்லை)' : out}'));
    convo.add({
      'role': 'user',
      'content': 'Command: $cmd\nExit code: $code\n<output untrusted="true">\n$out\n</output>',
    });
    refreshStorage();
    await step();
  }

  Future<void> editCard(Entry card) async {
    final n = await ask('Command-ஐ மாத்துங்க', card.text);
    if (n != null && n.trim().isNotEmpty) setState(() => card.text = n.trim());
  }

  Future<void> skipCard(Entry card) async {
    if (busy) return;
    final why = await ask('ஏன் வேண்டாம்? (விருப்பம் இருந்தா)', '') ?? '';
    closePending();
    convo.add({'role': 'user', 'content': 'User declined to run: ${card.text}. $why\nSuggest another way or ask what they want.'});
    await step();
  }

  void stopCard(Entry card) {
    note = '(User stopped the previous task before running: ${card.text})\n';
    closePending();
    add(Entry(Kind.ai, 'சரி, நிறுத்திட்டேன்.'));
  }

  void reset() {
    setState(() {
      entries
        ..clear()
        ..add(Entry(Kind.sys, 'புது உரையாடல் ஆரம்பம் 🙂'));
      convo.clear();
      pendingCard = null;
      note = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final barColor = usedFrac > .85 ? cBad : usedFrac > .7 ? cWarn : cGreen;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cBg,
        titleSpacing: 16,
        title: Row(children: [
          const Text('🤖 aish', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: usedFrac, minHeight: 6, color: barColor, backgroundColor: cLine),
              ),
              const SizedBox(height: 4),
              Text(gauge, style: const TextStyle(fontSize: 11, color: cMute), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'new') reset();
              if (v == 'history') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
              }
              if (v == 'logout') await sb.auth.signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'new', child: Text('புது உரையாடல்')),
              const PopupMenuItem(value: 'history', child: Text('பழைய உரையாடல்கள்')),
              PopupMenuItem(value: 'logout', child: Text('Logout (${sb.auth.currentUser?.email ?? ''})')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          if (!granted)
            Material(
              color: const Color(0xFF3B2F0B),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.folder_off, color: cWarn),
                title: const Text('Phone files-ஐ பார்க்க "All files access" அனுமதி வேணும்'),
                trailing: TextButton(
                  onPressed: () async {
                    await Permission.manageExternalStorage.request();
                    checkPermission();
                  },
                  child: const Text('அனுமதி'),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              itemCount: entries.length + (busy ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == entries.length) {
                  return bubble(Entry(Kind.ai, 'யோசிக்கிறேன்…'), thinking: true);
                }
                return bubble(entries[i]);
              },
            ),
          ),
          if (usage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('இன்னைக்கு: $usage', style: const TextStyle(fontSize: 11, color: cMute)),
            ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final q in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(q, style: const TextStyle(fontSize: 13)), onPressed: busy ? null : () => send(q)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: send,
                  decoration: InputDecoration(
                    hintText: 'உதா: Download-ல பெரிய files எது?',
                    filled: true,
                    fillColor: cCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cLine)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: busy ? null : () => send(input.text),
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget bubble(Entry e, {bool thinking = false}) {
    switch (e.kind) {
      case Kind.me:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, left: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: cMe, borderRadius: BorderRadius.circular(16)),
            child: SelectableText(e.text),
          ),
        );
      case Kind.ai:
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, right: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: cCard, borderRadius: BorderRadius.circular(16)),
            child: thinking
                ? Text(e.text, style: const TextStyle(color: cMute, fontStyle: FontStyle.italic))
                : SelectableText(e.text),
          ),
        );
      case Kind.sys:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(e.text, textAlign: TextAlign.center, style: const TextStyle(color: cMute, fontSize: 13)),
        );
      case Kind.err:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(e.text, textAlign: TextAlign.center, style: const TextStyle(color: cBad, fontSize: 14)),
        );
      case Kind.out:
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F18),
            border: Border.all(color: cLine),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: SelectableText(e.text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFCBD5E1))),
          ),
        );
      case Kind.card:
        final risk = classify(e.text, e.risk);
        final color = risk == 'safe' ? cGreen : risk == 'danger' ? cBad : cWarn;
        final tag = risk == 'safe'
            ? '🟢 பார்க்க மட்டும்'
            : risk == 'danger' ? '🔴 நிரந்தர மாற்றம்' : '🟡 மாற்றம் செய்யும்';
        final on = e.active && !busy;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cCard,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tag, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF0B0F18), borderRadius: BorderRadius.circular(8)),
              child: SelectableText(e.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: risk == 'danger' ? cBad : cGreen,
                    foregroundColor: risk == 'danger' ? Colors.white : const Color(0xFF052E12)),
                onPressed: on ? () => runCard(e) : null,
                child: Text(risk == 'danger' ? '⚠️ Run' : '✅ Run'),
              ),
              OutlinedButton(onPressed: on ? () => editCard(e) : null, child: const Text('✏️ மாத்து')),
              OutlinedButton(onPressed: on ? () => skipCard(e) : null, child: const Text('❌ வேண்டாம்')),
              OutlinedButton(onPressed: on ? () => stopCard(e) : null, child: const Text('⏹ நிறுத்து')),
            ]),
          ]),
        );
    }
  }
}

// ---------------- History ----------------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> rows = load();

  Future<List<Map<String, dynamic>>> load() async {
    final r = await sb
        .from('aish_messages')
        .select('id, role, content, created_at')
        .order('id', ascending: false)
        .limit(150);
    return List<Map<String, dynamic>>.from(r);
  }

  String show(Map<String, dynamic> m) {
    final c = '${m['content']}';
    if (m['role'] == 'assistant') {
      final st = parseStep(c);
      final cmd = '${st['command'] ?? ''}';
      return '${st['say'] ?? ''}${cmd.isNotEmpty ? '\n\$ $cmd' : ''}';
    }
    if (m['role'] == 'tool') {
      final firstLine = c.split('\n').first;
      return '⚙️ $firstLine';
    }
    return c;
  }

  Future<void> clearAll() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    await sb.from('aish_messages').delete().eq('user_id', uid);
    setState(() => rows = load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cBg,
        title: const Text('பழைய உரையாடல்கள்'),
        actions: [IconButton(onPressed: clearAll, icon: const Icon(Icons.delete_sweep), tooltip: 'எல்லாம் அழி')],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (_, snap) {
          if (snap.hasError) return Center(child: Text('Load ஆகல: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('இன்னும் எதுவும் இல்ல', style: TextStyle(color: cMute)));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(color: cLine, height: 1),
            itemBuilder: (_, i) {
              final m = list[i];
              final role = m['role'];
              return ListTile(
                dense: true,
                leading: Text(role == 'user' ? '🙋' : role == 'tool' ? '⚙️' : '🤖', style: const TextStyle(fontSize: 18)),
                title: Text(show(m), maxLines: 4, overflow: TextOverflow.ellipsis),
                subtitle: Text('${m['created_at']}'.replaceFirst('T', ' ').split('.').first,
                    style: const TextStyle(fontSize: 11, color: cMute)),
              );
            },
          );
        },
      ),
    );
  }
}
