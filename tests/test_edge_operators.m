% uji kebenaran operator deteksi tepi pada citra kecil / sintetis.
%
%   1. sifat mask: respon Laplace pada citra konstan = 0, LoG jumlahnya 0,
%      Gaussian jumlahnya 1
%   2. contoh angka dari slide (Laplace tepi curam & landai, Roberts)
%      -> figure: matriks input | respon | zero-crossing
%   3. magnitudo & arah Sobel/Prewitt dibandingkan dengan imgradient
%      (HANYA validasi, imgradient tidak dipakai di program)
%      -> figure "Validasi Sobel": cameraman asli | Sobel sendiri | imgradient | selisih
%   3b. arah gradien Sobel/Prewitt/Roberts pada bidang miring (seharusnya 63.43 derajat)

clear; clc; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(rootDir, 'src')));

stats = [0 0];   % [jumlah PASS, jumlah FAIL]

%% 1. sifat mask
for v = {'4', '8', 'weighted'}
    R = laplaceOperator(ones(10) * 0.7, v{1});
    stats = report(max(abs(R(:))) < 1e-12, ...
        sprintf('Laplace varian %s: respon citra konstan = 0', v{1}), stats);
end

H = logKernel(1.4);
stats = report(abs(sum(H(:))) < 1e-12 && isequal(size(H), [11 11]), ...
    'LoG sigma 1.4: jumlah koefisien = 0, ukuran 11x11', stats);

Hg = gaussianKernel(1);
stats = report(abs(sum(Hg(:)) - 1) < 1e-12, 'Gaussian: jumlah koefisien = 1', stats);

