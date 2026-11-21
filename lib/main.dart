import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
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
          final pages = [
            ProfilePage(me: me),
            const RankPage(),
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
          ];
          return Scaffold(
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 20), children: [pages[tab]]),
            ),
            bottomNavigationBar: NavigationBar(
              backgroundColor: card,
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Profil'),
                NavigationDestination(icon: Icon(Icons.list), label: 'Rank'),
                NavigationDestination(icon: Icon(Icons.download_outlined), label: 'Update'),
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
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 14, 5),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.icon, size: 16, color: r.solid),
            const SizedBox(width: 6),
            RankText(r.name, rank, size: 13),
          ]),
        ),
        const SizedBox(height: 8),
      ])),
      box(Column(children: [
        infoRow(Icons.badge_outlined, 'Username', Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
        infoRow(r.icon, 'Rank', Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
        infoRow(Icons.calendar_today_outlined, 'Bergabung',
            Text((me['created_at'] as String).substring(0, 10), style: const TextStyle(fontWeight: FontWeight.w700))),
      ])),
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
        const Text('Pembaruan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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

  void start() {
    try {
      OtaUpdate()
          .execute(widget.cfg['apk_url'] as String, destinationFilename: 'nnevapp.apk')
          .listen((e) {
        if (!mounted) return;
        setState(() {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              pct = (double.tryParse(e.value ?? '0') ?? 0) / 100;
              msg = 'Mengunduh ${e.value}%';
              break;
            case OtaStatus.INSTALLING:
              pct = 1;
              msg = 'Membuka installer...';
              break;
            default:
              err = true;
              msg = 'Gagal: ${e.status.name}';
          }
        });
      }, onError: (_) {
        if (mounted) {
          setState(() {
            err = true;
            msg = 'Gagal mengunduh';
          });
        }
      });
    } catch (_) {
      err = true;
      msg = 'Gagal mengunduh';
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
