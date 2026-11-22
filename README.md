# Tugas 3 IF4073 – Segmentasi Citra

Aplikasi MATLAB (`SegmentationApp`) untuk segmentasi citra dengan tiga pendekatan dalam satu GUI:

1. **Deteksi tepi** (Laplace, LoG, Sobel, Prewitt, Roberts, Canny) → segmentasi objek utama
2. **Split and merge** (quadtree split + merge region bertetangga)
3. **Semantic segmentation** (DeepLabV3 MobileNetV3 hasil fine-tuning CamVid, 11 kelas, inferensi di Python)

## Struktur

```
Tugas3-IF4073-CitraDigital-13523104/
├── SegmentationApp.m              # GUI dan titik masuk program
├── gui/
│   ├── AppState.m                 # kelas handle penyimpan state & komponen GUI
│   └── datasetIndex.m             # daftar citra di data/BSDS500 dan data/CamVid/test
├── data/
│   ├── BSDS500/                   # 8 citra BSDS500_Tugas3_Test_8
│   └── CamVid/                    # dataset CamVid (di-ignore git)
├── results/                       # keluaran script uji & tombol Simpan Hasil (di-ignore git)
├── src/
│   ├── applySegmentationMethod.m  # titik masuk ketiga metode + validasi parameter
│   ├── edge_detection/
│   │   ├── operators/             # operator buatan sendiri (+ Canny built-in)
│   │   ├── detectEdges.m          # pilih operator + ambang -> citra tepi biner
│   │   ├── segmentFromEdges.m     # citra tepi -> mask objek utama
│   │   └── edgeSegmentation.m     # pipeline lengkap Bagian B
│   ├── split_merge/               # quadtreeSplit, mergeRegions, isHomogeneous, splitAndMerge
│   ├── semantic_segmentation/     # semanticSegmentation.m, camvid_predict.py, model/*.pth
│   └── utils/                     # konvolusi, kernel Gaussian/LoG, Otsu, zero-crossing
└── tests/
    ├── test_apply_segmentation.m  # uji titik masuk GUI: keluaran + validasi input
    ├── test_edge_operators.m      # uji operator (sintetis + contoh slide)
    ├── test_edge_segmentation.m   # uji segmentasi tepi: lingkaran sintetis + 8 citra BSDS500
    ├── test_split_merge.m         # uji split and merge pada 8 citra BSDS500
    ├── test_semantic_segmentation.m  # uji MATLAB <-> Python pada citra CamVid test
    └── ...                        # skrip eksplorasi (demo_arah_gradien, compare_steps_log_canny, ...)
```

## Dependensi

- MATLAB R2025a atau lebih baru (memakai properti `Theme` pada figure; teruji pada R2026a).
- Image Processing Toolbox: morfologi (`bwareaopen`, `imclose`, `imfill`, `imopen`,
  `regionprops`), tampilan (`bwperim`, `imoverlay`, `label2rgb`, `labeloverlay`) dan
  `edge(...,'canny')`. Fungsi deteksi tepi built-in **tidak** dipakai kecuali Canny.
- Bagian D: Python 3 dengan paket di `src/semantic_segmentation/requirements.txt`
  (`torch`, `torchvision`, `pillow`, `numpy`) dan model
  `src/semantic_segmentation/model/camvid_deeplabv3_mbv3.pth`.

## Menjalankan GUI

```matlab
% dari root repo
SegmentationApp
```

1. **Pilih citra:** pilih sumber (BSDS500 atau CamVid test) dan citra, lalu tekan **Muat Citra**. Bisa juga **Dari File...** untuk citra lain.
2. **Pilih metode dan atur parameter:** panel parameter berganti sesuai metode. Field yang tidak dipakai operator terpilih tampil abu-abu.
3. **Proses:**
   - Tab **Hasil** menampilkan citra asli dan 3 citra hasil, ditambah log berisi parameter dan ringkasan.
   - Tab **Tahapan Tepi** menampilkan langkah segmentasi berbasis tepi.
4. **Simpan Hasil:** menyimpan 4 panel ke `results/gui/<citra>_<metode>.png`. Klik kanan pada gambar lalu pilih "Salin gambar" untuk menyalinnya ke clipboard.

