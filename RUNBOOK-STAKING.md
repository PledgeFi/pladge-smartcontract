# Runbook: Membuka Staking PLG

Dokumen ini berisi langkah on-chain yang harus dijalankan pemilik kontrak.
Perbaikan kode di website dan admin dashboard sudah selesai — langkah di bawah ini
tidak bisa dikerjakan dari kode karena butuh tanda tangan wallet owner.

Tanggal pemeriksaan chain: 12 September 2026.

---

## 1. Kondisi sekarang

| Hal | Nilai |
| --- | --- |
| Kontrak staking yang benar | `0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07` |
| Kontrak staking lama (jangan dipakai) | `0xA317886027c83183C22d9526bd09e9837CBc38F6` |
| Token PLG yang benar | `0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf` |
| Owner semua kontrak | `0x82FBf39835a885C1CdA3D756FB6AA79802f29e92` |
| Timelock (belum dipakai) | `0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD` |

Kontrak staking yang benar punya 3 pool:

| # | Nama sekarang | Token stake | Status | Catatan |
| --- | --- | --- | --- | --- |
| 0 | `PLG Staking` | PLG **lama** `0xDfC0a301…` | mati | namanya menyesatkan |
| 1 | `USDG Staking` | USDG | mati | tidak dipakai |
| 2 | `PONS Staking` | PLG **baru** `0x1BE30101…` | aktif | ini yang benar, tapi saldo hadiah nol |

Pool 2 kecepatan hadiahnya 6.111,11 PLG per hari, kunci 1–90 hari.

**Pool tidak bisa dihapus.** Daftar pool di kontrak hanya bisa ditambah, dan token
sebuah pool tidak bisa diganti. Jadi pool 0 dan 1 akan selamanya ada di sana. Yang
bisa dilakukan hanya membiarkannya mati — dan itu sudah.

Website dan admin dashboard sekarang menyembunyikan pool yang mati, jadi user hanya
melihat satu pool PLG. Di admin masih ada tombol "Show retired" kalau perlu melihatnya.

**Jebakan yang perlu diperhatikan:** token PLG lama `0xDfC0a301…` simbolnya juga
`PLG`. Jadi membedakan lewat nama token tidak cukup — harus lihat alamatnya.

Di kontrak staking lama, pool 0 dan 1 masih berstatus aktif. Tidak ada dana orang di
dalamnya (total stake nol), tapi selama masih aktif orang bisa masuk ke sana.

**Hal yang belum bisa saya pastikan:** 1 miliar PLG yang sudah dicetak tidak ada di
wallet manapun yang tercatat di repo ini, termasuk wallet owner. Anda perlu
memastikan sendiri wallet mana yang memegang PLG sebelum menjalankan langkah 4.

---

## 2. Urutan langkah

Urutannya penting. Langkah 6 dikerjakan paling akhir karena setelah itu setiap
perubahan harus menunggu 48 jam.

### Langkah 1 — Tutup pool di kontrak lama

Ini yang paling mendesak. Selama pool lama aktif, ada kemungkinan orang menaruh token
di kontrak yang sudah tidak dipakai.

```bash
export PATH="$HOME/.foundry/bin:$PATH"
RPC=https://rpc.mainnet.chain.robinhood.com
OLD=0xA317886027c83183C22d9526bd09e9837CBc38F6

cast send $OLD "setPoolActive(uint256,bool)" 0 false --rpc-url $RPC --private-key $OWNER_KEY
cast send $OLD "setPoolActive(uint256,bool)" 1 false --rpc-url $RPC --private-key $OWNER_KEY
```

Verifikasi — kolom kesembilan harus `false`:

```bash
cast call $OLD "pools(uint256)(address,address,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256)" 0 --rpc-url $RPC
```

### Langkah 2 — Rapikan nama pool

Nama `"PONS Staking"` tampil apa adanya di website, karena website membaca nama dari
kontrak. Tapi hati-hati: pool 0 **sudah** memakai nama `"PLG Staking"` padahal isinya
token lama. Ganti nama pool 0 dulu supaya tidak ada dua pool bernama sama.

```bash
NEW=0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07
cast send $NEW "setPoolName(uint256,string)" 0 "PLG Staking (retired)" --rpc-url $RPC --private-key $OWNER_KEY
cast send $NEW "setPoolName(uint256,string)" 2 "PLG Staking" --rpc-url $RPC --private-key $OWNER_KEY
```

Bisa juga lewat admin dashboard: tekan "Show retired" untuk melihat pool 0, pilih,
lalu isi kolom "Display name" dan tekan "Rename".

### Langkah 3 — Tentukan rentang kunci

Sekarang 1 hari sampai 90 hari. User memilih sendiri di dalam rentang itu.
Kalau ingin diubah, pakai admin dashboard: isi "Min lock days" dan "Max lock days",
lalu tombol "Set lock".

Perubahan ini hanya berlaku untuk stake baru. Orang yang sudah stake tetap memakai
waktu kunci yang mereka dapat waktu itu.

### Langkah 4 — Isi saldo hadiah

