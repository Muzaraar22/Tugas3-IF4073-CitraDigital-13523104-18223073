% Bagian D - uji integrasi MATLAB <-> Python untuk segmentasi semantik CamVid
%
% persiapan:
%   1. model hasil training Kaggle -> src/semantic_segmentation/model/camvid_deeplabv3_mbv3.pth
%   2. dari dataset Kaggle (carlolepelaars/camvid), salin folder test/, test_labels/,
%      dan file class_dict.csv ke data/CamVid/
%   3. python lokal sudah terpasang paket di src/semantic_segmentation/requirements.txt,
%      isi pythonExe di bawah dengan path python tersebut
% jalankan dari root repo:
%   run('tests/test_semantic_segmentation.m')
%
% yang dicek:
%   - python terpanggil, label terbaca, ukurannya sama dengan citra, nilainya 1..11
%   - pixel accuracy & IoU pada beberapa citra test. angkanya harus mirip hasil
%     evaluasi di notebook; kalau jauh lebih jelek berarti ada yang salah di
%     jembatan MATLAB <-> Python (mis. urutan kelas / preprocessing beda)
%   - figure per citra: asli | ground truth | prediksi | overlay | legenda

clear; clc; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(rootDir, 'src')));

% ---- konfigurasi
pythonExe = 'python';   % contoh Windows: 'C:\Users\nama\venv\Scripts\python.exe'
nImages   = 6;          % banyak citra test yang dicoba
showFigures = true;

dataDir = fullfile(rootDir, 'data', 'CamVid');
outDir  = fullfile(rootDir, 'results', 'semantic_segmentation');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
params = struct('PythonExe', pythonExe);

% ---- 11 kelas tugas -> kelas asli CamVid (sama dengan CLASS_GROUPS di notebook)
% hanya dipakai di test ini untuk membuat ground truth 11 kelas
groups = {
    'Sky',        {'Sky'}
    'Building',   {'Building', 'Wall', 'Tunnel', 'Archway', 'Bridge'}
    'Pole',       {'Column_Pole', 'TrafficCone'}
    'Road',       {'Road', 'LaneMkgsDriv', 'LaneMkgsNonDriv'}
    'Pavement',   {'Sidewalk', 'ParkingBlock', 'RoadShoulder'}
    'Tree',       {'Tree', 'VegetationMisc'}
    'SignSymbol', {'SignSymbol', 'Misc_Text', 'TrafficLight'}
    'Fence',      {'Fence'}
    'Car',        {'Car', 'SUVPickupTruck', 'Truck_Bus', 'Train', 'OtherMoving'}
    'Pedestrian', {'Pedestrian', 'Child', 'CartLuggagePram', 'Animal'}
    'Bicyclist',  {'Bicyclist', 'MotorcycleScooter'}
};
nClass = size(groups, 1);

% class_dict.csv: nama kelas asli + warna RGB di citra label
classDict = readtable(fullfile(dataDir, 'class_dict.csv'));
csvNames  = classDict{:, 1};
csvRGB    = classDict{:, 2:4};
codes     = csvRGB(:, 1) * 65536 + csvRGB(:, 2) * 256 + csvRGB(:, 3);
codeIdx   = zeros(numel(codes), 1);   % 0 = Void (diabaikan)
for k = 1:numel(codes)
    for g = 1:nClass
        if any(strcmp(csvNames{k}, groups{g, 2}))
            codeIdx(k) = g;
        end
    end
end

%% proses beberapa citra test
files = dir(fullfile(dataDir, 'test', '*.png'));
if isempty(files)
    error('tidak ada citra di %s, salin folder test/ dari dataset Kaggle dulu', ...
          fullfile(dataDir, 'test'));
end
pick = round(linspace(1, numel(files), min(nImages, numel(files))));   % tersebar merata

stats = [0 0];                       % [jumlah PASS, jumlah FAIL]
conf  = zeros(nClass, nClass);       % confusion matrix gabungan (baris = GT, kolom = prediksi)
if showFigures
    figVisible = 'on';
