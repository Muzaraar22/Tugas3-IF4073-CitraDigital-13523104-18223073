% uji titik masuk GUI (applySegmentationMethod): bentuk keluaran & validasi input
% jalankan dari root repo:
%   run('tests/test_apply_segmentation.m')
%
% isi pengujian:
%   1. tiap metode valid -> 4 view, view citra seukuran citra masukan
%   2. berbagai format citra (grayscale, RGBA, logical, double) bisa diproses
%   3. parameter / citra tidak valid -> error dengan ID yang tepat
%   4. semantik di-SKIP kalau python + torch atau file model tidak tersedia

clear; clc; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(rootDir, 'src')));

% python yang terpasang torch & torchvision, contoh Windows:
%   'C:\Users\nama\AppData\Local\Programs\Python\Python311\python.exe'
pythonExe = 'python';

stats = [0 0];   % [jumlah PASS, jumlah FAIL]
I = imread(fullfile(rootDir, 'data', 'BSDS500', '2018.jpg'));
I = I(1:120, 1:100, :);   % potong supaya cepat
sz = [size(I, 1) size(I, 2)];

%% 1. keluaran tiap metode
% view 2 = respons operator (abu-abu 0..1, belum biner), tahap 2 = tepi biner
for op = {'laplace', 'log', 'sobel', 'prewitt', 'roberts', 'canny'}
    for mode = {'otsu', 'percentile', 'manual'}
        out = applySegmentationMethod(I, 'edge', struct('Operator', op{1}, 'ThresholdMode', mode{1}));
        resp = out.views(2).image;
        ok = numel(out.views) == 4 && numel(out.steps) == 8 && sameSize(out.views, sz) && ...
             isfloat(resp) && min(resp(:)) >= 0 && max(resp(:)) <= 1 && ...
             islogical(out.steps(2).image);
        stats = report(ok, sprintf('edge %-8s %-10s: 4 view + 8 tahap, respons 0..1', ...
            op{1}, mode{1}), stats);
    end
end

out = applySegmentationMethod(I, 'edge', struct('Operator', 'canny', ...
    'ThresholdMode', 'manual', 'Threshold', 0.1));
stats = report(contains(out.paramText, 'Manual, T = 0.100'), 'edge canny: ambang manual dipakai', stats);

% persentil makin besar -> piksel tepi makin sedikit
e = zeros(1, 2);
P = [70 95];
for k = 1:2
    out = applySegmentationMethod(I, 'edge', struct('ThresholdMode', 'percentile', 'Percentile', P(k)));
    e(k) = nnz(out.steps(2).image);
end
stats = report(e(1) > e(2), sprintf('persentil 70 -> %d px tepi, 95 -> %d px', e(1), e(2)), stats);

out = applySegmentationMethod(I, 'splitmerge', struct());
stats = report(numel(out.views) == 4 && isempty(out.steps) && sameSize(out.views, sz), ...
    'splitmerge default: 4 view, tanpa tahapan', stats);
out = applySegmentationMethod(I, 'splitmerge', struct('Predicate', 'range', 'MinBlockSize', 8));
stats = report(contains(out.methodName, 'range'), 'splitmerge predikat range', stats);

%% 2. format citra
formats = {
    'grayscale uint8', rgb2gray(I)
    'RGBA',            cat(3, I, 255 * ones(sz, 'uint8'))
    'logical',         rgb2gray(I) > 128
    'double 0..1',     im2double(I)
};
for k = 1:size(formats, 1)
    ok = true;
    try
        out = applySegmentationMethod(formats{k, 2}, 'edge', struct());
        ok = sameSize(out.views, sz);
    catch
        ok = false;
    end
    stats = report(ok, sprintf('citra %s bisa diproses', formats{k, 1}), stats);
end

