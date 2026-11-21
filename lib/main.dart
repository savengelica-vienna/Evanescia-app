import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supaUrl = 'https://ypkvgvenejqfkacljtpa.supabase.co';
const supaKey = 'sb_publishable_P5FZe_rmoWEDO3rvjZAsYg_EPVYAiKR';

const bg = Color(0xFF0B0F1A);
const card = Color(0xFF121829);
const line = Color(0xFF222B45);
const mu = Color(0xFF7C88A8);
const ac = Color(0xFF6C7BFF);

final sb = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supaUrl, anonKey: supaKey);
  runApp(MaterialApp(
    title: 'NnevApp',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: ac, surface: card),
    ),
    home: const Gate(),
  ));
}

// ---------- RANK ----------
class Rk {
  final String name, desc;
  final IconData icon;
  final Color solid;
  final List<Color>? grad;
  final Color? glow;
  final bool anim;
  const Rk(this.name, this.desc, this.icon, this.solid,
      {this.grad, this.glow, this.anim = false});
}

const ranks = <String, Rk>{
  'user': Rk('User', 'User biasa', Icons.person_outline, Color(0xFF9CA3AF)),
  'member': Rk('Member', 'Member script', Icons.verified_user_outlined, Colors.white),
  'premium': Rk('Premium', 'Donatur script', Icons.diamond_outlined, Color(0xFFFFD700),
      grad: [Color(0xFFFFD700), Color(0xFFFFF4A3), Color(0xFFD4AF37), Color(0xFFFFD700)],
      glow: Color(0xFFFFD700)),
  'admin': Rk('Admin', 'Pengendali grup', Icons.workspace_premium_outlined, Color(0xFFFF4D8D),
      grad: [Color(0xFFFF1744), Color(0xFFFF69B4), Color(0xFFFF1493), Color(0xFFFF1744)],
      glow: Color(0xFFFF1493)),
  'helper': Rk('Helper', 'Staff', Icons.headset_mic_outlined, Color(0xFF00E5E5),
      grad: [Color(0xFF00FFFF), Color(0xFF00BFA5), Color(0xFF7FFFD4), Color(0xFF00FFFF)],
      glow: Color(0xFF00FFFF), anim: true),
  'developer': Rk('Developer', 'Maha raja dewa', Icons.code, Color(0xFFC06BFF),
      grad: [Color(0xFF9400FF), Color(0xFFDA70D6), Color(0xFFFFD700), Color(0xFF9400FF)],
      glow: Color(0xFF9400FF), anim: true),
};

class _Slide extends GradientTransform {
  final double p;
  const _Slide(this.p);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * p, 0, 0);
}

class RankText extends StatefulWidget {
  final String text, rank;
  final double size;
  const RankText(this.text, this.rank, {super.key, this.size = 17});
  @override
  State<RankText> createState() => _RankTextState();
}

class _RankTextState extends State<RankText> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  void _sync() {
    final a = ranks[widget.rank]?.anim ?? false;
    if (a && !c.isAnimating) c.repeat();
    if (!a) c.stop();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(RankText o) {
    super.didUpdateWidget(o);
    _sync();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ranks[widget.rank] ?? ranks['user']!;
    if (r.grad == null) {
      return Text(widget.text,
          style: TextStyle(fontSize: widget.size, fontWeight: FontWeight.w800, color: r.solid));
    }
    final style = TextStyle(
      fontSize: widget.size,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      shadows: [Shadow(color: r.glow!.withOpacity(.35), blurRadius: 4)],
    );
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (b) => LinearGradient(
          colors: r.grad!,
          tileMode: TileMode.repeated,
          transform: _Slide(c.value),
        ).createShader(b),
        child: Text(widget.text, style: style),
      ),
    );
  }
}

Widget box(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: child,
    );

Widget infoRow(IconData i, String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(i, size: 18, color: mu),
        const SizedBox(width: 8),
        Text(k, style: const TextStyle(color: mu, fontSize: 14)),
        const Spacer(),
        v,
      ]),
    );

