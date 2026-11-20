function out = applySegmentationMethod(img, method, params)
% applySegmentationMethod - titik masuk tunggal ketiga bagian segmentasi
%
% img    : citra masukan (grayscale / RGB, uint8 / double / logical)
% method : 'edge' | 'splitmerge' | 'semantic'
% params : struct field sesuai metode (lihat daftar di bawah)
%
% out : struct dengan bentuk sama untuk semua metode, supaya GUI generik
%         .views      : struct array 4 elemen (.title, .image) untuk ditampilkan
%                       ([] di .image = panel itu dipakai untuk legenda)
%         .steps      : struct array tahapan (.title, .image), [] kalau tidak ada
%         .legend     : struct (.names, .colors, .ratio) untuk semantik, [] lainnya
%         .methodName : nama metode yang dipakai (untuk log/laporan)
%         .paramText  : parameter efektif yang dipakai (untuk log/laporan)
%         .summary    : cell array baris ringkasan hasil
%         .elapsed    : waktu proses (detik)
%
% Daftar field params per method (kosong / tidak ada = default):
%   edge        .Operator 'laplace'|'log'|'sobel'|'prewitt'|'roberts'|'canny'
%               .Sigma (>= 0)  .Threshold ([] = Otsu, 0 < T <= 1)
%               .LogSigma (> 0)  .ZcScale (>= 0)
%               .CannyThreshold ([] = otomatis, 0 < T <= 1)
%               .MinEdgeLength  .CloseRadius  .MaxCloseRadius (bulat >= 1)
%   splitmerge  .Predicate 'std'|'range'  .SplitThreshold  .MergeThreshold (0 < T <= 1)
%               .MinBlockSize (bulat >= 1)
%   semantic    .PythonExe (path python)  .ModelPath (file .pth)

if nargin < 2 || isempty(method)
    error('applySegmentationMethod:metodeKosong', 'Metode belum dipilih.');
end
if nargin < 3
    params = struct();
end
if ~isstruct(params)
    error('applySegmentationMethod:paramsBukanStruct', 'Parameter metode harus berupa struct.');
end

img = checkImage(img);
tStart = tic;

out = struct('views', [], 'steps', [], 'legend', [], 'methodName', '', ...
             'paramText', '', 'summary', {{}}, 'elapsed', 0);

switch lower(method)
    case 'edge'
        out = applyEdge(img, params, out);
    case 'splitmerge'
        out = applySplitMerge(img, params, out);
    case 'semantic'
        out = applySemantic(img, params, out);
    otherwise
        error('applySegmentationMethod:metodeTidakDikenal', ...
            'Metode tidak dikenal: %s. Pilih edge, splitmerge, atau semantic.', method);
end

out.elapsed = toc(tStart);
end

% ---------------------------------------------------------------------------
function out = applyEdge(img, params, out)

operator = lower(getText(params, 'Operator', 'sobel'));
operators = {'laplace', 'log', 'sobel', 'prewitt', 'roberts', 'canny'};
if ~any(strcmp(operator, operators))
    error('applySegmentationMethod:operatorTidakDikenal', ...
        'Operator tidak dikenal: %s. Pilih %s.', operator, strjoin(operators, ', '));
end

% ZcScale default beda untuk Laplace dan LoG (lihat detectEdges.m)
if strcmp(operator, 'log')
    zcDefault = 0.75;
else
    zcDefault = 1.5;
end

p.Sigma          = numParam(params, 'Sigma', 1.0, 'nonneg');
p.Threshold      = numParam(params, 'Threshold', [], 'unit');
p.LogSigma       = numParam(params, 'LogSigma', 2.0, 'pos');
p.ZcScale        = numParam(params, 'ZcScale', zcDefault, 'nonneg');
p.CannyThreshold = numParam(params, 'CannyThreshold', [], 'unit');
p.MinEdgeLength  = numParam(params, 'MinEdgeLength', 30, 'posint');
p.CloseRadius    = numParam(params, 'CloseRadius', 3, 'posint');
p.MaxCloseRadius = numParam(params, 'MaxCloseRadius', 15, 'posint');
if p.MaxCloseRadius < p.CloseRadius
    error('applySegmentationMethod:radiusTerbalik', ...
        'MaxCloseRadius (%d) tidak boleh lebih kecil dari CloseRadius (%d).', ...
        p.MaxCloseRadius, p.CloseRadius);
