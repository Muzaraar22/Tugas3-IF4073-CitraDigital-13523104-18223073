% analisis pemilihan ambang Bagian B (Subbab 4.1.11 laporan):
% kenapa Laplace/LoG memakai persentil 70, sedangkan operator lain Otsu,
% dan berapa persentil terbaik pada citra beruang (100007.jpg)
%
% jalankan dari root repo:
%   run('tests/analyze_threshold_percentile.m')
%
% isi:
%   1. ground truth beruang dari split and merge (Bagian C)
%   2. histogram kekuatan tepi Sobel vs LoG + tepi biner LoG (Otsu vs P70)
%   3. Laplace/LoG pada 8 citra BSDS: Otsu vs persentil 70
%   4. sweep persentil 1..99 untuk 6 operator -> IoU terhadap ground truth
%   5. contoh hasil LoG dan Sobel pada beberapa persentil
%
% semua gambar + CSV disimpan di results/threshold_analysis/
% (penilaian Baik/Sebagian/Gagal di laporan dilakukan visual dari gambar ini)

clear; clc; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(rootDir, 'src')));
outDir = fullfile(rootDir, 'results', 'threshold_analysis');
if ~isfolder(outDir)
    mkdir(outDir);
end

I  = imread(fullfile(rootDir, 'data', 'BSDS500', '100007.jpg'));
Id = im2double(I);
[M, N, ~] = size(I);

%% 1. ground truth beruang dari split and merge
% BSDS500 di folder tugas tidak membawa ground truth, jadi acuan diambil dari
% hasil split and merge terbaik pada citra ini:
%   - SplitThreshold 0.03 dan MinBlockSize 2 (lebih halus dari bawaan 0.06 / 4)
%     supaya batas beruang tidak bergerigi blok besar
%   - MergeThreshold 0.08 (bawaan)
%   - region yang memuat titik SEED di badan beruang, lalu lubangnya diisi
GT_PARAMS = struct('Predicate', 'std', 'SplitThreshold', 0.03, ...
                   'MergeThreshold', 0.08, 'MinBlockSize', 2);
SEED = [175 172];   % (x, y) di badan beruang

[L, ~, smInfo] = splitAndMerge(I, GT_PARAMS);
gt = imfill(L == L(SEED(2), SEED(1)), 'holes');
fprintf('== 1. ground truth: region split and merge di (%d, %d), luas %.2f%% citra, %d region total\n', ...
    SEED, 100 * mean(gt(:)), smInfo.numMergeRegions);

% kestabilan: MergeThreshold sedikit diubah, region beruang harus hampir sama
for mt = [0.06 0.10]
    p = GT_PARAMS; p.MergeThreshold = mt;
    Lm = splitAndMerge(I, p);
    g2 = imfill(Lm == Lm(SEED(2), SEED(1)), 'holes');
    fprintf('   MergeThreshold %.2f -> luas %.2f%%, IoU terhadap ground truth %.3f\n', ...
        mt, 100 * mean(g2(:)), iouOf(g2, gt));
end

fig = figure('Visible', 'off', 'Position', [0 0 1300 450], 'Theme', 'light');
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); imshow(smInfo.mergeRGB, 'Parent', ax); hold(ax, 'on');
plot(ax, SEED(1), SEED(2), 'w+', 'MarkerSize', 14, 'LineWidth', 2);
title(ax, sprintf('(a) After merge (%d region), + = titik seed', smInfo.numMergeRegions));
ax = nexttile(tl); imshow(imoverlay(Id, imdilate(bwperim(gt), ones(2)), 'yellow'), 'Parent', ax);
title(ax, sprintf('(b) Ground truth beruang (%.2f%% citra)', 100 * mean(gt(:))));
saveFig(fig, fullfile(outDir, 'gt_100007.png'));