// ---------- GATE + LOGIN ----------
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: sb.auth.onAuthStateChange,
        builder: (_, __) =>
            sb.auth.currentSession == null ? const LoginPage() : const Home(),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final u = TextEditingController(), p = TextEditingController();
  String err = '';
  bool busy = false;

  Future<void> go() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await sb.auth.signInWithPassword(
          email: '${u.text.trim().toLowerCase()}@nnevapp.local', password: p.text);
    } on AuthException {
      err = 'Username atau password salah';
    } catch (_) {
      err = 'Tidak bisa terhubung ke server';
    }
    if (mounted) setState(() => busy = false);
  }

  Widget field(TextEditingController c, String h, IconData i, {bool pw = false}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
        child: Row(children: [
          Icon(i, color: mu, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              obscureText: pw,
              autocorrect: false,
              decoration: InputDecoration(hintText: h, border: InputBorder.none),
              onSubmitted: (_) => pw ? go() : null,
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                    child: const Icon(Icons.smartphone, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text('NnevApp', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Masuk dengan akun yang kamu punya', style: TextStyle(color: mu)),
                  const SizedBox(height: 26),
                  field(u, 'Username', Icons.person_outline),
                  field(p, 'Password', Icons.lock_outline, pw: true),
                  SizedBox(
                      height: 20,
                      child: Text(err, style: const TextStyle(color: Color(0xFFFF6B81), fontSize: 13))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: busy ? null : go,
                      icon: busy
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: const Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                          backgroundColor: ac,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

// ---------- HOME ----------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0, cur = 0;
  int? shownFor;
  Map<String, dynamic>? cfg;
  StreamSubscription? sub;
  late final Stream<List<Map<String, dynamic>>> prof =
      sb.from('profiles').stream(primaryKey: ['id']).eq('id', sb.auth.currentUser!.id);

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      cur = int.tryParse(i.buildNumber) ?? 0;
      if (mounted) setState(() {});
      maybePrompt();
    });
    sub = sb.from('app_config').stream(primaryKey: ['id']).eq('id', 'android').listen((rows) {
      if (rows.isEmpty) return;
      cfg = rows.first;
      if (mounted) setState(() {});
      maybePrompt();
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  bool get hasUpdate =>
      cfg != null &&
      cur > 0 &&
      (cfg!['version_code'] as int) > cur &&
      (cfg!['apk_url'] ?? '').toString().isNotEmpty;

  void maybePrompt({bool force = false}) {
    if (!hasUpdate || !mounted) return;
    final vc = cfg!['version_code'] as int;
    if (!force && shownFor == vc) return;
    shownFor = vc;
    final must = cur < (cfg!['min_version_code'] as int);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(cfg: cfg!, force: must),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: prof,
        builder: (_, s) {
          final rows = s.data;
          if (rows == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (rows.isEmpty) {
            return Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Profil tidak ditemukan'),
                  TextButton(onPressed: () => sb.auth.signOut(), child: const Text('Keluar')),
                ]),
              ),
            );
          }
          final me = rows.first;
          final exp = me['expires_at'];
          if (exp != null && DateTime.parse(exp as String).isBefore(DateTime.now().toUtc())) {
            WidgetsBinding.instance.addPostFrameCallback((_) => sb.auth.signOut());
            return const Scaffold(body: Center(child: Text('Masa aktif akun kamu sudah habis')));
          }
          final pages = [
            UpdatePage(
              cur: cur,
              cfg: cfg,
              onCheck: () {
                if (hasUpdate) {
                  maybePrompt(force: true);
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Sudah versi terbaru')));
                }
              },
            ),
            const SizedBox(),
            ProfilePage(me: me),
          ];
          return Scaffold(
            body: SafeArea(
              child: tab == 1
                  ? ChatListPage(me: me)
                  : ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 20), children: [pages[tab]]),
            ),
            bottomNavigationBar: NavigationBar(
              backgroundColor: card,
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
                NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
          );
        },
      );
}

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> me;
  const ProfilePage({super.key, required this.me});
  @override
  Widget build(BuildContext context) {
    final rank = me['rank'] as String;
    final r = ranks[rank] ?? ranks['user']!;
    final name = me['username'] as String;
    return Column(children: [
      box(Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: bg, border: Border.all(color: line, width: 2)),
          child: Icon(r.icon, size: 38, color: r.solid),
        ),
        const SizedBox(height: 14),
        RankText(name, rank, size: 28),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => showRankList(context),
          child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.icon, size: 16, color: r.solid),
            const SizedBox(width: 6),
            RankText(r.name, rank, size: 13),
          ]),
        )),
        const SizedBox(height: 8),
      ])),
      box(Column(children: [
        infoRow(Icons.badge_outlined, 'Username', Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
        InkWell(
          onTap: () => showRankList(context),
          child: infoRow(r.icon, 'Rank', Row(mainAxisSize: MainAxisSize.min, children: [
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right, size: 18, color: mu),
          ])),
        ),
        infoRow(Icons.timer_outlined, 'Masa aktif',
            Text(me['expires_at'] == null ? 'Lifetime' : (me['expires_at'] as String).substring(0, 10),
                style: const TextStyle(fontWeight: FontWeight.w700))),
        infoRow(Icons.calendar_today_outlined, 'Bergabung',
            Text((me['created_at'] as String).substring(0, 10), style: const TextStyle(fontWeight: FontWeight.w700))),
      ])),
      if (rank == 'developer' || rank == 'helper') ...[
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersPage())),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Kelola User'),
            style: FilledButton.styleFrom(
                backgroundColor: ac,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 10),
      ],
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => sb.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]);
  }
}