end

res = edgeSegmentation(img, operator, p);

edgePct = 100 * mean(res.edges(:));
maskPct = 100 * mean(res.mask(:));
out.views = makeViews( ...
    'Citra asli', img, ...
    sprintf('Citra tepi (%.1f%% piksel)', edgePct), res.edges, ...
    'Overlay batas objek', res.overlay, ...
    sprintf('Objek tersegmentasi (%.1f%% luas)', maskPct), res.segmented);

s = res.steps;
out.steps = struct( ...
    'title', {'1. Tepi biner', ...
              sprintf('2. Fragmen < %d px dibuang', p.MinEdgeLength), ...
              sprintf('3. Closing (r = %d)', s.radius), ...
              '4. Fill holes', '5. Opening', '6. Objek tersegmentasi'}, ...
    'image', {res.edges, s.cleaned, s.closed, s.filled, s.opened, res.segmented});

out.methodName = sprintf('Deteksi tepi - %s', upper(operator));
out.paramText  = sprintf('%s; MinEdgeLength = %d, CloseRadius = %d..%d', ...
    edgeParamText(operator, p), p.MinEdgeLength, p.CloseRadius, p.MaxCloseRadius);
out.summary = { ...
    sprintf('Piksel tepi            : %.1f%%', edgePct), ...
    sprintf('Luas objek             : %.1f%%', maskPct), ...
    sprintf('Radius closing dipakai : %d', s.radius)};
if ~any(res.mask(:))
    out.summary{end + 1} = ['PERINGATAN: tidak ada kontur tertutup. Coba perbesar ' ...
        'MaxCloseRadius atau kecilkan MinEdgeLength.'];
end
end

function t = edgeParamText(operator, p)
% hanya parameter yang benar-benar dipakai operator terpilih
switch operator
    case {'sobel', 'prewitt', 'roberts'}
        t = sprintf('Sigma = %g, Threshold = %s', p.Sigma, autoText(p.Threshold, 'Otsu'));
    case 'laplace'
        t = sprintf('Sigma = %g, ZcScale = %g', p.Sigma, p.ZcScale);
    case 'log'
        t = sprintf('LogSigma = %g, ZcScale = %g', p.LogSigma, p.ZcScale);
    case 'canny'
        t = sprintf('CannyThreshold = %s', autoText(p.CannyThreshold, 'otomatis'));
end
end

% ---------------------------------------------------------------------------
function out = applySplitMerge(img, params, out)

p.Predicate = lower(getText(params, 'Predicate', 'std'));
if ~any(strcmp(p.Predicate, {'std', 'range'}))
    error('applySegmentationMethod:predikatTidakDikenal', ...
        'Predikat tidak dikenal: %s. Pilih std atau range.', p.Predicate);
end
p.SplitThreshold = numParam(params, 'SplitThreshold', 0.06, 'unit');
p.MergeThreshold = numParam(params, 'MergeThreshold', 0.08, 'unit');
p.MinBlockSize   = numParam(params, 'MinBlockSize', 4, 'posint');

[~, ~, info] = splitAndMerge(img, p);

out.views = makeViews( ...
    'Citra asli', img, ...
    sprintf('After split (%d region)', info.numSplitRegions), info.splitRGB, ...
    sprintf('After merge (%d region)', info.numMergeRegions), info.mergeRGB, ...
    'Rekonstruksi rata-rata region', info.reconstructed);

out.methodName = sprintf('Split and Merge - predikat %s', p.Predicate);
out.paramText  = sprintf('SplitThreshold = %g, MergeThreshold = %g, MinBlockSize = %d', ...
    p.SplitThreshold, p.MergeThreshold, p.MinBlockSize);
out.summary = { ...
    sprintf('Region setelah split : %d', info.numSplitRegions), ...
    sprintf('Region setelah merge : %d', info.numMergeRegions)};
end

% ---------------------------------------------------------------------------
function out = applySemantic(img, params, out)

p.PythonExe = strtrim(getText(params, 'PythonExe', 'python'));
if isempty(p.PythonExe)
    error('applySegmentationMethod:pythonKosong', 'Path Python belum diisi.');