| Metode | Panel hasil | Parameter |
|---|---|---|
| Deteksi tepi | citra tepi, overlay batas objek, objek tersegmentasi | lihat tabel Bagian B |
| Split and merge | after split, after merge, rekonstruksi rata-rata | `Predicate` (std/range), `SplitThreshold`, `MergeThreshold` (0..1), `MinBlockSize` |
| Semantik CNN | label kelas, overlay, legenda + % piksel per kelas | path Python, path model |

**Validasi input:**
- **Citra:**
  - indexed diubah ke RGB, kanal alpha dibuang, tipe disamakan ke uint8;
  - citra yang tidak terbaca, bukan grayscale/RGB, atau lebih kecil dari 8×8 ditolak.
- **Parameter:** rentangnya dicek di `applySegmentationMethod`, misalnya threshold harus di (0, 1], radius dan ukuran blok harus bilangan bulat ≥ 1, dan `MaxCloseRadius` ≥ `CloseRadius`.
- **Pesan error:** kesalahan apa pun ditampilkan sebagai dialog, bukan menghentikan GUI.

## Menjalankan test

```matlab
% dari root repo
run('tests/test_apply_segmentation.m')  % keluaran & validasi (isi pythonExe untuk bagian semantik)
run('tests/test_edge_operators.m')      % kebenaran operator
run('tests/test_edge_segmentation.m')   % segmentasi tepi -> results/edge_segmentation/
```

Pemakaian tanpa GUI:

```matlab
addpath(genpath('src'));
I = imread('data/BSDS500/2018.jpg');
out = applySegmentationMethod(I, 'edge', struct('Operator', 'log', 'LogSigma', 3));
out = applySegmentationMethod(I, 'splitmerge', struct('SplitThreshold', 0.05));
imshow(out.views(3).image)
```

## Bagian B – alur segmentasi berbasis tepi

1. **Deteksi tepi** (`detectEdges`)
   - Sobel/Prewitt/Roberts: penghalusan Gaussian (σ = `Sigma`) → magnitudo gradien →
     normalisasi [0,1] → ambang Otsu (atau `Threshold` manual).
   - Laplace: penghalusan Gaussian (σ = `Sigma`) → mask Laplace → zero-crossing.
   - LoG: konvolusi mask LoG (σ = `LogSigma`) → zero-crossing.
   - Zero-crossing hanya dihitung tepi bila selisih kedua sisi > `ZcScale × mean(|R|)`.
   - Canny: `edge(I,'canny')` dengan ambang otomatis atau `CannyThreshold`.
   - Konvolusi memakai *replicate padding* agar tidak muncul tepi palsu di batas citra.
2. **Segmentasi** (`segmentFromEdges`)
   1. Buang fragmen tepi pendek (`MinEdgeLength`)
   2. Closing dengan disk radius r → menyambung celah kontur
   3. `imfill holes` → isi region di dalam kontur tertutup
   4. Opening dengan disk r → buang garis tepi yang tidak mengapit region
   5. Pilih region utama: luas 1%–90% citra, skor = jumlah bobot Gaussian (σ = 0.42) tiap piksel region, sehingga piksel dekat pusat citra bernilai lebih besar
   6. Bila belum ada region, r diperbesar (+2) hingga `MaxCloseRadius`

### Parameter

| Parameter | Default | Keterangan |
|---|---|---|
| `Operator` | `sobel` | `laplace` / `log` / `sobel` / `prewitt` / `roberts` / `canny` |
| `Sigma` | 1.0 | σ Gaussian sebelum Sobel/Prewitt/Roberts/Laplace (0 = tanpa) |
| `Threshold` | Otsu | ambang magnitudo gradien (0,1], kosong = Otsu |
| `LogSigma` | 2.0 | σ LoG |
| `ZcScale` | 1.5 (Laplace), 0.75 (LoG) | ambang zero-crossing |
| `CannyThreshold` | otomatis | T_high Canny (0,1], T_low = 0.4 × T_high. Otomatis meloloskan ~30% piksel sebagai kandidat, jadi pada citra berderau lebih baik diisi manual (mis. 0.1) |
| `MinEdgeLength` | 30 | panjang minimal fragmen tepi (piksel) |
| `CloseRadius` / `MaxCloseRadius` | 3 / 15 | radius closing awal / maksimum |
