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

## Dataset

- **BSDS500:** 8 citra uji sudah tersedia di `data/BSDS500/`.
- **CamVid:** tidak disimpan di repositori karena ukurannya besar (sekitar 600 MB).
  - Sumber yang dipakai: [CamVid di Kaggle](https://www.kaggle.com/datasets/carlolepelaars/camvid) (`carlolepelaars/camvid`), dengan pembagian train 369, validation 100, dan test 232 citra.
  - Sumber resmi: [Cambridge-driving Labeled Video Database](https://mi.eng.cam.ac.uk/research/projects/VideoRec/CamVid/).

Dataset CamVid hanya diperlukan untuk melatih ulang model atau memakai sumber "CamVid test" di GUI. Model hasil pelatihan sudah tersedia di repositori. Ekstrak dataset Kaggle ke `data/CamVid/` dengan susunan berikut:

```
data/CamVid/
├── class_dict.csv
├── train/    train_labels/
├── val/      val_labels/
└── test/     test_labels/
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
   - Tab **Hasil** menampilkan citra asli dan 3 citra hasil, ditambah log berisi parameter, ambang yang dipakai, dan ringkasan.
   - Tab **Tahapan Tepi** menampilkan 8 langkah segmentasi berbasis tepi, dari respons operator sampai objek tersegmentasi.
4. **Simpan Hasil:** menyimpan 4 panel ke `results/gui/<citra>_<metode>.png`. Klik kanan pada gambar lalu pilih "Salin gambar" untuk menyalinnya ke clipboard.

| Metode | Panel hasil | Parameter |
|---|---|---|
| Deteksi tepi | respons operator (sebelum ambang), overlay batas objek, objek tersegmentasi | lihat tabel Bagian B |
| Split and merge | after split, after merge, rekonstruksi rata-rata | `Predicate` (std/range), `SplitThreshold`, `MergeThreshold` (0..1), `MinBlockSize` |
| Semantik CNN | label kelas, overlay, legenda + % piksel per kelas | path Python, path model |

**Validasi input:**
- **Citra:**
  - indexed diubah ke RGB, kanal alpha dibuang, tipe disamakan ke uint8;
  - citra yang tidak terbaca, bukan grayscale/RGB, atau lebih kecil dari 8×8 ditolak.
- **Parameter:** rentangnya dicek di `applySegmentationMethod`, misalnya threshold harus di (0, 1], persentil di (0, 100), radius dan ukuran blok harus bilangan bulat ≥ 1, dan `MaxCloseRadius` ≥ `CloseRadius`.
- **Pesan error:** kesalahan apa pun ditampilkan sebagai dialog, bukan menghentikan GUI.

## Menjalankan test

```matlab
% dari root repo
run('tests/test_apply_segmentation.m')  % keluaran & validasi (isi pythonExe untuk bagian semantik)
run('tests/test_edge_operators.m')      % kebenaran operator
run('tests/test_edge_segmentation.m')   % segmentasi tepi -> results/edge_segmentation/
run('tests/analyze_threshold_percentile.m')  % analisis Otsu vs persentil -> results/threshold_analysis/
```

`analyze_threshold_percentile` membuat gambar dan tabel Subbab 4.1.11 laporan. Ground truth beruang
(100007.jpg) diambil dari region split and merge (SplitThreshold 0.03, MergeThreshold 0.08,
MinBlockSize 2) yang memuat titik (175, 172), karena BSDS500 di folder tugas tidak membawa ground truth.

Pemakaian tanpa GUI:

```matlab
addpath(genpath('src'));
I = imread('data/BSDS500/2018.jpg');
out = applySegmentationMethod(I, 'edge', struct('Operator', 'log', 'LogSigma', 3));
out = applySegmentationMethod(I, 'splitmerge', struct('SplitThreshold', 0.05));
imshow(out.views(3).image)
```

## Bagian B – alur segmentasi berbasis tepi

1. **Deteksi tepi** (`detectEdges`): konvolusi operator → kekuatan tepi S ∈ [0, 1] → ambang T → tepi biner.

   | Operator | Respons (panel 2 GUI) | Kekuatan tepi S |
   |---|---|---|
   | Sobel/Prewitt/Roberts | magnitudo gradien citra asli (Gaussian σ = `Sigma` opsional) | magnitudo / maksimum |
   | Laplace | hasil konvolusi mask Laplace pada citra asli (Gaussian opsional), bagian positif | kecuraman zero-crossing / maksimum |
   | LoG | hasil konvolusi mask LoG (σ = `LogSigma`), bagian positif | kecuraman zero-crossing / maksimum |
   | Canny | magnitudo gradien setelah Gaussian σ = √2 (sebelum NMS) | magnitudo / maksimum |

   - Ambang T dipilih dengan `ThresholdMode`:
     - **Otsu:** T memisahkan histogram S menjadi 2 kelas secara optimal.
     - **Persentil:** T = persentil ke-`Percentile` dari S, jadi P% kandidat terlemah dibuang.
     - **Manual:** T = `Threshold`.
   - Laplace/LoG: Otsu dan persentil dihitung hanya dari piksel zero-crossing. Kecuramannya adalah selisih nilai di kedua sisi crossing.
   - Canny: T menjadi T_high dan T_low = 0.4 × T_high, lalu `edge(I,'canny')` melakukan NMS + *hysteresis*.
   - Respons Laplace/LoG ditampilkan seperti di slide (`uint8(convn(I, H))`): nilai negatif dipotong, jadi latar hitam dan sisi positif tepi putih.
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
| `Sigma` | 0 | σ Gaussian opsional sebelum Sobel/Prewitt/Roberts/Laplace (0 = operator langsung pada citra asli) |
| `LogSigma` | 2.0 | σ LoG |
| `ThresholdMode` | `percentile` (Laplace/LoG), `otsu` (lainnya) | `otsu` / `percentile` / `manual` |
| `Percentile` | 70 (Laplace/LoG), 90 (lainnya) | mode persentil, (0, 100) |
| `Threshold` | 0.2 | mode manual, T di (0, 1] relatif terhadap S maksimum |
| `MinEdgeLength` | 30 | panjang minimal fragmen tepi (piksel) |
| `CloseRadius` / `MaxCloseRadius` | 3 / 15 | radius closing awal / maksimum |

Default ambang Laplace/LoG adalah persentil 70 karena pada 8 citra BSDS, Otsu pada kecuraman
zero-crossing terlalu tinggi sehingga kontur objek jarang tertutup.