end

defaultModel = fullfile(fileparts(which('semanticSegmentation')), 'model', ...
                        'camvid_deeplabv3_mbv3.pth');
p.ModelPath = strtrim(getText(params, 'ModelPath', defaultModel));
if isempty(p.ModelPath)
    p.ModelPath = defaultModel;
end
if ~isfile(p.ModelPath)
    error('applySegmentationMethod:modelTidakAda', 'File model tidak ditemukan: %s', p.ModelPath);
end

res = semanticSegmentation(img, p);

out.views = makeViews( ...
    'Citra asli', img, ...
    'Label kelas per piksel', res.colorLabel, ...
    'Overlay label', res.overlay, ...
    'Legenda kelas', []);
out.legend = struct('names', {res.classNames}, 'colors', res.colormap, 'ratio', res.classRatio);

[~, model] = fileparts(p.ModelPath);
out.methodName = 'Semantic segmentation - DeepLabV3 MobileNetV3 (CamVid, 11 kelas)';
out.paramText  = sprintf('model = %s', model);

% 3 kelas terbanyak
[ratio, order] = sort(res.classRatio, 'descend');
out.summary = {'Kelas terbanyak:'};
for k = 1:min(3, nnz(ratio))
    out.summary{end + 1} = sprintf('  %-10s : %.1f%%', res.classNames{order(k)}, 100 * ratio(k));
end
end

% ---------------------------------------------------------------------------
% helper

function img = checkImage(img)
% validasi citra masukan + samakan ke uint8 grayscale / RGB
if ~(isnumeric(img) || islogical(img)) || isempty(img) || ndims(img) > 3
    error('applySegmentationMethod:citraTidakValid', ...
        'Citra masukan harus matriks 2D (grayscale) atau 3D (RGB).');
end
if size(img, 3) == 4
    img = img(:, :, 1:3);       % buang kanal alpha
end
if ~any(size(img, 3) == [1 3])
    error('applySegmentationMethod:citraTidakValid', ...
        'Citra harus 1 kanal (grayscale) atau 3 kanal (RGB), sekarang %d kanal.', size(img, 3));
end
if size(img, 1) < 8 || size(img, 2) < 8
    error('applySegmentationMethod:citraTerlaluKecil', ...
        'Citra minimal 8x8 piksel, sekarang %dx%d.', size(img, 2), size(img, 1));
end
if ~isa(img, 'uint8')
    img = im2uint8(img);
end
end

function views = makeViews(varargin)
% makeViews(judul1, citra1, judul2, citra2, ...) -> struct array (.title, .image)
views = struct('title', varargin(1:2:end), 'image', varargin(2:2:end));
end

function v = numParam(s, name, default, rule)
% ambil parameter angka dari struct lalu cek rentangnya.
% rule: 'nonneg' (>= 0), 'pos' (> 0), 'unit' (0 < v <= 1), 'posint' (bulat >= 1)
if ~isfield(s, name) || isempty(s.(name))
    v = default;
    return;
end
v = s.(name);
if ~isnumeric(v) || ~isscalar(v) || ~isreal(v) || ~isfinite(v)
    error('applySegmentationMethod:bukanAngka', 'Parameter %s harus berupa satu angka.', name);
end
v = double(v);

switch rule
    case 'nonneg', ok = v >= 0;           syarat = '>= 0';
    case 'pos',    ok = v > 0;            syarat = '> 0';
    case 'unit',   ok = v > 0 && v <= 1;  syarat = 'di antara 0 (eksklusif) dan 1';
    case 'posint', ok = v >= 1 && v == round(v); syarat = 'bilangan bulat >= 1';
end
if ~ok
    error('applySegmentationMethod:diLuarRentang', ...
        'Parameter %s harus %s, sekarang %g.', name, syarat, v);
end
end

function v = getText(s, name, default)
if ~isfield(s, name) || isempty(s.(name))
    v = default;
    return;
end
v = s.(name);
if ~(ischar(v) || (isstring(v) && isscalar(v)))
    error('applySegmentationMethod:bukanTeks', 'Parameter %s harus berupa teks.', name);
end
v = char(v);
end

function t = autoText(v, autoName)
if isempty(v)
    t = autoName;
else
    t = sprintf('%g', v);
end
end