%% 2. histogram kekuatan tepi Sobel vs LoG pada 100007.jpg
[~, infoSob] = detectEdges(I, 'sobel', struct('ThresholdMode', 'otsu'));
[Elo, infoLo] = detectEdges(I, 'log', struct('ThresholdMode', 'otsu'));
[Elp, infoLp] = detectEdges(I, 'log', struct('ThresholdMode', 'percentile', 'Percentile', 70));
Ssob = infoSob.strength(:);
Slog = infoLo.strength(infoLo.strength > 0);
fprintf('\n== 2. histogram 100007.jpg\n');
fprintf('   Sobel: Otsu T = %.3f, piksel tepi %.1f%%\n', infoSob.T, 100 * mean(Ssob >= infoSob.T));
fprintf('   LoG  : kandidat zero-crossing %.1f%% piksel, median S = %.3f\n', ...
    100 * numel(Slog) / (M * N), median(Slog));
fprintf('          Otsu T = %.3f membuang %.1f%% kandidat -> %.1f%% piksel tepi\n', ...
    infoLo.T, 100 * mean(Slog < infoLo.T), 100 * mean(Elo(:)));
fprintf('          P70  T = %.3f membuang %.1f%% kandidat -> %.1f%% piksel tepi\n', ...
    infoLp.T, 100 * mean(Slog < infoLp.T), 100 * mean(Elp(:)));

fig = figure('Visible', 'off', 'Position', [0 0 1400 760], 'Theme', 'light');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl);
histogram(ax, Ssob, 100, 'Normalization', 'probability', 'FaceColor', [0.3 0.45 0.7], 'EdgeColor', 'none');
xline(ax, infoSob.T, 'r-', sprintf('Otsu T = %.2f', infoSob.T), 'LineWidth', 1.5);
title(ax, '(a) Sobel: magnitudo gradien semua piksel'); xlabel(ax, 'kekuatan tepi S'); ylabel(ax, 'proporsi');
ax = nexttile(tl);
histogram(ax, Slog, 100, 'Normalization', 'probability', 'FaceColor', [0.3 0.45 0.7], 'EdgeColor', 'none');
xline(ax, infoLo.T, 'r-', sprintf('Otsu T = %.2f', infoLo.T), 'LineWidth', 1.5);
xline(ax, infoLp.T, 'g-', sprintf('P70 T = %.2f', infoLp.T), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'top');
title(ax, '(b) LoG: kecuraman piksel zero-crossing'); xlabel(ax, 'kekuatan tepi S'); ylabel(ax, 'proporsi');
ax = nexttile(tl); imshow(Elo, 'Parent', ax);
title(ax, sprintf('(c) LoG + Otsu: %.1f%% piksel tepi', 100 * mean(Elo(:))));
ax = nexttile(tl); imshow(Elp, 'Parent', ax);
title(ax, sprintf('(d) LoG + persentil 70: %.1f%% piksel tepi', 100 * mean(Elp(:))));
saveFig(fig, fullfile(outDir, 'hist_100007.png'));

