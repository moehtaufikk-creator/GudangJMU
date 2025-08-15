import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() => runApp(const JMUApp());

class JMUApp extends StatefulWidget {
  const JMUApp({super.key});
  @override
  State<JMUApp> createState() => _JMUAppState();
}

class _JMUAppState extends State<JMUApp> {
  ThemeMode _mode = ThemeMode.light;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PT. JAYA MAS UTAMA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _mode,
      home: Home(onToggleTheme: (){
        setState(()=> _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
      }),
    );
  }
}

/* ===== Models & State ===== */
enum JenisTrip { pengantaran, pengambilan }
enum Kendaraan { hino4, hino6 }

class Settings {
  double capHino4Ton = 5.0;
  double capHino6Ton = 9.0;
  int tarifPerZak = 600; // muat 600 + bongkar 600
}

class OrderItem {
  int tonasa40 = 0; // 40kg
  int tonasa50 = 0; // 50kg
  int merdeka40 = 0; // 40kg
  int get totalZak => tonasa40 + tonasa50 + merdeka40;
  int get totalKg => tonasa40 * 40 + tonasa50 * 50 + merdeka40 * 40;
  double get totalTon => totalKg / 1000.0;
}

class Jadwal {
  DateTime waktu;
  String toko;
  JenisTrip jenis;
  Kendaraan kendaraan;
  OrderItem order;
  String? nopol;
  String? sopir;

  Jadwal({
    required this.waktu,
    required this.toko,
    required this.jenis,
    required this.kendaraan,
    required this.order,
    this.nopol,
    this.sopir,
  });

  int upahMuat(int tarif) => order.totalZak * tarif;
  int upahBongkar(int tarif) => order.totalZak * tarif;
  int totalUpah(int tarif) => upahMuat(tarif) + upahBongkar(tarif);
}

class AppState extends ChangeNotifier {
  final settings = Settings();
  final List<Jadwal> _list = [];
  List<Jadwal> get semua => List.unmodifiable(_list);

  void tambah(Jadwal j) { _list.add(j); notifyListeners(); }

  List<Jadwal> harian(DateTime d) => _list.where((e) =>
    e.waktu.year==d.year && e.waktu.month==d.month && e.waktu.day==d.day).toList()
    ..sort((a,b)=> a.waktu.compareTo(b.waktu));
}

/* ===== UI Shell (Tabs) ===== */
class Home extends StatefulWidget {
  const Home({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  final AppState state = AppState();
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PT. JAYA MAS UTAMA'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
            tooltip: 'Light/Dark',
          )
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Jadwal Harian'),
            Tab(text: 'Rekap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          DashboardPage(state: state),
          JadwalPage(state: state),
          RekapPage(state: state),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jadwal'),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TambahJadwalPage(state: state)),
          );
          setState((){}); // refresh
        },
      ),
    );
  }
}

/* ===== Pages ===== */

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final list = state.harian(today);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Ringkasan Hari Ini', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 12),
        _Summary(list: list, settings: state.settings),
        const SizedBox(height: 16),
        const Text('Jadwal Hari Ini', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Belum ada jadwal untuk ${DateFormat('dd MMM yyyy').format(today)}')))
        else
          ...list.map((j) => JadwalTile(j: j, settings: state.settings)),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.list, required this.settings});
  final List<Jadwal> list;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final totalZak = list.fold<int>(0, (p, e) => p + e.order.totalZak);
    final totalTon = list.fold<double>(0.0, (p, e) => p + e.order.totalTon);
    final totalUpah = list.fold<int>(0, (p, e) => p + e.totalUpah(settings.tarifPerZak));

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(title: 'Total Jadwal', value: '${list.length}'),
        _StatCard(title: 'Total Zak', value: '$totalZak'),
        _StatCard(title: 'Total Ton', value: totalTon.toStringAsFixed(2)),
        _StatCard(title: 'Total Upah', value: _rupiah(totalUpah)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});
  final String title; final String value;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ]),
        ),
      ),
    );
  }
}