%% 2. contoh angka dari slide
figure('Name', 'Contoh slide', 'Position', [50 50 1200 650]);
tiledlayout(3, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% tepi curam 4 -> 8. mask [0 1 0; 1 -4 1; 0 1 0] menghasilkan 0 4 -4 0 0.
% slide menulis 0 -4 4 0 0 (konvensi tanda kebalikannya), lokasi
% zero-crossing-nya tetap sama: di antara kolom 3 dan 4
f  = repmat([4 4 4 8 8 8 8], 5, 1);
R  = laplaceOperator(f, '4');
BW = zeroCrossing(R, 0);
stats = report(isequal(R(3, 2:6), [0 4 -4 0 0]), 'Laplace tepi curam: 0 4 -4 0 0', stats);
stats = report(all(BW(2:4, 3)) && ~any(any(BW(2:4, [1 2 4 5 6 7]))), ...
    'zero-crossing tepi curam di kolom 3 (|R| sama, ambil sisi kiri)', stats);
nexttile; showMatrix(f,  'Tepi curam - citra asli');
nexttile; showMatrix(R,  'Respon Laplace');
nexttile; showMatrix(BW, 'Zero-crossing');

% tepi landai 2 2 2 5 8 8 8 -> 0 3 0 -3 0, zero-crossing di piksel bernilai 0
f  = repmat([2 2 2 5 8 8 8 8], 5, 1);
R  = laplaceOperator(f, '4');
BW = zeroCrossing(R, 0.5);
% seluruh kolom 4 harus 1, termasuk baris pinggir (baris 1 dan 5)
stats = report(isequal(R(3, 2:6), [0 3 0 -3 0]) && all(BW(:, 4)) && nnz(BW) == 5, ...
    'Laplace tepi landai: 0 3 0 -3 0, zero-crossing di seluruh kolom 4', stats);
% tepi landai horizontal (citra diputar): seluruh baris 4 harus 1,
% termasuk kolom pinggir -> menguji pasangan atas-bawah
stats = report(isequal(zeroCrossing(laplaceOperator(f', '4'), 0.5), BW'), ...
    'tepi landai horizontal: zero-crossing di seluruh baris 4', stats);
nexttile; showMatrix(f,  'Tepi landai - citra asli');
nexttile; showMatrix(R,  'Respon Laplace');
nexttile; showMatrix(BW, 'Zero-crossing (t = 0.5)');

% Roberts (slide): f'[0,0] = |3 - 1| + |4 - 2| = 4
f   = [1 2; 4 3];
mag = robertsOperator(f, 'abs');
stats = report(mag(2, 2) == 4, 'Roberts |3-1| + |4-2| = 4', stats);
nexttile; showMatrix(f,   'Roberts - citra asli');
nexttile; showMatrix(mag, 'Magnitudo |R+| + |R-|');
nexttile; axis off;

%% 3. validasi magnitudo & arah Sobel / Prewitt terhadap imgradient (opsional)
if exist('imgradient', 'file') && exist('cameraman.tif', 'file')
    I = imread('cameraman.tif');
    G = im2double(I);

    % abaikan 2 piksel pinggir (cara padding bisa beda), lalu normalisasi
    inner = @(A) A(3:end-2, 3:end-2) / max(max(A(3:end-2, 3:end-2)));

    mSobel = inner(sobelOperator(G));
    mRef   = inner(imgradient(G, 'sobel'));
    stats = report(max(abs(mSobel(:) - mRef(:))) < 1e-10, ...
        'magnitudo Sobel sendiri == imgradient sobel', stats);

    mPrew = inner(prewittOperator(G));
    mRefP = inner(imgradient(G, 'prewitt'));
    stats = report(max(abs(mPrew(:) - mRefP(:))) < 1e-10, ...
        'magnitudo Prewitt sendiri == imgradient prewitt', stats);

    % arah: imgradient pakai sumbu y ke atas (berlawanan jarum jam),
    % theta di kode pakai sumbu y ke bawah -> theta = -Gdir.
    % dibandingkan hanya di piksel yang gradiennya cukup kuat
    % (di daerah datar arah gradien tidak terdefinisi)
    angDiff = @(a, b) abs(mod(a - b + 180, 360) - 180);   % selisih sudut, tahan wrap 180/-180
    [magS, ~, ~, thS] = sobelOperator(G);
    [~, GdirS]        = imgradient(G, 'sobel');
    valid = magS > 0.05 * max(magS(:));
    valid([1:2 end-1:end], :) = false;   valid(:, [1:2 end-1:end]) = false;
    d = angDiff(rad2deg(thS(valid)), -GdirS(valid));
    stats = report(max(d) < 1e-6, 'arah Sobel sendiri == -Gdir imgradient sobel', stats);

    [magP, ~, ~, thP] = prewittOperator(G);
    [~, GdirP]        = imgradient(G, 'prewitt');
    valid = magP > 0.05 * max(magP(:));
    valid([1:2 end-1:end], :) = false;   valid(:, [1:2 end-1:end]) = false;
    d = angDiff(rad2deg(thP(valid)), -GdirP(valid));
    stats = report(max(d) < 1e-6, 'arah Prewitt sendiri == -Gdir imgradient prewitt', stats);

    figure('Name', 'Validasi Sobel', 'Position', [80 80 1200 330]);
    tiledlayout(1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    nexttile; imshow(I);                         title('cameraman.tif (asli)');
    nexttile; imshow(mSobel);                    title('Sobel sendiri');
    nexttile; imshow(mRef);                      title('imgradient sobel');
    nexttile; imshow(abs(mSobel - mRef), []);    title('|selisih|');
else
    fprintf('[SKIP] imgradient / cameraman.tif tidak tersedia\n');
end

%% 3b. arah gradien pada bidang miring f = 10x + 20y (jawaban pasti 63.43 derajat)
% Roberts harus sama dengan Sobel/Prewitt setelah ditambah pi/4
[xx, yy] = meshgrid(1:8, 1:8);
plane = 10 * xx + 20 * yy;
inner = 3:6;   % hindari pinggir (efek replicate padding)
[~, ~, ~, thS] = sobelOperator(plane);
[~, ~, ~, thP] = prewittOperator(plane);
[~, ~, ~, thR] = robertsOperator(plane);
target = atan2d(20, 10);
stats = report(all(abs(rad2deg(thS(inner, inner)) - target) < 1e-9, 'all'), ...
    sprintf('arah Sobel bidang miring = %.2f derajat', target), stats);
stats = report(all(abs(rad2deg(thP(inner, inner)) - target) < 1e-9, 'all'), ...
    sprintf('arah Prewitt bidang miring = %.2f derajat', target), stats);
stats = report(all(abs(rad2deg(thR(inner, inner)) - target) < 1e-9, 'all'), ...
    sprintf('arah Roberts (pi/4 + atan) bidang miring = %.2f derajat', target), stats);

fprintf('\n==== %d PASS, %d FAIL ====\n', stats(1), stats(2));


%% ---- fungsi lokal

% cetak PASS/FAIL lalu update hitungan
function stats = report(ok, msg, stats)
if ok
    fprintf('[PASS] %s\n', msg);
    stats(1) = stats(1) + 1;
else
    fprintf('[FAIL] %s\n', msg);
    stats(2) = stats(2) + 1;
end
end

% tampilkan matriks kecil sebagai gambar + angka tiap selnya
function showMatrix(A, ttl)
A = double(A);
imagesc(A);
colormap(gca, gray);
axis image off;
title(ttl);
span = max(A(:)) - min(A(:));
for i = 1:size(A, 1)
    for j = 1:size(A, 2)
        % warna teks kebalikan dari warna sel supaya terbaca
        isBright = span > 0 && (A(i, j) - min(A(:))) / span > 0.5;
        text(j, i, num2str(A(i, j)), 'HorizontalAlignment', 'center', ...
            'Color', [1 1 1] * ~isBright, 'FontSize', 9);
    end
end
end