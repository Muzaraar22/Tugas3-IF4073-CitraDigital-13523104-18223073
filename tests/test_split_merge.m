clc; clear; close all;

testDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(testDir);

addpath(genpath(fullfile(rootDir, 'src')));

dataDir = fullfile(rootDir, 'data', 'BSDS500');
outDir  = fullfile(rootDir, 'results', 'split_merge');

imgFiles = dir(fullfile(dataDir, '*.jpg'));
if isempty(imgFiles)
    error('Tidak ada file .jpg ditemukan di folder: %s', dataDir);
end

% Parameter uji (sesuaikan per citra sesuai kebutuhan)
params.SplitThreshold = 0.06;
params.MergeThreshold = 0.08;
params.MinBlockSize   = 4;
params.Predicate      = 'std';
params.Normalize      = true;

fprintf('=== Pengujian Split and Merge pada %d Citra BSDS500 ===\n', length(imgFiles));

for k = 1:length(imgFiles)
    fname = imgFiles(k).name;
    I = imread(fullfile(dataDir, fname));

    [~, ~, info] = splitAndMerge(I, params);

    fprintf('[%d/%d] %s | Split: %d region -> Merge: %d region (%.3f dtk)\n', ...
        k, length(imgFiles), fname, info.numSplitRegions, info.numMergeRegions, info.executionTime);

    % Tampilkan hasil dalam jendela pop-up interaktif
    fig = figure('Name', sprintf('[%d/%d] Hasil Split & Merge - %s', k, length(imgFiles), fname), ...
                 'NumberTitle', 'off', ...
                 'Position', [100, 120, 1200, 380]);

    subplot(1, 4, 1); imshow(I); title('Citra Asli');
    subplot(1, 4, 2); imshow(info.splitRGB); title(sprintf('After Split (%d)', info.numSplitRegions));
    subplot(1, 4, 3); imshow(info.mergeRGB); title(sprintf('After Merge (%d)', info.numMergeRegions));
    subplot(1, 4, 4); imshow(info.reconstructed); title('Rekonstruksi Mean');

    % Tombol aksi di bagian bawah jendela pop-up
    btnSave = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'String', 'Simpan ke Results', ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'Position', [430, 12, 160, 32]);

    btnNext = uicontrol('Parent', fig, 'Style', 'pushbutton', ...
        'String', 'Lanjut (Next)', ...
        'FontSize', 10, ...
        'Position', [610, 12, 140, 32], ...
        'Callback', @(~, ~) uiresume(fig));

    btnSave.Callback = @(src, ~) saveFigureClean(fig, src, btnNext, outDir, fname);

    % Tunggu hingga pengguna menekan tombol Lanjut atau menutup jendela pop-up
    uiwait(fig);
    if isvalid(fig)
        close(fig);
    end
end

fprintf('Pengujian selesai.\n');

function saveFigureClean(fig, btnSave, btnNext, outDir, fname)
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % Sembunyikan tombol sesaat agar gambar yang tersimpan bersih
    btnSave.Visible = 'off';
    btnNext.Visible = 'off';
    drawnow;

    savePath = fullfile(outDir, ['sm_', fname]);
    saveas(fig, savePath);

    btnSave.Visible = 'on';
    btnNext.Visible = 'on';
    btnSave.String = 'Tersimpan!';
    btnSave.Enable = 'off';
    fprintf('   -> Disimpan ke: %s\n', savePath);
end