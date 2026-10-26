// Tugas Rutin 4: Sistem Parkir (versi 3: Terminal, factory + slot berbeda)
// Nama: ................  NIM: ................
import 'dart:async';

abstract class Kendaraan {
  static int jumlahDibuat = 0;

  final String plat;
  Kendaraan(this.plat) {
    jumlahDibuat++;
  }

  /// Factory: membuat subclass yang sesuai dari teks jenis.
  factory Kendaraan.buat(String jenis, String plat, {bool member = false}) =>
      switch ((jenis.toLowerCase(), member)) {
        ('motor', _) => Motor(plat),
        ('mobil', true) => MobilMember(plat),
        ('mobil', false) => Mobil(plat),
        ('bus', _) => Bus(plat),
        _ => throw FormatException('Jenis tidak dikenal: $jenis'),
      };

  String get jenis;
  int get tarifPerJam;
  int get slot => 1; // polimorfisme: Bus memakai 2 slot

  int biaya(int jam) => tarifPerJam * (jam < 1 ? 1 : jam);
}

class Motor extends Kendaraan {
  Motor(super.plat);
  @override
  String get jenis => 'Motor';
  @override
  int get tarifPerJam => 1500;
}

class Mobil extends Kendaraan {
  Mobil(super.plat);
  @override
  String get jenis => 'Mobil';
  @override
  int get tarifPerJam => 4000;
}

class Bus extends Kendaraan {
  Bus(super.plat);
  @override
  String get jenis => 'Bus';
  @override
  int get tarifPerJam => 9000;
  @override
  int get slot => 2;
}

mixin DiskonMember on Kendaraan {
  int get persenDiskon => 30;

  @override
  int biaya(int jam) => super.biaya(jam) * (100 - persenDiskon) ~/ 100;
}

class MobilMember extends Mobil with DiskonMember {
  MobilMember(super.plat);
  @override
  String get jenis => 'Mobil (member)';
}

class ParkirPenuh implements Exception {
  final String pesan;
  ParkirPenuh(this.pesan);
  @override
  String toString() => pesan;
}

class KendaraanTidakAda implements Exception {
  final String plat;
  KendaraanTidakAda(this.plat);
  @override
  String toString() => 'Kendaraan $plat tidak ditemukan';
}

class PlatSudahAda implements Exception {
  final String plat;
  PlatSudahAda(this.plat);
  @override
  String toString() => 'Plat $plat sudah terparkir';
}

class Parkiran {
  final int kapasitas;
  final _aktif = <String, Kendaraan>{};
  int _pendapatan = 0;
  final _log = StreamController<String>.broadcast();

  Parkiran(this.kapasitas);

  int get terpakai => _aktif.values.fold<int>(0, (s, k) => s + k.slot);
  int get sisa => kapasitas - terpakai;
  int get pendapatan => _pendapatan;
  Stream<String> get layarPos => _log.stream;

  Future<void> masuk(Kendaraan k) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_aktif.containsKey(k.plat)) throw PlatSudahAda(k.plat);
    if (k.slot > sisa) {
      throw ParkirPenuh('Slot tidak cukup: butuh ${k.slot}, sisa $sisa');
    }
    _aktif[k.plat] = k;
    _log.add('MASUK  ${k.jenis} ${k.plat} (sisa slot $sisa)');
  }

  Future<int> keluar(String plat, {required int jam}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final k = _aktif.remove(plat);
    if (k == null) throw KendaraanTidakAda(plat);
    final bayar = k.biaya(jam);
    _pendapatan += bayar;
    _log.add('KELUAR ${k.jenis} ${k.plat} bayar Rp$bayar');
    return bayar;
  }

  Future<void> tutup() => _log.close();
}

Future<void> main() async {
  final parkir = Parkiran(5);
  parkir.layarPos.listen(
    (e) => print('[POS] $e'),
    onDone: () => print('[POS] layar ditutup'),
  );

  Future<void> coba(Future<void> Function() aksi) async {
    try {
      await aksi();
    } on ParkirPenuh catch (e) {
      print('Ditolak: $e');
    } on Exception catch (e) {
      print('Gagal: $e');
    }
  }

  await coba(() => parkir.masuk(Kendaraan.buat('motor', 'BK 1 A')));
  await coba(() => parkir.masuk(Kendaraan.buat('bus', 'BK 2 B')));
  await coba(() => parkir.masuk(Kendaraan.buat('mobil', 'BK 3 C', member: true)));
  await coba(() => parkir.masuk(Kendaraan.buat('bus', 'BK 4 D'))); // slot kurang
  await coba(() => parkir.masuk(Kendaraan.buat('truk', 'BK 5 E'))); // jenis salah
  await coba(() => parkir.keluar('BK 1 A', jam: 2));
  await coba(() => parkir.keluar('BK 2 B', jam: 3));
  await coba(() => parkir.keluar('BK 3 C', jam: 2));

  await parkir.tutup();
  print('Pendapatan: Rp${parkir.pendapatan}');
  print('Slot kosong: ${parkir.sisa} dari ${parkir.kapasitas}');
  print('Objek dibuat: ${Kendaraan.jumlahDibuat}');
}