%% 3. Laplace/LoG pada 8 citra BSDS: Otsu vs persentil 70
files = dir(fullfile(rootDir, 'data', 'BSDS500', '*.jpg'));
fprintf('\n== 3. Otsu vs persentil 70 (Peq = persentil yang setara ambang Otsu)\n');
fprintf('   %-8s %-8s | %5s %7s %7s | %7s %7s\n', 'citra', 'operator', 'Peq', 'tepi%', 'luas%', 'tepi%', 'luas%');
for op = {'laplace', 'log'}
    fig = figure('Visible', 'off', 'Position', [0 0 900 2000], 'Theme', 'light');
    tl = tiledlayout(fig, numel(files), 2, 'TileSpacing', 'tight', 'Padding', 'tight');
    for i = 1:numel(files)
        [~, name] = fileparts(files(i).name);
        J = imread(fullfile(files(i).folder, files(i).name));
        [Eo, io] = detectEdges(J, op{1}, struct('ThresholdMode', 'otsu'));
        ro = edgeSegmentation(J, op{1}, struct('ThresholdMode', 'otsu'));
        rp = edgeSegmentation(J, op{1}, struct('ThresholdMode', 'percentile', 'Percentile', 70));
        cand = io.strength(io.strength > 0);
        fprintf('   %-8s %-8s | %5.1f %7.1f %7.1f | %7.1f %7.1f\n', name, op{1}, ...
            100 * mean(cand < io.T), 100 * mean(Eo(:)), 100 * mean(ro.mask(:)), ...
            100 * mean(rp.edges(:)), 100 * mean(rp.mask(:)));
        ax = nexttile(tl); imshow(ro.overlay, 'Parent', ax);
        title(ax, sprintf('%s %s Otsu', name, op{1}), 'FontSize', 8);
        ax = nexttile(tl); imshow(rp.overlay, 'Parent', ax);
        title(ax, sprintf('%s %s P70', name, op{1}), 'FontSize', 8);
    end
    saveFig(fig, fullfile(outDir, ['otsu_vs_p70_' op{1} '.png']));
end

%% 4. sweep persentil 1..99 pada 100007.jpg (parameter lain bawaan)
ops = {'sobel', 'prewitt', 'roberts', 'canny', 'laplace', 'log'};
names = {'Sobel', 'Prewitt', 'Roberts', 'Canny', 'Laplace', 'LoG'};
Ps = 1:99;
iou = zeros(numel(ops), numel(Ps));
edgePct = zeros(numel(ops), numel(Ps));
iouOtsu = zeros(1, numel(ops));
peqOtsu = zeros(1, numel(ops));
for k = 1:numel(ops)
    for j = 1:numel(Ps)
        r = edgeSegmentation(I, ops{k}, struct('ThresholdMode', 'percentile', 'Percentile', Ps(j)));
        iou(k, j) = iouOf(r.mask, gt);
        edgePct(k, j) = 100 * mean(r.edges(:));
    end
    % posisi ambang Otsu dinyatakan sebagai persentil dari data yang sama
    [~, io] = detectEdges(I, ops{k}, struct('ThresholdMode', 'otsu'));
    if any(strcmp(ops{k}, {'laplace', 'log'}))
        vals = io.strength(io.strength > 0);
    else
        vals = io.strength(:);
    end
    peqOtsu(k) = 100 * mean(vals < io.T);
    ro = edgeSegmentation(I, ops{k}, struct('ThresholdMode', 'otsu'));
    iouOtsu(k) = iouOf(ro.mask, gt);
end

fprintf('\n== 4. sweep persentil pada 100007.jpg (IoU terhadap ground truth)\n');
fprintf('   %-8s %7s %8s %8s %8s %8s %8s  %s\n', 'operator', 'P best', 'IoU best', 'IoU P70', ...
    'IoU P96', 'Otsu~P', 'IoU Otsu', 'P dengan IoU >= 0.7');
for k = 1:numel(ops)
    [b, bj] = max(iou(k, :));
    fprintf('   %-8s %7d %8.3f %8.3f %8.3f %8.1f %8.3f  %s\n', names{k}, Ps(bj), b, ...
        iou(k, Ps == 70), iou(k, Ps == 96), peqOtsu(k), iouOtsu(k), rangesText(Ps(iou(k, :) >= 0.7)));
end
writetable(array2table([Ps' iou'], 'VariableNames', [{'P'}, strcat('IoU_', names)]), ...
    fullfile(outDir, 'sweep_100007.csv'));

