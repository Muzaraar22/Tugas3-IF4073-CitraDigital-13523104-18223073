% Bagian B - uji segmentasi berbasis deteksi tepi
% jalankan dari root repo:
%   run('tests/test_edge_segmentation.m')
%
%   1. lingkaran sintetis + derau, IoU vs ground truth untuk 6 operator
%      -> figure "Uji sintetis" (ditampilkan)
%   2. 8 citra BSDS500 di data/BSDS500/ (ekstrak BSDS500_Tugas3_Test_8.zip)
%      -> results/edge_segmentation/<nama>.png       : asli | tepi | overlay | objek
%      -> results/edge_segmentation/<nama>_steps.png : tahapan segmentasi (Sobel)

clear; clc; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(rootDir, 'src')));

methods = {'laplace', 'log', 'sobel', 'prewitt', 'roberts', 'canny'};
params  = struct();   % kosong = semua default, mis. params.Sigma = 1.5;
stats   = [0 0];      % [jumlah PASS, jumlah FAIL]

%% 1. lingkaran sintetis + derau Gaussian
rng(0);   % supaya deraunya sama tiap dijalankan
[X, Y] = meshgrid(1:320, 1:240);
gt  = (X - 170).^2 + (Y - 115).^2 <= 70^2;          % ground truth objek
img = 0.25 + 0.5 * gt + 0.04 * randn(size(gt));    % objek terang + derau
img = min(max(img, 0), 1);

results = cell(1, numel(methods));
for k = 1:numel(methods)
    results{k} = edgeSegmentation(img, methods{k}, params);
    iou = nnz(results{k}.mask & gt) / nnz(results{k}.mask | gt);
    stats = report(iou > 0.90, sprintf('lingkaran %-8s IoU = %.3f', methods{k}, iou), stats);
end
figure('Name', 'Uji sintetis', 'Position', [50 50 1500 520]);
showGrid(img, results, methods, 'Lingkaran sintetis + derau');

fprintf('\n==== sintetis: %d PASS, %d FAIL ====\n\n', stats(1), stats(2));

%% 2. 8 citra BSDS500
dataDir = fullfile(rootDir, 'data', 'BSDS500');
outDir  = fullfile(rootDir, 'results', 'edge_segmentation');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

files = dir(fullfile(dataDir, '*.jpg'));
if isempty(files)
    error('tidak ada citra di %s, ekstrak BSDS500_Tugas3_Test_8.zip ke situ dulu', dataDir);
end

for i = 1:numel(files)
    [~, name] = fileparts(files(i).name);
    I = imread(fullfile(dataDir, files(i).name));

    for k = 1:numel(methods)
        results{k} = edgeSegmentation(I, methods{k}, params);
        r = results{k};
        fprintf('%-8s %-8s tepi %5.1f%% | objek %5.1f%% | r = %2d\n', name, methods{k}, ...
            100 * mean(r.edges(:)), 100 * mean(r.mask(:)), r.steps.radius);
        if ~any(r.mask(:))
            fprintf('[WARN] %s %s: tidak ada objek yang tersegmentasi\n', name, methods{k});
        end
    end

    % semua operator dalam 1 figure
    fig = figure('Visible', 'off', 'Position', [20 20 1600 560], 'Theme', 'light');
    showGrid(I, results, methods, files(i).name);
    saveFigure(fig, fullfile(outDir, [name '.png']));

    % tahapan segmentasi Sobel, bahan laporan
    fig = figure('Visible', 'off', 'Position', [20 20 1500 420], 'Theme', 'light');
    showSteps(I, results{strcmp(methods, 'sobel')}, files(i).name);
    saveFigure(fig, fullfile(outDir, [name '_steps.png']));

    fprintf('\n');
end
fprintf('selesai, hasil disimpan di %s\n', outDir);


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

% grid 3 baris: kolom 1 = citra asli, kolom berikutnya 1 per operator
% (baris 1 tepi, baris 2 overlay, baris 3 objek)
function showGrid(I, results, methods, ttl)
nCol = numel(methods) + 1;
tl = tiledlayout(3, nCol, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, ttl, 'Interpreter', 'none', 'FontWeight', 'bold');
nexttile(1); imshow(I); title('Citra asli');
for k = 1:numel(methods)
    r = results{k};
    nexttile(k + 1);            imshow(r.edges);     title([upper(methods{k}) ' - tepi']);
    nexttile(k + 1 + nCol);     imshow(r.overlay);   title('overlay');
    nexttile(k + 1 + 2 * nCol); imshow(r.segmented); title('objek');
end
end

% tahapan: asli -> tepi -> buang fragmen -> closing -> fill -> opening -> objek
function showSteps(I, r, fileName)
tl = tiledlayout(2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, [fileName ' - tahapan segmentasi (SOBEL)'], 'Interpreter', 'none', 'FontWeight', 'bold');
s = r.steps;
nexttile; imshow(I);           title('1. Citra asli');
nexttile; imshow(r.edges);     title('2. Tepi biner');
nexttile; imshow(s.cleaned);   title('3. Fragmen pendek dibuang');
nexttile; imshow(s.closed);    title(sprintf('4. Closing (r = %d)', s.radius));
nexttile; imshow(s.filled);    title('5. Fill holes');
nexttile; imshow(s.opened);    title('6. Opening');
nexttile; imshow(r.overlay);   title('7. Region utama');
nexttile; imshow(r.segmented); title('8. Objek tersegmentasi');
end

% simpan figure ke PNG lalu tutup
function saveFigure(fig, path)
exportgraphics(fig, path, 'Resolution', 110);
close(fig);
end
