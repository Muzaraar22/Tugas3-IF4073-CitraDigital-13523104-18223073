# Tugas 3 IF4073 – Segmentasi Citra

Aplikasi MATLAB untuk segmentasi citra dengan tiga pendekatan:

1. **Deteksi tepi** (Laplace, LoG, Sobel, Prewitt, Roberts, Canny) → segmentasi objek ✅
2. **Split and merge** ⏳
3. **Semantic segmentation (CNN, CamVid)** ⏳

## Struktur

```
Tugas3-IF4073-CitraDigital-13523104/
├── data/BSDS500/                  # 8 citra BSDS500_Tugas3_Test_8
├── results/                       # keluaran script uji (di-ignore git)
├── src/
│   ├── edge_detection/
│   │   ├── operators/             # operator buatan sendiri (+ Canny built-in)
│   │   │   ├── gradientOperator.m     # inti bersama Sobel/Prewitt/Roberts
│   │   │   ├── sobelOperator.m  prewittOperator.m  robertsOperator.m
│   │   │   ├── laplaceOperator.m  logOperator.m
│   │   │   └── cannyOperator.m
│   │   ├── detectEdges.m          # pilih operator + ambang -> citra tepi biner
│   │   ├── segmentFromEdges.m     # citra tepi -> mask objek utama
│   │   └── edgeSegmentation.m     # pipeline lengkap Bagian B
│   ├── split_merge/               # (Bagian C)
│   ├── semantic_segmentation/     # (Bagian D)
│   └── utils/                     # konvolusi, kernel Gaussian/LoG, Otsu, zero-crossing
└── tests/
    ├── test_edge_operators.m      # uji operator (sintetis + contoh slide)
    ├── test_edge_segmentation.m   # uji segmentasi: lingkaran sintetis + 8 citra BSDS500
    └── demo_arah_gradien.m        # demo arah gradien 4x4
```

## Dependensi

- MATLAB R2025a atau lebih baru (memakai `tiledlayout`, `exportgraphics`, figure `Theme`)
- Image Processing Toolbox: dipakai untuk morfologi (`bwareaopen`, `imclose`, `imfill`,
  `imopen`, `regionprops`), tampilan (`bwperim`, `imoverlay`) dan `edge(...,'canny')`.
  Fungsi deteksi tepi built-in **tidak** dipakai kecuali Canny.

## Menjalankan

```matlab
% dari root repo
run('tests/test_edge_operators.m')     % cek kebenaran operator
run('tests/test_edge_segmentation.m')  % uji segmentasi -> results/edge_segmentation/
```

Pemakaian langsung:

```matlab
addpath(genpath('src'));
I = imread('data/BSDS500/2018.jpg');
res = edgeSegmentation(I, 'sobel');
res = edgeSegmentation(I, 'log', struct('LogSigma', 3, 'CloseRadius', 5));
imshow(res.overlay)
```

## Bagian B – alur segmentasi berbasis tepi

1. **Deteksi tepi** (`detectEdges`)
   - Sobel/Prewitt/Roberts: penghalusan Gaussian (σ = `Sigma`) → magnitudo gradien →
     normalisasi [0,1] → ambang Otsu (atau `Threshold` manual).
   - Laplace: penghalusan Gaussian (σ = `Sigma`) → mask Laplace → zero-crossing.
   - LoG: konvolusi mask LoG (σ = `LogSigma`) → zero-crossing.
   - Zero-crossing hanya dihitung tepi bila selisih kedua sisi > `ZcScale × mean(|R|)`.
   - Canny: `edge(I,'canny')`.
   - Konvolusi memakai *replicate padding* agar tidak muncul tepi palsu di batas citra.
2. **Segmentasi** (`segmentFromEdges`)
   1. Buang fragmen tepi pendek (`MinEdgeLength`)
   2. Closing dengan disk radius r → menyambung celah kontur
   3. `imfill holes` → isi region di dalam kontur tertutup
   4. Opening dengan disk r → buang garis tepi yang tidak mengapit region
   5. Pilih region utama: luas 1%–90% citra, skor = luas × (1 − 0.5 × jarak ke pusat)
   6. Bila belum ada region, r diperbesar (+2) hingga `MaxCloseRadius`

### Parameter

| Parameter | Default | Keterangan |
|---|---|---|
| `Sigma` | 1.0 | σ Gaussian sebelum Sobel/Prewitt/Roberts/Laplace (0 = tanpa) |
| `Threshold` | Otsu | ambang magnitudo gradien [0,1], kosong = Otsu |
| `LogSigma` | 2.0 | σ LoG |
| `ZcScale` | 1.5 (Laplace), 0.75 (LoG) | ambang zero-crossing |
| `MinEdgeLength` | 30 | panjang minimal fragmen tepi (piksel) |
| `CloseRadius` / `MaxCloseRadius` | 3 / 15 | radius closing awal / maksimum |