class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key, required this.state});
  final AppState state;
  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final list = widget.state.harian(selected);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text('📅 ${DateFormat('dd MMM yyyy').format(selected)}', style: const TextStyle(fontWeight: FontWeight.w600))),
            FilledButton.tonal(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: selected);
                if (d != null) setState(()=> selected = d);
              },
              child: const Text('Pilih Tanggal'),
            ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
            ? const Center(child: Text('Belum ada jadwal di hari ini'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => JadwalTile(j: list[i], settings: widget.state.settings),
              ),
        )
      ],
    );
  }
}

class RekapPage extends StatelessWidget {
  const RekapPage({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final all = state.semua;
    final totalZak = all.fold<int>(0, (p, e) => p + e.order.totalZak);
    final totalTon = all.fold<double>(0.0, (p, e) => p + e.order.totalTon);
    final totalUpah = all.fold<int>(0, (p, e) => p + e.totalUpah(state.settings.tarifPerZak));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Rekap Seluruh Jadwal (saat aplikasi hidup)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kv('Total Jadwal', '${all.length}'),
            _kv('Total Zak', '$totalZak'),
            _kv('Total Ton', totalTon.toStringAsFixed(2)),
            _kv('Total Upah', _rupiah(totalUpah)),
          ]),
        )),
        const SizedBox(height: 12),
        ...all.map((j) => JadwalTile(j: j, settings: state.settings)),
      ],
    );
  }
}

class JadwalTile extends StatelessWidget {
  const JadwalTile({super.key, required this.j, required this.settings});
  final Jadwal j; final Settings settings;

  String _kendText(Kendaraan k) => k == Kendaraan.hino4 ? 'Hino 4 Roda' : 'Hino 6 Roda';

  @override
  Widget build(BuildContext context) {
    final jam = DateFormat('HH:mm').format(j.waktu);
    final detail = '${j.order.totalZak} zak • ${j.order.totalTon.toStringAsFixed(2)} ton';
    return Card(
      child: ListTile(
        title: Text('${j.toko} • ${_kendText(j.kendaraan)}'),
        subtitle: Text('$jam • ${j.jenis == JenisTrip.pengantaran ? 'Pengantaran' : 'Pengambilan'} • $detail'),
        trailing: Text(_rupiah(j.totalUpah(settings.tarifPerZak))),
      ),
    );
  }
}

/* ===== Form Tambah Jadwal ===== */
class TambahJadwalPage extends StatefulWidget {
  const TambahJadwalPage({super.key, required this.state});
  final AppState state;
  @override
  State<TambahJadwalPage> createState() => _TambahJadwalPageState();
}

class _TambahJadwalPageState extends State<TambahJadwalPage> {
  final _form = GlobalKey<FormState>();
  DateTime _waktu = DateTime.now();
  final _toko = TextEditingController();
  final _nopol = TextEditingController();
  final _sopir = TextEditingController();
  JenisTrip _jenis = JenisTrip.pengantaran;
  Kendaraan _kend = Kendaraan.hino4;
  int _zakT40 = 0, _zakT50 = 0, _zakM40 = 0;