Ini yang membuat staking benar-benar jalan. Tanpa ini pool menerima token tapi tidak
membayar apa pun.

Dengan kecepatan sekarang, 6.111,11 PLG per hari:

| Mau jalan berapa lama | Butuh PLG |
| --- | --- |
| 30 hari | 183.334 |
| 90 hari | 550.000 |
| 180 hari | 1.100.000 |

Pindahkan dulu PLG ke wallet owner, lalu:

```bash
PLG=0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf
AMOUNT=550000000000000000000000   # 550.000 PLG

cast send $PLG "approve(address,uint256)" $NEW $AMOUNT --rpc-url $RPC --private-key $OWNER_KEY
cast send $NEW "fundRewards(uint256,uint256)" 2 $AMOUNT --rpc-url $RPC --private-key $OWNER_KEY
```

Bisa juga lewat admin dashboard, kartu "Fund rewards" — approve-nya otomatis.

Verifikasi — angka terakhir harus sama dengan jumlah yang diisi:

```bash
cast call $NEW "pools(uint256)(address,address,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256)" 2 --rpc-url $RPC
```

Setelah ini website akan menampilkan APR dan kolom "Rewards last" berisi 90 hari.
Selama saldo hadiah masih nol, website menolak stake dan menampilkan peringatan.

### Langkah 5 — Upgrade implementasi untuk menambah `emergencyWithdraw`

Fungsi ini sudah ditulis dan diuji di `src/core/PledgeStaking.sol`. Gunanya: menarik
pokok tanpa menyentuh token hadiah. `unstake` membayar hadiah lebih dulu, jadi kalau
transfer hadiah gagal, pokok user ikut tersandera. Ini jalan keluarnya.

Fungsi ini **tidak menambah variabel penyimpanan apa pun**, sudah diverifikasi dengan
membandingkan `forge inspect PledgeStaking storage-layout` sebelum dan sesudah — hasilnya
identik. Jadi cukup ganti implementasi, **proxy dan semua datanya tetap**.

```bash
cd pladge-smartcontract
forge build

# Deploy implementasi baru
forge create src/core/PledgeStaking.sol:PledgeStaking \
  --constructor-args 0x0000000000000000000000000000000000000000 \
  --rpc-url $RPC --private-key $OWNER_KEY

# Arahkan proxy ke implementasi baru (ganti $NEW_IMPL dengan hasil di atas)
cast send $NEW "upgradeToAndCall(address,bytes)" $NEW_IMPL 0x \
  --rpc-url $RPC --private-key $OWNER_KEY
```

Verifikasi sesudahnya — harus mengembalikan `0`, bukan error:

```bash
cast call $NEW "getPosition(uint256,address)(uint256,uint256,uint256,uint256,uint256)" 2 $DEPLOYER --rpc-url $RPC
```

Kerjakan ini **sebelum** langkah 6. Sesudah kepemilikan pindah ke timelock, upgrade
harus antre 48 jam.

Catatan: website dan admin dashboard belum memanggil fungsi ini, karena memanggilnya
sebelum upgrade akan gagal. Setelah upgrade terpasang, tombolnya bisa ditambahkan.

### Langkah 6 — Serahkan kepemilikan ke timelock

Kerjakan paling akhir, setelah semua angka di atas sudah final. Sesudah ini setiap
perubahan setting harus antre 48 jam.

```bash
TIMELOCK=0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD
cast send $NEW "transferOwnership(address)" $TIMELOCK --rpc-url $RPC --private-key $OWNER_KEY
```

---

## 3. Yang tidak dikerjakan di sini

**Alamat vault, oracle, stability pool, surplus buffer tidak diubah.**
Website masih menunjuk ke set kontrak lama untuk produk pinjaman. Ini disengaja:
vault lama masih memegang 2,01 USDG sedangkan vault baru kosong. Memindahkan alamat
sekarang akan mematikan fitur pinjam. Pemindahan itu proyek tersendiri — vault baru
harus diisi dulu dan market-nya diperiksa.

**Yang masih kurang di kontrak.** Tiga hal berikut butuh **proxy baru**, bukan sekadar
upgrade, karena mengubah tata letak penyimpanan:

- Pelindung reentrancy versi upgradeable — sekarang memakai versi biasa yang menempati
  slot 1, jadi daftar warisan kontrak tidak boleh diubah.
- `__gap` untuk ruang variabel tambahan di masa depan.
- Field tambahan di dalam `PoolInfo`, misalnya pengali hadiah untuk kunci panjang.

Selama total stake masih nol seperti sekarang, mengganti proxy tidak merugikan
siapa pun. Semakin lama ditunda, semakin mahal.

**Keputusan produk yang tertunda:** lama kunci saat ini tidak memengaruhi besar hadiah
sama sekali — pembagian murni berdasarkan jumlah token. Jadi tidak ada alasan bagi user
memilih 90 hari daripada 1 hari. Pilihannya: kunci jadi satu nilai tetap (set min = maks
lewat admin), atau tambah pengali hadiah — yang kedua butuh proxy baru.