cols = lines(numel(ops));
fig = figure('Visible', 'off', 'Position', [0 0 1300 820], 'Theme', 'light');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
groups = {1:4, 5:6};
titles = {'(a) Operator turunan pertama', '(b) Operator turunan kedua'};
for g = 1:2
    ax = nexttile(tl); hold(ax, 'on');
    for k = groups{g}
        plot(ax, Ps, iou(k, :), '-', 'Color', cols(k, :), 'LineWidth', 1.6, 'DisplayName', names{k});
        plot(ax, peqOtsu(k), iouOtsu(k), 'o', 'Color', cols(k, :), 'MarkerFaceColor', cols(k, :), ...
            'MarkerSize', 7, 'HandleVisibility', 'off');
    end
    xline(ax, 70, 'k--', 'P = 70', 'HandleVisibility', 'off');
    xlim(ax, [1 99]); ylim(ax, [0 1]); grid(ax, 'on'); box(ax, 'on');
    xlabel(ax, 'persentil P'); ylabel(ax, 'IoU terhadap ground truth');
    legend(ax, 'Location', 'northwest');
    title(ax, [titles{g} ' (titik bulat = posisi ambang Otsu)']);
end
saveFig(fig, fullfile(outDir, 'sweep_100007.png'));

%% 5. contoh hasil pada beberapa persentil: LoG (2 baris atas) dan Sobel (2 baris bawah)
rows = {'log',   unique([30 50 bestP(iou, ops, 'log') 70 90]);
        'sobel', unique([70 90 96 bestP(iou, ops, 'sobel')])};
nCol = max(cellfun(@numel, rows(:, 2))) + 1;   % + kolom Otsu
fig = figure('Visible', 'off', 'Position', [0 0 250 * nCol 820], 'Theme', 'light');
tl = tiledlayout(fig, 4, nCol, 'TileSpacing', 'tight', 'Padding', 'compact');
for k = 1:size(rows, 1)
    showcase(tl, (k - 1) * 2 * nCol, nCol, I, gt, rows{k, 1}, rows{k, 2});
end
saveFig(fig, fullfile(outDir, 'percentiles_100007.png'));

fprintf('\nGambar dan CSV tersimpan di %s\n', outDir);


%% ---- fungsi lokal

function v = iouOf(a, b)
u = nnz(a | b);
if u == 0
    v = 1;
else
    v = nnz(a & b) / u;
end
end

function P = bestP(iou, ops, op)
[~, j] = max(iou(strcmp(ops, op), :));
P = j;   % Ps = 1:99, jadi indeks = nilai P
end

% '21-46, 72-87' dari daftar bilangan bulat
function t = rangesText(v)
if isempty(v)
    t = 'tidak ada';
    return;
end
br = [true diff(v) > 1];
s = v(br);
e = v([br(2:end) true]);
t = strjoin(arrayfun(@(a, b) sprintf('%d-%d', a, b), s, e, 'UniformOutput', false), ', ');
end

% 2 baris mulai tile ke-(offset + 1): atas tepi biner, bawah overlay hasil + IoU,
% kolom terakhir Otsu
function showcase(tl, offset, nCol, I, gt, op, Ps)
names = struct('log', 'LoG', 'sobel', 'Sobel');
cfgs = [num2cell(Ps), {'otsu'}];
for c = 1:numel(cfgs)
    if ischar(cfgs{c})
        r = edgeSegmentation(I, op, struct('ThresholdMode', 'otsu'));
        lbl = 'Otsu';
    else
        r = edgeSegmentation(I, op, struct('ThresholdMode', 'percentile', 'Percentile', cfgs{c}));
        lbl = sprintf('P = %d', cfgs{c});
    end
    ax = nexttile(tl, offset + c); imshow(r.edges, 'Parent', ax);
    title(ax, sprintf('%s %s: %.1f%% tepi', names.(op), lbl, 100 * mean(r.edges(:))), 'FontSize', 9);
    ax = nexttile(tl, offset + nCol + c); imshow(r.overlay, 'Parent', ax);
    title(ax, sprintf('IoU = %.2f (r = %d)', iouOf(r.mask, gt), r.steps.radius), 'FontSize', 9);
end
end

function saveFig(fig, path)
exportgraphics(fig, path, 'Resolution', 100);
close(fig);
end