%% 3. validasi: setiap kasus harus melempar error dengan ID ini
cases = {
    % deskripsi                      citra          method        params                                       ID error
    'metode kosong',                  I,             '',           struct(),                                    'metodeKosong'
    'metode tidak dikenal',           I,             'watershed',  struct(),                                    'metodeTidakDikenal'
    'params bukan struct',            I,             'edge',       42,                                          'paramsBukanStruct'
    'citra kosong',                   [],            'edge',       struct(),                                    'citraTidakValid'
    'citra 2 kanal',                  I(:, :, 1:2),  'edge',       struct(),                                    'citraTidakValid'
    'citra teks',                     'abc',         'edge',       struct(),                                    'citraTidakValid'
    'citra terlalu kecil',            I(1:5, 1:5, :),'edge',       struct(),                                    'citraTerlaluKecil'
    'operator tidak dikenal',         I,             'edge',       struct('Operator', 'kirsch'),                'operatorTidakDikenal'
    'operator bukan teks',            I,             'edge',       struct('Operator', 3),                       'bukanTeks'
    'Sigma negatif',                  I,             'edge',       struct('Sigma', -1),                         'diLuarRentang'
    'Sigma bukan angka',              I,             'edge',       struct('Sigma', 'satu'),                     'bukanAngka'
    'Sigma NaN',                      I,             'edge',       struct('Sigma', NaN),                        'bukanAngka'
    'Sigma vektor',                   I,             'edge',       struct('Sigma', [1 2]),                      'bukanAngka'
    'Threshold > 1',                  I,             'edge',       struct('Threshold', 1.5),                    'diLuarRentang'
    'Threshold = 0',                  I,             'edge',       struct('Threshold', 0),                      'diLuarRentang'
    'LogSigma = 0',                   I,             'edge',       struct('Operator', 'log', 'LogSigma', 0),    'diLuarRentang'
    'metode ambang tidak dikenal',    I,             'edge',       struct('ThresholdMode', 'triangle'),         'modeAmbangTidakDikenal'
    'Percentile = 0',                 I,             'edge',       struct('Percentile', 0),                     'diLuarRentang'
    'Percentile = 100',               I,             'edge',       struct('Percentile', 100),                   'diLuarRentang'
    'MinEdgeLength pecahan',          I,             'edge',       struct('MinEdgeLength', 2.5),                'diLuarRentang'
    'CloseRadius 0',                  I,             'edge',       struct('CloseRadius', 0),                    'diLuarRentang'
    'MaxCloseRadius < CloseRadius',   I,             'edge',       struct('CloseRadius', 9, 'MaxCloseRadius', 5), 'radiusTerbalik'
    'predikat tidak dikenal',         I,             'splitmerge', struct('Predicate', 'mean'),                 'predikatTidakDikenal'
    'SplitThreshold > 1',             I,             'splitmerge', struct('SplitThreshold', 5),                 'diLuarRentang'
    'MergeThreshold negatif',         I,             'splitmerge', struct('MergeThreshold', -0.1),              'diLuarRentang'
    'MinBlockSize 0',                 I,             'splitmerge', struct('MinBlockSize', 0),                   'diLuarRentang'
    'PythonExe spasi saja',           I,             'semantic',   struct('PythonExe', '   '),                  'pythonKosong'
    'model tidak ada',                I,             'semantic',   struct('ModelPath', 'tidak_ada.pth'),        'modelTidakAda'
};
for k = 1:size(cases, 1)
    expectedId = ['applySegmentationMethod:' cases{k, 5}];
    try
        applySegmentationMethod(cases{k, 2}, cases{k, 3}, cases{k, 4});
        gotId = '(tidak error)';
    catch ex
        gotId = ex.identifier;
    end
    stats = report(strcmp(gotId, expectedId), ...
        sprintf('%-30s -> %s', cases{k, 1}, strrep(gotId, 'applySegmentationMethod:', '')), stats);
end

%% 4. semantik (butuh python + torch + model)
modelPath = fullfile(rootDir, 'src', 'semantic_segmentation', 'model', 'camvid_deeplabv3_mbv3.pth');
[st, ~] = system(sprintf('"%s" -c "import torch, torchvision"', pythonExe));
if st ~= 0 || ~isfile(modelPath)
    fprintf('[SKIP] semantik: %s belum terpasang torch, atau model tidak ada\n', pythonExe);
else
    out = applySegmentationMethod(I, 'semantic', struct('PythonExe', pythonExe));
    okLegend = numel(out.legend.names) == 11 && abs(sum(out.legend.ratio) - 1) < 1e-9;
    stats = report(numel(out.views) == 4 && isempty(out.views(4).image) && okLegend && ...
        sameSize(out.views(1:3), sz), 'semantic: 3 view citra + legenda 11 kelas', stats);
end

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

% semua view yang berisi citra berukuran sz (baris x kolom)
function ok = sameSize(views, sz)
ok = true;
for k = 1:numel(views)
    img = views(k).image;
    if ~isempty(img) && ~isequal([size(img, 1) size(img, 2)], sz)
        ok = false;
    end
end
end