else
    figVisible = 'off';
end

for i = pick
    [~, name] = fileparts(files(i).name);
    I     = imread(fullfile(files(i).folder, files(i).name));
    gtRGB = imread(fullfile(dataDir, 'test_labels', [name '_L.png']));
    gt    = rgbToLabel(gtRGB, codes, codeIdx);

    res = semanticSegmentation(I, params);
    pred = res.labels;

    % cek format keluaran
    okSize  = isequal(size(pred), [size(I, 1) size(I, 2)]);
    okRange = min(pred(:)) >= 1 && max(pred(:)) <= nClass;
    stats = report(okSize && okRange, sprintf('%s: ukuran label = ukuran citra, nilai 1..%d', ...
                   name, nClass), stats);

    % akurasi citra ini (piksel Void tidak dihitung)
    valid = gt > 0;
    acc = mean(pred(valid) == gt(valid));
    fprintf('       pixel acc %.3f | %.1fs\n', acc, res.elapsed);
    conf = conf + accumarray([double(gt(valid)) double(pred(valid))], 1, [nClass nClass]);

    % figure: asli | ground truth | prediksi | overlay | legenda
    fig = figure('Name', files(i).name, 'Visible', figVisible, ...
                 'Position', [30 30 1700 330], 'Color', 'w');
    tl = tiledlayout(1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('%s  (pixel acc %.3f)', files(i).name, acc), ...
          'Interpreter', 'none', 'FontWeight', 'bold');
    nexttile; imshow(I);                                   title('Citra asli');
    nexttile; imshow(label2rgb(gt, res.colormap, 'k'));    title('Ground truth (hitam = Void)');
    nexttile; imshow(res.colorLabel);                      title('Prediksi');
    nexttile; imshow(res.overlay);                         title('Overlay');
    nexttile; showLegend(res.classNames, res.colormap);

    exportgraphics(fig, fullfile(outDir, [name '.png']), 'Resolution', 110);
    if ~showFigures
        close(fig);
    end
end

%% ringkasan seluruh citra yang dicoba
tp  = diag(conf);
iou = tp ./ (sum(conf, 1)' + sum(conf, 2) - tp);   % NaN kalau kelas tidak muncul sama sekali
totalAcc = sum(tp) / sum(conf(:));

fprintf('\n%-12s %s\n', 'kelas', 'IoU');
for g = 1:nClass
    fprintf('%-12s %.3f\n', groups{g, 1}, iou(g));
end
fprintf('\nmIoU      : %.3f (kelas yang muncul saja)\n', mean(iou, 'omitnan'));
fprintf('pixel acc : %.3f\n', totalAcc);

% batas longgar: kalau jembatan MATLAB <-> Python benar, akurasi biasanya jauh di atas ini
stats = report(totalAcc > 0.7, sprintf('pixel accuracy gabungan %.3f > 0.7', totalAcc), stats);
fprintf('\n==== %d PASS, %d FAIL ====\n', stats(1), stats(2));


%% ---- fungsi lokal

% label RGB CamVid -> label 11 kelas (1..11), Void / warna tak dikenal -> 0
function L = rgbToLabel(rgb, codes, codeIdx)
rgb  = double(rgb);
code = rgb(:, :, 1) * 65536 + rgb(:, :, 2) * 256 + rgb(:, :, 3);
L = zeros(size(code), 'uint8');
for k = 1:numel(codes)
    L(code == codes(k)) = codeIdx(k);
end
end

% legenda: kotak warna + nama kelas
function showLegend(names, cmap)
axis([0 1 0 numel(names) + 1]); axis off; hold on;
for k = 1:numel(names)
    y = numel(names) + 1 - k;
    rectangle('Position', [0.05 y - 0.4 0.15 0.8], 'FaceColor', cmap(k, :), 'EdgeColor', 'k');
    text(0.25, y, names{k}, 'FontSize', 9);
end
hold off;
end

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