class RankPage extends StatelessWidget {
  const RankPage({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Daftar Rank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        box(Column(
          children: ranks.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Icon(e.value.icon, color: e.value.solid),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        RankText(e.value.name, e.key),
                        Text(e.value.desc, style: const TextStyle(color: mu, fontSize: 12)),
                      ]),
                    ]),
                  ))
              .toList(),
        )),
      ]);
}

class UpdatePage extends StatelessWidget {
  final int cur;
  final Map<String, dynamic>? cfg;
  final VoidCallback onCheck;
  const UpdatePage({super.key, required this.cur, required this.cfg, required this.onCheck});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        box(Column(children: [
          infoRow(Icons.sell_outlined, 'Build terpasang', Text('$cur', style: const TextStyle(fontWeight: FontWeight.w700))),
          infoRow(Icons.refresh, 'Versi terbaru',
              Text(cfg == null ? '-' : '${cfg!['version_name']} (${cfg!['version_code']})',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ])),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: onCheck,
            icon: const Icon(Icons.refresh),
            label: const Text('Cek update'),
            style: FilledButton.styleFrom(
                backgroundColor: ac,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]);
}

// ---------- UPDATE DIALOG (download otomatis) ----------
class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> cfg;
  final bool force;
  const UpdateDialog({super.key, required this.cfg, required this.force});
  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double pct = 0;
  String msg = 'Mengunduh...';
  bool err = false;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    try {
      final req = http.Request('GET', Uri.parse(widget.cfg['apk_url'] as String));
      final res = await http.Client().send(req);
      if (res.statusCode != 200) throw Exception('http ${res.statusCode}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nnevapp.apk');
      final sink = file.openWrite();
      final total = res.contentLength ?? 0;
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && mounted) {
          setState(() {
            pct = got / total;
            msg = 'Mengunduh ${(pct * 100).toInt()}%';
          });
        }
      }
      await sink.close();
      if (!mounted) return;
      setState(() {
        pct = 1;
        msg = 'Membuka installer...';
      });
      final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (r.type != ResultType.done && mounted) {
        setState(() {
          err = true;
          msg = 'Izinkan install dari sumber ini, lalu coba lagi';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          err = true;
          msg = 'Gagal mengunduh';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)]),
                ),
                child: const Icon(Icons.download, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(widget.force ? 'Update Wajib' : 'Update Tersedia',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Versi ${widget.cfg['version_name']}\n${widget.cfg['changelog'] ?? ''}',
                  textAlign: TextAlign.center, style: const TextStyle(color: mu)),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: err ? 0 : pct, minHeight: 8, backgroundColor: bg),
              ),
              const SizedBox(height: 10),
              Text(msg, style: const TextStyle(color: mu, fontSize: 13)),
              const SizedBox(height: 14),
              if (err)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => setState(() {
                      err = false;
                      pct = 0;
                      msg = 'Mengunduh...';
                      start();
                    }),
                    child: const Text('Coba lagi'),
                  ),
                ),
              if (!widget.force)
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
            ]),
          ),
        ),
      );
}

