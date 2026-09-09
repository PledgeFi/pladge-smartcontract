# Panduan Verifikasi Blockscout — Robinhood Mainnet 4663

Kesepuluh kontrak sudah terverifikasi **exact match** di [Sourcify](https://sourcify.dev). Folder ini
ada karena Blockscout di chain ini berada di belakang Cloudflare dan menolak semua permintaan
otomatis, sehingga `forge verify-contract` tidak bisa menjangkaunya. Verifikasi harus dilakukan
manual dari browser.

Explorer: https://robinhoodchain.blockscout.com

Metode **Sourcify** tidak tersedia di dropdown Blockscout ini, jadi kita pakai **Standard JSON
Input**. Semua berkas yang dibutuhkan sudah disiapkan di folder ini.

---

## Pengaturan yang sama untuk kesepuluh kontrak

Hafalkan sekali, dipakai berulang:

| Field | Isi |
|---|---|
| Verification method | **Solidity (Standard JSON Input)** |
| Compiler | **v0.8.24+commit.e11b9ed9** |
| Optimization enabled | **Yes** |
| Optimization runs | **200** |

Yang berbeda tiap kontrak hanya dua: berkas `.json` yang diunggah dan isi field
**Constructor Arguments**.

## Constructor Arguments — kosongkan

**Biarkan field ini kosong untuk kesepuluh kontrak.**

Pada mode Standard JSON Input, Blockscout menurunkan sendiri constructor argument dari transaksi
pembuatan kontrak. Menempelkannya secara manual membuat nilainya terhitung dua kali dan verifikasi
gagal dengan keluhan bytecode tidak cocok. Ini terbukti di lapangan: kontrak pertama yang field-nya
dikosongkan langsung berhasil, sedangkan yang argumennya ditempel semuanya gagal.

Berkas `.args.txt` di folder ini tetap disimpan sebagai cadangan, kalau-kalau Blockscout justru
mewajibkan field tersebut diisi. Isinya sudah diverifikasi cocok dengan ekor input transaksi
pembuatan tiap kontrak. Kalau perlu dipakai:

```
cd verification
pbcopy < 01-vault-proxy.args.txt
```

Kalau versi tanpa `0x` ditolak, coba tambahkan awalan `0x`.

---

## Urutan pengerjaan

Kerjakan lima implementasi lebih dulu, baru lima proxy. Alasannya ada di bagian
[Kenapa implementasi didahulukan](#kenapa-implementasi-didahulukan).

### Tahap 1 — Implementasi

**1. PledgeChainlinkOracle** — mulai dari sini, satu-satunya tanpa constructor argument, cocok untuk
mengenali alur formulirnya.

- Halaman: https://robinhoodchain.blockscout.com/address/0x428AceFE3bc2Da5a4B9b1615Ae066Bf81Be794cc/contract-verification
- Unggah: `07-oracle-impl.json`
- Constructor args: **kosongkan**

**2. PledgeSurplusBuffer**

- Halaman: https://robinhoodchain.blockscout.com/address/0x5df0d2c7aB8443f41B84e684027eEB656e303C12/contract-verification
- Unggah: `08-surplus-impl.json`
- Constructor args: **kosongkan**

**3. PledgeStabilityPool**

- Halaman: https://robinhoodchain.blockscout.com/address/0x3fc952F815f63dE054446D4c3C16c57d6467635D/contract-verification
- Unggah: `09-pool-impl.json`
- Constructor args: **kosongkan**

**4. PledgeStaking**

- Halaman: https://robinhoodchain.blockscout.com/address/0x4de94A31e0725270b047820293e784bb62363Be3/contract-verification
- Unggah: `10-staking-impl.json`
- Constructor args: **kosongkan**

**5. PledgeVaultManager**

- Halaman: https://robinhoodchain.blockscout.com/address/0x0b8E032242A54a5373aed9968FEF01a9A0e0ec6F/contract-verification
- Unggah: `06-vault-impl.json`
- Constructor args: **kosongkan**

### Tahap 2 — Proxy (inilah yang bernama PledgeFinance)

**6. PledgeFinanceVault**

- Halaman: https://robinhoodchain.blockscout.com/address/0x83B6F15BD3A7385C0F55BA3C685f688511279B00/contract-verification
- Unggah: `01-vault-proxy.json`
- Constructor args: **kosongkan**

**7. PledgeFinanceOracle**

- Halaman: https://robinhoodchain.blockscout.com/address/0xB11951Dba2A7cAF846e0A3484237d8E5844428b7/contract-verification
- Unggah: `02-oracle-proxy.json`
- Constructor args: **kosongkan**

**8. PledgeFinanceSurplusBuffer**

- Halaman: https://robinhoodchain.blockscout.com/address/0xc6D477491ACE30fa5651ac61C735C2B636B095c4/contract-verification
- Unggah: `03-surplus-proxy.json`
- Constructor args: **kosongkan**

**9. PledgeFinanceStabilityPool**

- Halaman: https://robinhoodchain.blockscout.com/address/0xf70D2a727E72b6890Bd269f5f8AdE7c86F3D244D/contract-verification
- Unggah: `04-pool-proxy.json`
- Constructor args: **kosongkan**

**10. PledgeFinanceStaking**

- Halaman: https://robinhoodchain.blockscout.com/address/0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07/contract-verification
- Unggah: `05-staking-proxy.json`
- Constructor args: **kosongkan**

---

## Menandai keberhasilan

Setelah klik **Verify & publish**, tunggu 10–30 detik. Kalau berhasil, halaman berpindah ke tab
**Contract** dengan centang hijau, nama kontrak muncul di sebelah alamat, dan muncul tab **Read
contract** serta **Write contract**.

Khusus kelima proxy, yang muncul adalah **Read as Proxy** dan **Write as Proxy** — ini yang
menandakan Blockscout berhasil mengaitkan proxy ke implementasinya.

## Kenapa implementasi didahulukan

Blockscout mengenali proxy EIP-1967 secara otomatis, tapi tab **Read as Proxy** dan **Write as
Proxy** baru muncul kalau implementasi di belakangnya sudah terverifikasi lebih dulu. Kalau hanya
proxy yang dikerjakan, halamannya tetap bernama `PledgeFinanceVault` tapi tidak ada fungsi yang bisa
dipanggil dari sana.

## Kalau gagal

**Bytecode tidak cocok** — periksa dulu field Constructor Arguments benar-benar kosong. Inilah
penyebab tersering: Blockscout sudah menurunkan argumennya sendiri, jadi nilai yang ditempel
terhitung dua kali. Baru kalau dikosongkan pun tetap gagal, coba isi dari `.args.txt`, mula-mula
tanpa `0x` lalu dengan `0x`.

**Compiler version mismatch** — harus persis `v0.8.24+commit.e11b9ed9`. Jangan pilih `0.8.24` versi
nightly atau commit lain.

**Optimization mismatch** — enabled **Yes**, runs **200**. Nilai bawaan Blockscout kadang 200 kadang
kosong, jadi selalu periksa.

**Sudah terverifikasi** — kalau muncul pesan bahwa kontrak sudah diverifikasi, berarti sudah beres,
lanjut ke nomor berikutnya.

## Membuat ulang berkas di folder ini

```
forge verify-contract <address> <path>:<Name> --show-standard-json-input > out.json
```

Jalankan di luar sandbox; Foundry butuh akses tulis ke direktori cache-nya sendiri.

## Rujukan alamat

| Modul | Proxy | Implementasi |
|---|---|---|
| Vault | `0x83B6F15BD3A7385C0F55BA3C685f688511279B00` | `0x0b8E032242A54a5373aed9968FEF01a9A0e0ec6F` |
| Oracle | `0xB11951Dba2A7cAF846e0A3484237d8E5844428b7` | `0x428AceFE3bc2Da5a4B9b1615Ae066Bf81Be794cc` |
| Surplus Buffer | `0xc6D477491ACE30fa5651ac61C735C2B636B095c4` | `0x5df0d2c7aB8443f41B84e684027eEB656e303C12` |
| Stability Pool | `0xf70D2a727E72b6890Bd269f5f8AdE7c86F3D244D` | `0x3fc952F815f63dE054446D4c3C16c57d6467635D` |
| Staking | `0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07` | `0x4de94A31e0725270b047820293e784bb62363Be3` |