  @override
  void dispose() { _toko.dispose(); _nopol.dispose(); _sopir.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.state.settings;
    final order = OrderItem()..tonasa40 = _zakT40..tonasa50 = _zakT50..merdeka40 = _zakM40;
    final totalZak = order.totalZak;
    final upahMuat = totalZak * s.tarifPerZak;
    final upahBongkar = upahMuat;
    final totalUpah = upahMuat + upahBongkar;
    final totalTon = order.totalTon;
    final cap = _kend == Kendaraan.hino4 ? s.capHino4Ton : s.capHino6Ton;
    final overload = totalTon > cap;

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Jadwal')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: Text('Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format(_waktu)}')),
              IconButton(
                icon: const Icon(Icons.edit_calendar_outlined),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _waktu);
                  if (d == null) return;
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_waktu));
                  setState(()=> _waktu = DateTime(d.year,d.month,d.day, t?.hour ?? 0, t?.minute ?? 0));
                },
              )
            ]),
            const SizedBox(height: 8),
            TextFormField(
              controller: _toko,
              decoration: const InputDecoration(labelText: 'Nama Toko', border: OutlineInputBorder()),
              validator: (v)=> (v==null||v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<JenisTrip>(
                value: _jenis,
                decoration: const InputDecoration(labelText: 'Jenis', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: JenisTrip.pengantaran, child: Text('Pengantaran')),
                  DropdownMenuItem(value: JenisTrip.pengambilan, child: Text('Pengambilan')),
                ],
                onChanged: (v){ if(v!=null) setState(()=> _jenis=v); },
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<Kendaraan>(
                value: _kend,
                decoration: const InputDecoration(labelText: 'Kendaraan', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: Kendaraan.hino4, child: Text('Hino 4 Roda')),
                  DropdownMenuItem(value: Kendaraan.hino6, child: Text('Hino 6 Roda')),
                ],
                onChanged: (v){ if(v!=null) setState(()=> _kend=v); },
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _nopol,
                decoration: const InputDecoration(labelText: 'No. Polisi (opsional)', border: OutlineInputBorder()),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _sopir,
                decoration: const InputDecoration(labelText: 'Nama Sopir (opsional)', border: OutlineInputBorder()),
              )),
            ]),
            const SizedBox(height: 16),
            const Text('Jumlah Zak per Jenis Barang', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ZakInput(label: 'Semen Tonasa 40kg', onChanged: (n)=> setState(()=> _zakT40=n)),
            const SizedBox(height: 8),
            _ZakInput(label: 'Semen Tonasa 50kg', onChanged: (n)=> setState(()=> _zakT50=n)),
            const SizedBox(height: 8),
            _ZakInput(label: 'Semen Merdeka 40kg', onChanged: (n)=> setState(()=> _zakM40=n)),
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Hasil Otomatis', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _kv('Total Zak', '$totalZak'),
                _kv('Total Kg', '${order.totalKg} kg'),
                _kv('Total Ton', totalTon.toStringAsFixed(2)),
                const Divider(height: 20),
                _kv('Upah Muat', _rupiah(upahMuat)),
                _kv('Upah Bongkar', _rupiah(upahBongkar)),
                _kv('Total Upah', _rupiah(totalUpah)),
                const SizedBox(height: 8),
                overload
                  ? Text('⚠️ Overload: > ${cap.toStringAsFixed(1)} ton', style: TextStyle(color: Theme.of(context).colorScheme.error))
                  : const Text('Kapasitas Aman ✅'),
              ]),
            )),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (){
                if (!_form.currentState!.validate()) return;
                final jadwal = Jadwal(
                  waktu: _waktu,
                  toko: _toko.text.trim(),
                  jenis: _jenis,
                  kendaraan: _kend,
                  order: order,
                  nopol: _nopol.text.trim().isEmpty ? null : _nopol.text.trim(),
                  sopir: _sopir.text.trim().isEmpty ? null : _sopir.text.trim(),
                );
                widget.state.tambah(jadwal);
                Navigator.pop(context);
              },
              child: const Text('Simpan Jadwal'),
            )
          ],
        ),
      ),
    );
  }
}

class _ZakInput extends StatefulWidget {
  const _ZakInput({required this.label, required this.onChanged});
  final String label;
  final ValueChanged<int> onChanged;
  @override
  State<_ZakInput> createState() => _ZakInputState();
}
class _ZakInputState extends State<_ZakInput> {
  final c = TextEditingController(text: '0');
  @override void dispose(){ c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex:2, child: Text(widget.label)),
      const SizedBox(width: 12),
      Expanded(child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0'),
        onChanged: (v){
          final n = int.tryParse(v) ?? 0;
          widget.onChanged(n < 0 ? 0 : n);
        },
      )),
    ]);
  }
}

/* ===== Helpers ===== */
Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(children: [
    Expanded(child: Text(k)),
    Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
  ]),
);

String _rupiah(int n){
  final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  return f.format(n);
}