// ---------- HELPER ----------
void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

void showRankList(BuildContext c) => showModalBottomSheet(
      context: c,
      backgroundColor: bg,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.all(18),
        child: SingleChildScrollView(child: RankPage()),
      ),
    );

Widget avatar(String rank, {double s = 34}) {
  final r = ranks[rank] ?? ranks['user']!;
  return Container(
    width: s,
    height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: card, border: Border.all(color: line)),
    child: Icon(r.icon, size: s * .5, color: r.solid),
  );
}

// ---------- CHAT ----------
String dmRoom(String a, String b) => a.compareTo(b) < 0 ? 'dm_${a}_$b' : 'dm_${b}_$a';

class ChatListPage extends StatefulWidget {
  final Map<String, dynamic> me;
  const ChatListPage({super.key, required this.me});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> users = [];
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    sub = sb.from('profiles').stream(primaryKey: ['id']).order('username').listen((r) {
      if (mounted) setState(() => users = r);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  void open(Map<String, dynamic>? peer) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => ChatRoomPage(me: widget.me, peer: peer)));

  @override
  Widget build(BuildContext context) {
    final myId = sb.auth.currentUser!.id;
    final others = users.where((u) => u['id'] != myId).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 20), children: [
      const Text('Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => open(null),
        child: box(Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)]),
            ),
            child: const Icon(Icons.groups_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chat Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Grup untuk semua user', style: TextStyle(color: mu, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: mu),
        ])),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Pesan pribadi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      if (others.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Belum ada user lain', style: TextStyle(color: mu))),
        )
      else
        box(Column(
          children: others.map((u) {
            final rk = (u['rank'] ?? 'user') as String;
            return InkWell(
              onTap: () => open(u),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  avatar(rk, s: 42),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RankText(u['username'] as String, rk),
                      Text((ranks[rk] ?? ranks['user']!).name,
                          style: const TextStyle(color: mu, fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: mu),
                ]),
              ),
            );
          }).toList(),
        )),
    ]);
  }
}

