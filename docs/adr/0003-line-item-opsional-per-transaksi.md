# Line item (struk) opsional per transaksi

Satu transaksi belanja dapat dipecah menjadi item-item produk (nama + harga +
qty) dengan total terhitung otomatis. Item bersifat opsional: transaksi tanpa
item tetap valid dengan nominal manual.

**Considered Options**: (a) nominal flat tanpa rincian — sederhana tapi
kehilangan detail struk; (b) item wajib — rinci tapi memperlambat pencatatan
kilat.

**Alasan**: (a) gagal memenuhi kebutuhan nyata pengguna (belanja Indomaret =
banyak produk); (b) melanggar prinsip "catat < 10 detik". Opsional memberi
keduanya: cepat saat buru-buru, rinci saat sempat. Invariant dijaga di
`TransactionRepository`: amount == sum(price×qty) bila item ada.
