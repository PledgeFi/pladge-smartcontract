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

| # | Nama di chain sekarang | Token stake | Status | Rencana |
| --- | --- | --- | --- | --- |
| 0 | `PLG Staking` | PLG **lama** `0xDfC0a301…` | mati | ganti nama jadi `PLG Staking (retired)` |
| 1 | `USDG Staking` | USDG `0x5fc5360D…` | mati | ganti nama jadi `USDG Staking (retired)` |
| 2 | `PONS Staking` | **PLG `0x1BE30101…`** | aktif | ganti nama jadi `PLG Staking` — ini satu-satunya pool yang dipakai |

Pool 2 kecepatan hadiahnya 6.111,11 PLG per hari, kunci 1–90 hari. Token yang
di-stake dan token hadiahnya sama-sama `0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf`.

Kolom "Nama di chain sekarang" mencatat apa yang benar-benar ada di blockchain hari
ini, bukan yang kita inginkan. Jalankan Langkah 2 dan kolom itu berubah.

### Yang TIDAK bisa dilakukan

**Pool 0 dan 1 tidak bisa dihapus, dan tokennya tidak bisa diganti ke PLG baru.**

Ini batasan kontrak, bukan pilihan kita. Daftar pool di dalam kontrak hanya bisa
ditambah — tidak ada fungsi untuk menghapus. Dan token sebuah pool ditetapkan sekali
saat pool dibuat, tidak ada fungsi untuk menggantinya. Jadi pool 0 akan selamanya
berisi PLG lama, dan pool 1 akan selamanya berisi USDG.

Yang bisa dilakukan ada tiga, dan ketiganya sudah atau akan dikerjakan:

1. Dimatikan supaya tidak ada yang bisa masuk — **sudah**, keduanya `active = false`.
2. Diberi nama yang jelas supaya tidak tertukar — Langkah 2.
3. Disembunyikan dari website — **sudah**, website dan admin dashboard hanya
   menampilkan pool yang hidup. Di admin ada tombol "Show retired" kalau perlu.

Hasil akhirnya: pengguna hanya melihat satu pool, yaitu pool 2 dengan PLG
`0x1BE30101…`. Pool 0 dan 1 tetap ada di blockchain, tapi tidak terlihat dan tidak
bisa dimasuki.

### Jebakan dua token bernama sama

PLG lama `0xDfC0a301…` **juga** memakai simbol `PLG`. Jadi kalau Anda membedakan lewat
nama atau simbol token, keduanya terlihat identik. Selalu cocokkan alamatnya.

| Token | Alamat | Dipakai? |
| --- | --- | --- |
| PLG live | `0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf` | **ya, ini satu-satunya** |
| PLG lama (launchpad) | `0xDfC0a301CA6F62c32800C4827974ECac64BC7e38` | tidak, jangan disentuh |

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

### Langkah 2 — Hapus nama "PONS", jadikan "PLG Staking"

Nama pool tersimpan di dalam kontrak dan website menampilkannya apa adanya. Jadi
selama transaksi ini belum jalan, pengguna tetap melihat tulisan "PONS Staking",
sebersih apa pun kode kita.

Skrip di bawah mengganti nama ketiga pool sekaligus:

| # | Dari | Jadi |
| --- | --- | --- |
| 0 | `PLG Staking` | `PLG Staking (retired)` |
| 1 | `USDG Staking` | `USDG Staking (retired)` |
| 2 | `PONS Staking` | `PLG Staking` |

Urutannya penting: pool 0 **sudah** memakai nama `"PLG Staking"` padahal isinya token
lama. Kalau pool 2 diganti duluan, akan ada dua pool bernama sama dan pengguna tidak
bisa membedakannya. Skrip sudah mengurutkannya dengan benar. Sebelum mengirim apa pun
dia juga memeriksa bahwa tiap pool berisi token yang diharapkan — dicocokkan lewat
alamat — dan bahwa pool 0 dan 1 memang sudah mati, supaya label "retired" tidak bohong.
Kalau ada satu saja yang tidak cocok, skripnya berhenti tanpa mengirim transaksi.

```bash
export DEPLOYER_PRIVATE_KEY=...   # dompet pemilik 0x82FBf398…
RPC=https://rpc.mainnet.chain.robinhood.com

# 1. Uji dulu tanpa mengirim apa pun — wajib
forge script script/mainnet/13_RenameStakingPools.s.sol --rpc-url $RPC

# 2. Kalau lognya benar, baru kirim
forge script script/mainnet/13_RenameStakingPools.s.sol --rpc-url $RPC --broadcast
```

Perintah pertama tidak mengirim transaksi, hanya mensimulasikan. Baca lognya: harus
tertulis nama sebelum dan sesudah. Kalau ada yang janggal, jangan lanjut.

Bisa juga lewat admin dashboard kalau lebih nyaman: tekan "Show retired" untuk melihat
pool 0 dan 1, ganti nama keduanya dulu, baru ganti pool 2 jadi `PLG Staking`.

Sesudah ini, cek hasilnya:

```bash
NEW=0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07
for i in 0 1 2; do cast call $NEW "poolNames(uint256)(string)" $i --rpc-url $RPC; done
```

Harus keluar `PLG Staking (retired)`, `USDG Staking (retired)`, `PLG Staking`. Tidak
boleh ada lagi tulisan PONS.

### Langkah 2b — Pasang upgrade bonus kunci

Tanpa langkah ini, slider 1–90 hari cuma merugikan yang memakainya: hadiahnya sama
saja, tapi uangnya terkunci lebih lama. Upgrade ini yang membuat mengunci lebih lama
benar-benar dibayar lebih besar — 1,00x di 1 hari sampai 3,00x di 90 hari.