class ChatRoomPage extends StatefulWidget {
  final Map<String, dynamic> me;
  final Map<String, dynamic>? peer; // null = Chat Utama (grup)
  const ChatRoomPage({super.key, required this.me, this.peer});
  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ctl = TextEditingController();
  late final String room = widget.peer == null
      ? 'main'
      : dmRoom(sb.auth.currentUser!.id, widget.peer!['id'] as String);
  List<Map<String, dynamic>> msgs = [], reacts = [];
  Map<String, Map<String, dynamic>> profs = {};
  final subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    subs.add(sb.from('profiles').stream(primaryKey: ['id']).listen((r) {
      if (mounted) setState(() => profs = {for (final p in r) p['id'] as String: p});
    }));
    subs.add(sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room', room)
        .order('created_at', ascending: false)
        .limit(100)
        .listen((r) {
      if (mounted) setState(() => msgs = r);
    }));
    subs.add(sb.from('reactions').stream(primaryKey: ['message_id', 'user_id']).listen((r) {
      if (mounted) setState(() => reacts = r);
    }));
  }

  @override
  void dispose() {
    for (final s in subs) {
      s.cancel();
    }
    ctl.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final t = ctl.text.trim();
    if (t.isEmpty) return;
    ctl.clear();
    try {
      await sb.from('messages').insert({'body': t, 'room': room});
    } catch (_) {
      if (mounted) snack(context, 'Gagal mengirim pesan');
    }
  }

  Future<void> react(String mid, String emoji) async {
    final uid = sb.auth.currentUser!.id;
    final mine = reacts.where((x) => x['message_id'] == mid && x['user_id'] == uid).toList();
    try {
      if (mine.isEmpty) {
        await sb.from('reactions').insert({'message_id': mid, 'emoji': emoji});
      } else if (mine.first['emoji'] == emoji) {
        await sb.from('reactions').delete().match({'message_id': mid, 'user_id': uid});
      } else {
        await sb.from('reactions').update({'emoji': emoji}).match({'message_id': mid, 'user_id': uid});
      }
    } catch (_) {}
  }

  void pick(Map<String, dynamic> m, bool mine) {
    final id = m['id'] as String;
    final staff = widget.peer == null &&
        (widget.me['rank'] == 'developer' || widget.me['rank'] == 'helper');
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😂', '😮', '😢', '🙏']
                  .map((e) => InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          react(id, e);
                        },
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(e, style: const TextStyle(fontSize: 28))),
                      ))
                  .toList(),
            ),
            if (mine || staff)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await sb.from('messages').delete().eq('id', id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus pesan'),
              ),
          ]),
        ),
      ),
    );
  }

  Widget bubble(int i, String uid) {
    final m = msgs[i];
    final sid = m['user_id'] as String;
    final mine = sid == uid;
    final p = profs[sid];
    final rank = (p?['rank'] ?? 'user') as String;
    final name = (p?['username'] ?? '?') as String;
    final first = i == msgs.length - 1 || msgs[i + 1]['user_id'] != sid;
    final t = DateTime.parse(m['created_at'] as String).toLocal();
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final id = m['id'] as String;
    final counts = <String, int>{};
    String? my;
    for (final x in reacts.where((x) => x['message_id'] == id)) {
      final e = x['emoji'] as String;
      counts[e] = (counts[e] ?? 0) + 1;
      if (x['user_id'] == uid) my = e;
    }
    final content = GestureDetector(
      onLongPress: () => pick(m, mine),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF144D37) : card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mine ? Colors.transparent : line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (!mine && first) ...[RankText(name, rank, size: 13), const SizedBox(height: 2)],
          Text(m['body'] as String, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 2),
          Align(alignment: Alignment.centerRight, child: Text(time, style: const TextStyle(color: mu, fontSize: 10))),
        ]),
      ),
    );
    final chips = counts.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Wrap(
              spacing: 4,
              children: counts.entries
                  .map((e) => GestureDetector(
                        onTap: () => react(id, e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: e.key == my ? ac.withOpacity(.25) : card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: e.key == my ? ac : line),
                          ),
                          child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
            ),
          );
    final col = Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [content, chips],
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? 10 : 2),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine
            ? [col]
            : [first ? avatar(rank) : const SizedBox(width: 34), const SizedBox(width: 6), col],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = sb.auth.currentUser!.id;
    final peer = widget.peer;
    final prk = (peer?['rank'] ?? 'user') as String;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: card,
        title: peer == null
            ? const Text('Chat Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
            : Row(children: [
                avatar(prk, s: 32),
                const SizedBox(width: 10),
                RankText(peer['username'] as String, prk, size: 16),
              ]),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
      Expanded(
        child: msgs.isEmpty
            ? const Center(child: Text('Belum ada pesan. Mulai obrolan!', style: TextStyle(color: mu)))
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (_, i) => bubble(i, uid),
              ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: card,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctl,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: 'Tulis pesan...',
                filled: true,
                fillColor: bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF6C7BFF), Color(0xFF9400FF)]),
            ),
            child: IconButton(onPressed: send, icon: const Icon(Icons.send, color: Colors.white, size: 20)),
          ),
        ]),
      ),
    ]),
      ),
    );
  }
}