**Ini bukan kontrak baru.** Alamatnya tetap `0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07`.
Yang di-deploy adalah kode barunya saja, lalu alamat lama diarahkan ke kode itu. Daftar
pool, namanya, saldo hadiah, dan pemiliknya semua tidak tersentuh. Website dan admin
dashboard tidak perlu diubah atau di-deploy ulang — keduanya sudah menunggu fitur ini
dan menyala sendiri begitu upgrade-nya mendarat.

Upgrade ini sekalian membawa `emergencyWithdraw`, jalan keluar untuk menarik pokok
tanpa menyentuh token hadiah.

**Syarat mutlak: tidak boleh ada satu pun yang sedang staking.** Upgrade ini mengubah
satuan pembagian hadiah dari "per token" menjadi "per bobot". Utang hadiah milik posisi
yang sudah jalan tercatat dalam satuan lama, dan tidak ada cara menulis ulangnya —
kontrak tidak menyimpan daftar staker. Jadi posisi yang terbuka akan salah hitung.
Skripnya memeriksa ini sendiri dan berhenti kalau ada yang staking. Saat ini ketiga
pool masih kosong, jadi aman — tapi ini alasan kuat untuk **menjalankannya sebelum
pool diisi dan dibuka**.

Harus dijalankan **sebelum** kepemilikan dipindah ke timelock.

```bash
export DEPLOYER_PRIVATE_KEY=...   # dompet pemilik 0x82FBf398…
RPC=https://rpc.mainnet.chain.robinhood.com

# 1. Uji dulu tanpa mengirim apa pun — wajib
forge script script/mainnet/14_UpgradeStakingWithBoost.s.sol --rpc-url $RPC

# 2. Kalau lognya benar, baru kirim
forge script script/mainnet/14_UpgradeStakingWithBoost.s.sol --rpc-url $RPC --broadcast
```

Lognya harus menampilkan pengali 10000 di 1 hari, 16516 di 30 hari, dan 30000 di 90
hari — yaitu 1,00x, 1,65x, dan 3,00x. Skrip juga memeriksa sendiri sesudah mengirim
bahwa kode barunya benar-benar hidup; kalau tidak, dia gagal dengan pesan yang jelas.

Catat alamat implementation yang keluar di log ke `deployments/4663.json`.

Cek hasilnya:

```bash
NEW=0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07
cast call $NEW "maxBoostBps(uint256)(uint256)" 2 --rpc-url $RPC          # 30000
cast call $NEW "multiplierBps(uint256,uint256)(uint256)" 2 86400 --rpc-url $RPC   # 10000
cast call $NEW "multiplierBps(uint256,uint256)(uint256)" 2 7776000 --rpc-url $RPC # 30000
```

Angka 3,00x bisa diubah kapan saja lewat admin dashboard, field "Reward multiplier at
the longest lock", tanpa upgrade lagi. Batasnya dikunci di 1x sampai 10x supaya satu
whale berkunci panjang tidak bisa menyedot seluruh emisi.

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

**Tidak perlu memindahkan PLG ke dompet owner dulu.** `fundRewards` sengaja tidak
dibatasi pemilik — tidak ada `onlyOwner` di situ — jadi dompet mana pun yang memegang
PLG bisa mengisi kantong hadiah langsung. Memindahkannya dulu hanya menambah satu
transaksi dan satu peluang salah kirim.

Dompet yang disiapkan untuk ini: `0x876f12d8043cD7a87D0eb512c29d5Ad58C92B055`.
Per 12 September 2026 dompet itu masih kosong, dan **juga belum punya native token
untuk bayar gas**. Keduanya harus ada sebelum perintah di bawah bisa jalan.

Yang tetap wajib dari dompet owner hanyalah membuka saklar pool di Langkah 4b.

```bash
PLG=0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf
AMOUNT=550000000000000000000000   # 550.000 PLG
FUNDER_KEY=...                    # dompet yang memegang PLG, bukan harus owner

cast send $PLG "approve(address,uint256)" $NEW $AMOUNT --rpc-url $RPC --private-key $FUNDER_KEY
cast send $NEW "fundRewards(uint256,uint256)" 2 $AMOUNT --rpc-url $RPC --private-key $FUNDER_KEY
```

Cara paling mudah lewat admin dashboard: sambungkan dompet pemegang PLG itu — bukan
dompet owner — lalu buka `/staking` dan pakai kartu "Fund rewards". Approve-nya
otomatis. Kartu itu memang tidak dikunci ke owner, jadi dompet mana pun bisa memakainya.

Verifikasi — angka terakhir harus sama dengan jumlah yang diisi:

```bash
cast call $NEW "pools(uint256)(address,address,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256)" 2 --rpc-url $RPC
```

Setelah ini website akan menampilkan APR dan kolom "Rewards last" berisi 90 hari.
Selama saldo hadiah masih nol, website menolak stake dan menampilkan peringatan.

### Langkah 4b — Buka kembali pool 2

Pool 2 ditutup pada 12 September 2026 dengan `setPoolActive(2, false)`, karena saat itu
saldo hadiahnya nol. Membiarkannya terbuka berarti menjebak orang: uang mereka terkunci
sampai 90 hari sementara bunganya nol, dan halaman staking menjanjikan bonus 3,00x yang
tidak bisa ditepati.

Jangan jalankan ini sebelum Langkah 4 selesai dan saldonya sudah terverifikasi.

Ini satu-satunya langkah di alur pendanaan yang **wajib** dari dompet owner.

```bash
cast send $NEW "setPoolActive(uint256,bool)" 2 true --rpc-url $RPC --private-key $OWNER_KEY
```

Bisa juga lewat admin dashboard, tombol aktif/nonaktif di kartu edit pool.

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