// ---------- KELOLA USER (Developer & Helper) ----------
class DurationPicker extends StatefulWidget {
  final bool allowKeep;
  final ValueChanged<int?> onChanged; // null = lifetime, -1 = tidak diubah / belum diisi
  const DurationPicker({super.key, required this.onChanged, this.allowKeep = false});
  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late String sel = widget.allowKeep ? 'keep' : 'life';
  final c = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onChanged(widget.allowKeep ? -1 : null);
  }

  Widget opt(String key, String label, int? d) => ChoiceChip(
        label: Text(label),
        selected: sel == key,
        onSelected: (_) {
          setState(() => sel = key);
          widget.onChanged(d);
        },
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, children: [
          if (widget.allowKeep) opt('keep', 'Tetap', -1),
          opt('life', 'Lifetime', null),
          opt('7', '7 hari', 7),
          opt('30', '30 hari', 30),
          opt('90', '90 hari', 90),
          ChoiceChip(
            label: const Text('Custom'),
            selected: sel == 'custom',
            onSelected: (_) {
              setState(() => sel = 'custom');
              widget.onChanged(int.tryParse(c.text) ?? -1);
            },
          ),
        ]),
        if (sel == 'custom')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah hari', border: OutlineInputBorder()),
              onChanged: (v) => widget.onChanged(int.tryParse(v) ?? -1),
            ),
          ),
      ]);
}

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});
  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final un = TextEditingController(), pw = TextEditingController();
  String rank = 'user';
  int? days;
  bool busy = false;
  List<Map<String, dynamic>> users = [];
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    sub = sb.from('profiles').stream(primaryKey: ['id']).order('created_at').listen((r) {
      if (mounted) setState(() => users = r);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> create() async {
    if (days == -1) {
      snack(context, 'Isi jumlah hari dulu');
      return;
    }
    setState(() => busy = true);
    try {
      await sb.rpc('create_user', params: {
        'p_username': un.text.trim(),
        'p_password': pw.text,
        'p_rank': rank,
        'p_days': days,
      });
      un.clear();
      pw.clear();
      if (mounted) snack(context, 'Akun berhasil dibuat');
    } on PostgrestException catch (e) {
      if (mounted) snack(context, e.message);
    } catch (_) {
      if (mounted) snack(context, 'Gagal membuat akun');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget rankChips(String sel, void Function(String) on) => Wrap(
        spacing: 6,
        children: ranks.entries
            .map((e) => ChoiceChip(
                  avatar: Icon(e.value.icon, size: 16, color: e.value.solid),
                  label: Text(e.value.name),
                  selected: sel == e.key,
                  onSelected: (_) => on(e.key),
                ))
            .toList(),
      );

  void edit(Map<String, dynamic> u) {
    var r = u['rank'] as String;
    int? d = -1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['username'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Text('Rank', style: TextStyle(color: mu)),
              const SizedBox(height: 6),
              rankChips(r, (v) => ss(() => r = v)),
              const SizedBox(height: 14),
              const Text('Masa aktif', style: TextStyle(color: mu)),
              const SizedBox(height: 6),
              DurationPicker(allowKeep: true, onChanged: (v) => d = v),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final upd = <String, dynamic>{'rank': r};
                    if (d != -1) {
                      upd['expires_at'] =
                          d == null ? null : DateTime.now().toUtc().add(Duration(days: d!)).toIso8601String();
                    }
                    try {
                      await sb.from('profiles').update(upd).eq('id', u['id'] as String);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (_) {
                      if (ctx.mounted) snack(ctx, 'Gagal menyimpan');
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kelola User'), backgroundColor: card),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tambah user', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
                controller: un,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
                controller: pw,
                decoration: const InputDecoration(labelText: 'Password (min 6)', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            const Text('Rank', style: TextStyle(color: mu)),
            const SizedBox(height: 6),
            rankChips(rank, (v) => setState(() => rank = v)),
            const SizedBox(height: 14),
            const Text('Masa aktif', style: TextStyle(color: mu)),
            const SizedBox(height: 6),
            DurationPicker(onChanged: (v) => days = v),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: busy ? null : create,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Buat akun'),
              ),
            ),
          ])),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Daftar user', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          box(Column(
            children: users.map((u) {
              final rk = u['rank'] as String;
              final exp = u['expires_at'];
              return InkWell(
                onTap: () => edit(u),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    avatar(rk),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        RankText(u['username'] as String, rk),
                        Text(
                          '${(ranks[rk] ?? ranks['user']!).name} · ${exp == null ? 'Lifetime' : 's/d ${(exp as String).substring(0, 10)}'}',
                          style: const TextStyle(color: mu, fontSize: 12),
                        ),
                      ]),
                    ),
                    const Icon(Icons.edit_outlined, size: 18, color: mu),
                  ]),
                ),
              );
            }).toList(),
          )),
        ]),
      );
}
