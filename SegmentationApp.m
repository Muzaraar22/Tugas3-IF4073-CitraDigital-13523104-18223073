function app = SegmentationApp()
% SegmentationApp - GUI segmentasi citra: deteksi tepi, split and merge,
% dan semantic segmentation (CNN CamVid)

rootFolder = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(rootFolder, 'src')));
addpath(fullfile(rootFolder, 'gui'));

app = initApp(rootFolder);

% dipanggil tanpa output: jangan cetak isi app ke command window
if nargout == 0
    clear app;
end
end

% ===========================================================================
% Pembangunan UI
% ===========================================================================

function app = initApp(rootFolder)

app = AppState();
app.RootFolder = rootFolder;
app.DatasetIdx = datasetIndex(fullfile(rootFolder, 'data'));
app.Panels = struct('edge', [], 'splitmerge', [], 'semantic', []);

% ukuran figure menyesuaikan layar supaya tidak terpotong di layar kecil
layar  = get(groot, 'ScreenSize');
lebar  = min(1360, layar(3) - 60);
tinggi = min(820,  layar(4) - 110);

app.Figure = uifigure( ...
    'Name',            'Segmentasi Citra - IF4073', ...
    'Position',        [30 50 lebar tinggi], ...
    'Theme',           'light', ...
    'Color',           [0.94 0.94 0.94], ...
    'Visible',         'off', ...
    'CloseRequestFcn', @(src, ~) delete(src));

% ---- pembagian: panel kontrol kiri (lebar tetap) + area tampilan kanan ----
main = uigridlayout(app.Figure, [1 2]);
main.ColumnWidth = {330, '1x'};
main.ColumnSpacing = 4;
main.Padding = [0 0 0 0];
main.BackgroundColor = [0.94 0.94 0.94];

leftPanel = uipanel(main, 'BorderType', 'none', 'BackgroundColor', [0.96 0.96 0.96]);
rightPanel = uipanel(main, 'BorderType', 'none', 'BackgroundColor', [0.94 0.94 0.94]);

buildLeftPanel(app, leftPanel);
buildRightPanel(app, rightPanel);

onSourceChanged(app);
onMethodChanged(app);
onOperatorChanged(app);
showResult(app);

% figure dibuat visible setelah semua komponen siap supaya tidak berkedip
app.Figure.Visible = 'on';
end

% ---------------------------------------------------------------------------
function buildLeftPanel(app, parent)

p = uigridlayout(parent, [10 1]);
p.RowHeight = {22, 26, 120, 28, 18, 22, 26, 22, '1x', 32};
p.RowSpacing = 4;
p.Padding = [8 8 8 8];
p.BackgroundColor = [0.96 0.96 0.96];

% --- 1. pilih citra ---------------------------------------------------------
sectionLabel(p, '1. PILIH CITRA');

if isempty(app.DatasetIdx)
    sumber = {'(data/ tidak ditemukan)'};
else
    sumber = {app.DatasetIdx.name};
end
app.SourceBox = uidropdown(p, 'Items', sumber, 'BackgroundColor', 'w', ...
    'Tooltip', 'Sumber citra uji di folder data/');
app.SourceBox.ValueChangedFcn = @(~, ~) onSourceChanged(app);

app.ImageBox = uilistbox(p, 'Items', {}, 'Tooltip', 'Citra di sumber terpilih');

loadRow = rowGrid(p, {'1x', 110});
uibutton(loadRow, 'Text', 'Muat Citra', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.30 0.50 0.75], 'FontColor', 'w', ...
    'ButtonPushedFcn', @(~, ~) loadSelectedImage(app));
uibutton(loadRow, 'Text', 'Dari File...', ...
    'BackgroundColor', [0.85 0.85 0.85], ...
    'Tooltip', 'Buka file citra lain di luar dataset', ...
    'ButtonPushedFcn', @(~, ~) onOpenImageFile(app));

app.InfoLabel = uilabel(p, 'Text', 'Belum ada citra dimuat.', ...
    'FontSize', 10, 'FontColor', [0.2 0.2 0.2]);

% --- 2. pilih metode -------------------------------------------------------
sectionLabel(p, '2. METODE');
app.MethodBox = uidropdown(p, ...
    'Items',     {'Deteksi Tepi (Bagian B)', 'Split and Merge (Bagian C)', ...
                  'Semantic Segmentation CNN (Bagian D)'}, ...
    'ItemsData', {'edge', 'splitmerge', 'semantic'}, ...
    'Value', 'edge', 'BackgroundColor', 'w');
app.MethodBox.ValueChangedFcn = @(~, ~) onMethodChanged(app);

% --- 3. parameter (hanya panel metode terpilih yang terlihat) ---------------
sectionLabel(p, '3. PARAMETER');
app.ParamStack = uigridlayout(p, [3 1]);
app.ParamStack.RowSpacing = 0;
app.ParamStack.Padding = [0 0 0 0];
app.ParamStack.BackgroundColor = [0.96 0.96 0.96];

buildEdgePanel(app);
buildSplitMergePanel(app);
buildSemanticPanel(app);

% --- 4. aksi ---------------------------------------------------------------
actionRow = rowGrid(p, {'1x', '1x'});
uibutton(actionRow, 'Text', 'Proses', ...
    'FontWeight', 'bold', 'BackgroundColor', [0.20 0.55 0.35], 'FontColor', 'w', ...
    'Tooltip', 'Jalankan metode terpilih pada citra masukan', ...
    'ButtonPushedFcn', @(~, ~) onProcess(app));
app.SaveButton = uibutton(actionRow, 'Text', 'Simpan Hasil', ...
    'BackgroundColor', [0.85 0.85 0.85], 'Enable', 'off', ...
    'Tooltip', 'Simpan 4 panel hasil ke results/gui/ sebagai PNG', ...
    'ButtonPushedFcn', @(~, ~) onSave(app));
end

% ---------------------------------------------------------------------------
function buildEdgePanel(app)

g = paramPanel(app, 'edge', 1, 13);

% --- a. konvolusi operator -> respons --------------------------------------
subSection(g, 'a. Deteksi tepi (konvolusi)');

uilabel(g, 'Text', 'Operator');
app.EdgeOperator = uidropdown(g, ...
    'Items',     {'Laplace', 'LoG', 'Sobel', 'Prewitt', 'Roberts', 'Canny (built-in)'}, ...
    'ItemsData', {'laplace', 'log', 'sobel', 'prewitt', 'roberts', 'canny'}, ...
    'Value', 'sobel', 'BackgroundColor', 'w');
app.EdgeOperator.ValueChangedFcn = @(~, ~) onOperatorChanged(app);

uilabel(g, 'Text', 'Sigma Gaussian');
app.EdgeSigma = uispinner(g, 'Value', 0, 'Limits', [0 Inf], 'Step', 0.1, ...
    'Tooltip', ['Pelembutan Gaussian opsional sebelum Sobel/Prewitt/Roberts/Laplace. ' ...
                '0 (bawaan) = operator langsung pada citra asli']);

uilabel(g, 'Text', 'Sigma LoG');
app.EdgeLogSigma = uispinner(g, 'Value', 2.0, 'Limits', [0 Inf], ...
    'LowerLimitInclusive', 'off', 'Step', 0.1, ...
    'Tooltip', 'Sigma mask LoG: makin besar makin sedikit tepi halus');

% --- b. ambang -> tepi biner -----------------------------------------------
subSection(g, 'b. Ambang (respons -> tepi biner)');

thrTip = ['Ambang diterapkan pada kekuatan tepi skala 0..1: magnitudo gradien ' ...
    '(Sobel/Prewitt/Roberts/Canny) atau kecuraman zero-crossing (Laplace/LoG). ' ...
    'Pada Canny nilai ini menjadi T_high, dengan T_low = 0.4 x T_high.'];
uilabel(g, 'Text', 'Metode ambang');
app.EdgeThrMode = uidropdown(g, ...
    'Items',     {'Otsu (otomatis)', 'Persentil', 'Manual'}, ...
    'ItemsData', {'otsu', 'percentile', 'manual'}, ...
    'Value', 'otsu', 'BackgroundColor', 'w', ...
    'Tooltip', ['Otsu: ambang yang paling memisahkan histogram kekuatan tepi menjadi ' ...
                '2 kelas. Persentil: P% kandidat terlemah dibuang. Manual: T tetap. ' thrTip]);
app.EdgeThrMode.ValueChangedFcn = @(~, ~) onThresholdModeChanged(app);

uilabel(g, 'Text', 'Persentil P (%)');
app.EdgePercentile = uispinner(g, 'Value', 90, 'Limits', [0 100], ...
    'LowerLimitInclusive', 'off', 'UpperLimitInclusive', 'off', 'Step', 1, ...
    'Tooltip', ['P% kandidat tepi terlemah dibuang, (100 - P)% terkuat menjadi tepi. ' thrTip]);

uilabel(g, 'Text', 'Threshold manual');
app.EdgeT = unitSpinner(g, 0.2, ['Ambang T (0..1] relatif terhadap respons maksimum. ' thrTip]);

% --- c. morfologi -> region ------------------------------------------------
subSection(g, 'c. Pembentukan region (morfologi)');

uilabel(g, 'Text', 'MinEdgeLength');
app.EdgeMinLength = intSpinner(g, 30, ...
    'Fragmen tepi yang lebih pendek dari ini (piksel) dibuang');

uilabel(g, 'Text', 'CloseRadius');
app.EdgeCloseR = intSpinner(g, 3, ...
    'Radius awal closing: celah kontur sampai ~2r piksel disambung');

uilabel(g, 'Text', 'MaxCloseRadius');
app.EdgeMaxCloseR = intSpinner(g, 15, ...
    'Radius dinaikkan +2 sampai nilai ini kalau belum ada kontur tertutup');

hint(g, ['Alur: konvolusi -> ambang -> tepi biner -> morfologi -> region. ' ...
    'Field abu-abu tidak dipakai. Setiap tahap bisa dilihat di tab Tahapan Tepi.']);
end

% ---------------------------------------------------------------------------
function buildSplitMergePanel(app)

g = paramPanel(app, 'splitmerge', 2, 5);

uilabel(g, 'Text', 'Predikat Q(R)');
app.SmPredicate = uidropdown(g, ...
    'Items', {'Standar deviasi (std)', 'Rentang max - min (range)'}, ...
    'ItemsData', {'std', 'range'}, 'Value', 'std', 'BackgroundColor', 'w');

uilabel(g, 'Text', 'Split threshold');
app.SmSplitT = unitSpinner(g, 0.06, ...
    'Blok dibelah selama Q(blok) > threshold. Kecil = lebih banyak blok');

uilabel(g, 'Text', 'Merge threshold');
app.SmMergeT = unitSpinner(g, 0.08, ...
    'Region bertetangga digabung kalau Q(gabungan) <= threshold. Besar = lebih sedikit region');

uilabel(g, 'Text', 'Min block size');
app.SmMinBlock = intSpinner(g, 4, ...
    'Ukuran blok terkecil (piksel). Pembelahan berhenti di ukuran ini');

hint(g, ['Q dihitung pada citra grayscale skala 0..1. Citra besar dengan min block ' ...
    'size kecil bisa butuh beberapa detik.']);
end

% ---------------------------------------------------------------------------
function buildSemanticPanel(app)

g = paramPanel(app, 'semantic', 3, 3);

uilabel(g, 'Text', 'Python');
row = rowGrid(g, {'1x', 50});
app.SemPython = uieditfield(row, 'Value', 'python', ...
    'Tooltip', 'Python yang sudah terpasang torch & torchvision (requirements.txt)');
uibutton(row, 'Text', 'Cari', 'ButtonPushedFcn', @(~, ~) onBrowsePython(app));

uilabel(g, 'Text', 'Model (.pth)');
row = rowGrid(g, {'1x', 50});
app.SemModel = uieditfield(row, 'Value', fullfile(app.RootFolder, 'src', ...
    'semantic_segmentation', 'model', 'camvid_deeplabv3_mbv3.pth'));
uibutton(row, 'Text', 'Cari', 'ButtonPushedFcn', @(~, ~) onBrowseModel(app));

hint(g, ['Inferensi dijalankan di Python (camvid_predict.py), jadi proses pertama ' ...
    'bisa beberapa detik karena memuat model. Citra CamVid test ada di sumber ' ...
    '"CamVid test".']);
end

% ---------------------------------------------------------------------------
function buildRightPanel(app, parent)

host = uigridlayout(parent, [1 1]);
host.Padding = [0 0 0 0];
host.BackgroundColor = [0.94 0.94 0.94];

app.TabGroup  = uitabgroup(host);
app.ResultTab = uitab(app.TabGroup, 'Title', 'Hasil');
app.StepsTab  = uitab(app.TabGroup, 'Title', 'Tahapan Tepi');

% tab Hasil: 4 citra (2x2) + log
g = uigridlayout(app.ResultTab, [3 2]);
g.RowHeight = {'1x', '1x', 130};
g.RowSpacing = 6;
g.ColumnSpacing = 6;
g.Padding = [6 6 6 6];
g.BackgroundColor = [0.94 0.94 0.94];

app.ViewPanels = gobjects(1, 4);
app.ViewAxes   = gobjects(1, 4);
for k = 1:4
    row = ceil(k / 2);
    col = 2 - mod(k, 2);
    app.ViewPanels(k) = makeDisplayPanel(g, sprintf('PANEL %d', k), row, col);
    app.ViewAxes(k)   = makeImageAxes(app, app.ViewPanels(k));
end

logPanel = makeDisplayPanel(g, 'LOG: METODE, PARAMETER & HASIL', 3, [1 2]);
inner = uigridlayout(logPanel, [1 1]);
inner.Padding = [0 2 0 2];
inner.BackgroundColor = 'w';
app.LogText = uitextarea(inner, 'Editable', 'off', ...
    'FontName', 'Consolas', 'FontSize', 10);

% tab Tahapan Tepi: 8 citra (2x4)
g = uigridlayout(app.StepsTab, [2 4]);
g.RowSpacing = 6;
g.ColumnSpacing = 6;
g.Padding = [6 6 6 6];
g.BackgroundColor = [0.94 0.94 0.94];

app.StepPanels = gobjects(1, 8);
app.StepAxes   = gobjects(1, 8);
for k = 1:8
    row = ceil(k / 4);
    col = k - 4 * (row - 1);
    app.StepPanels(k) = makeDisplayPanel(g, sprintf('TAHAP %d', k), row, col);
    app.StepAxes(k)   = makeImageAxes(app, app.StepPanels(k));
end
end

% ---------------------------------------------------------------------------
% pembuat komponen kecil

function g = paramPanel(app, name, row, nRows)
% panel parameter satu metode: grid label | kontrol, baris terakhir untuk hint
pnl = uipanel(app.ParamStack, 'BorderType', 'line', 'BackgroundColor', [0.99 0.99 0.99]);
pnl.Layout.Row = row;
app.Panels.(name) = pnl;

g = uigridlayout(pnl, [nRows 2]);
g.Scrollable = 'on';      % jendela pendek: panel parameter bisa digulir
g.RowHeight = [repmat({26}, 1, nRows - 1), {'1x'}];
g.ColumnWidth = {115, '1x'};
g.RowSpacing = 6;
g.ColumnSpacing = 6;
g.Padding = [10 10 10 10];
g.BackgroundColor = [0.99 0.99 0.99];
end

function sectionLabel(parent, text)
uilabel(parent, 'Text', text, 'FontWeight', 'bold', 'FontColor', [0.15 0.25 0.45]);
end

function subSection(g, text)
% judul kelompok parameter di dalam panel parameter (selebar 2 kolom)
sub = uilabel(g, 'Text', text, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
sub.Layout.Column = [1 2];
end

function g = rowGrid(parent, widths)
% grid 1 baris tanpa padding untuk menaruh beberapa kontrol berdampingan
g = uigridlayout(parent, [1 numel(widths)]);
g.ColumnWidth = widths;
g.ColumnSpacing = 6;
g.Padding = [0 0 0 0];
g.BackgroundColor = parent.BackgroundColor;
end

function hint(g, text)
h = uilabel(g, 'Text', text, 'WordWrap', 'on', 'FontSize', 10, ...
    'FontColor', [0.3 0.3 0.3], 'VerticalAlignment', 'top');
h.Layout.Column = [1 2];
end

function s = intSpinner(parent, value, tip)
s = uispinner(parent, 'Value', value, 'Limits', [1 Inf], 'Step', 1, ...
    'RoundFractionalValues', 'on', 'Tooltip', tip);
end

function s = unitSpinner(parent, value, tip)
% angka di (0, 1]
s = uispinner(parent, 'Value', value, 'Limits', [0 1], 'LowerLimitInclusive', 'off', ...
    'Step', 0.01, 'ValueDisplayFormat', '%.3f', 'Tooltip', tip);
end

function pnl = makeDisplayPanel(parent, title, row, col)
% AutoResizeChildren dimatikan: kalau aktif, posisi axes ikut digeser saat
% panel berubah ukuran sehingga citra tidak lagi di tengah (mis. full screen)
pnl = uipanel(parent, 'Title', title, 'FontSize', 10, 'FontWeight', 'bold', ...
    'BorderType', 'line', 'BackgroundColor', 'w', 'AutoResizeChildren', 'off', ...
    'Tooltip', 'Klik kanan pada gambar lalu pilih "Salin gambar" untuk menyalinnya');
pnl.Layout.Row = row;
pnl.Layout.Column = col;
end

function ax = makeImageAxes(app, parent)
% axes biasa dengan posisi eksplisit supaya citra mengisi panel
ax = axes('Parent', parent, 'Position', [0.01 0.01 0.98 0.98], 'Visible', 'off');
cm = uicontextmenu(app.Figure);
uimenu(cm, 'Text', 'Salin gambar', 'MenuSelectedFcn', @(~, ~) onCopyAxes(app, ax));
ax.ContextMenu = cm;
end

% ===========================================================================
% Callback
% ===========================================================================

function onSourceChanged(app)
k = currentSource(app);
if isempty(k)
    app.ImageBox.Items = {};
    return;
end
app.ImageBox.Items = app.DatasetIdx(k).files;
app.ImageBox.Value = app.DatasetIdx(k).files{1};
end

function k = currentSource(app)
k = [];
if ~isempty(app.DatasetIdx)
    k = find(strcmp({app.DatasetIdx.name}, app.SourceBox.Value), 1);
end
end

function loadSelectedImage(app)
k = currentSource(app);
if isempty(k) || isempty(app.ImageBox.Value)
    uialert(app.Figure, ['Tidak ada citra dataset yang terpilih. Pastikan folder ' ...
        'data/BSDS500 ada, atau pakai "Dari File...".'], 'Citra tidak bisa dimuat');
    return;
end
loadImage(app, fullfile(app.DatasetIdx(k).path, app.ImageBox.Value));
end

function onOpenImageFile(app)
[fileName, pathName] = uigetfile({'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
    'File citra (*.png, *.jpg, *.bmp, *.tif)'; '*.*', 'Semua file'}, 'Pilih citra');
figure(app.Figure);     % uigetfile memindahkan fokus dari uifigure
if isequal(fileName, 0), return; end   % pengguna membatalkan
loadImage(app, fullfile(pathName, fileName));
end

function loadImage(app, path)
% baca citra, rapikan formatnya, lalu jadikan citra masukan
try
    [img, map] = imread(path);
catch ex
    uialert(app.Figure, sprintf('Gagal membaca citra:\n%s', ex.message), ...
        'Citra tidak bisa dimuat');
    return;
end

if ~isempty(map)
    img = ind2rgb(img, map);    % citra indexed -> RGB
end
if size(img, 3) == 4
    img = img(:, :, 1:3);       % buang kanal alpha / keempat
end
if ~any(size(img, 3) == [1 3]) || size(img, 1) < 8 || size(img, 2) < 8
    uialert(app.Figure, sprintf(['Format citra tidak didukung (%s). Citra harus ' ...
        'grayscale atau RGB, minimal 8x8 piksel.'], mat2str(size(img))), ...
        'Citra tidak bisa dimuat');
    return;
end
if ~isa(img, 'uint8')
    img = im2uint8(img);
end

[~, name, ext] = fileparts(path);
app.Original = img;
app.FileName = [name ext];
app.Result   = [];
app.Method   = '';

if size(img, 3) == 3, jenis = 'RGB'; else, jenis = 'Grayscale'; end
app.InfoLabel.Text = sprintf('%s | %s %dx%d', app.FileName, jenis, size(img, 2), size(img, 1));
app.InfoLabel.Tooltip = app.InfoLabel.Text;

showResult(app);

if max(size(img, [1 2])) > 1500
    uialert(app.Figure, sprintf(['Citra cukup besar (%dx%d). Split and merge dan ' ...
        'segmentasi semantik bisa lambat.'], size(img, 2), size(img, 1)), ...
        'Citra besar', 'Icon', 'warning');
end
end

function onMethodChanged(app)
method = app.MethodBox.Value;
names = fieldnames(app.Panels);
heights = cell(1, numel(names));
for k = 1:numel(names)
    aktif = strcmp(names{k}, method);
    app.Panels.(names{k}).Visible = aktif;
    % uigridlayout tetap memberi tinggi untuk panel tersembunyi, jadi barisnya dilipat
    if aktif, heights{k} = '1x'; else, heights{k} = 0; end
end
app.ParamStack.RowHeight = heights;
end

function onOperatorChanged(app)
% nyalakan hanya field yang dipakai operator terpilih
% (Canny memakai pelembutan bawaannya sendiri, LoG memakai Sigma LoG)
op = app.EdgeOperator.Value;
app.EdgeSigma.Enable    = onOff(any(strcmp(op, {'sobel', 'prewitt', 'roberts', 'laplace'})));
app.EdgeLogSigma.Enable = onOff(strcmp(op, 'log'));

% ambang kembali ke default operator (sama dengan detectEdges.m):
% Laplace/LoG persentil 70, lainnya Otsu
if any(strcmp(op, {'laplace', 'log'}))
    app.EdgeThrMode.Value    = 'percentile';
    app.EdgePercentile.Value = 70;
else
    app.EdgeThrMode.Value    = 'otsu';
    app.EdgePercentile.Value = 90;
end
onThresholdModeChanged(app);
end

function onThresholdModeChanged(app)
% hanya spinner milik metode ambang terpilih yang aktif
mode = app.EdgeThrMode.Value;
app.EdgePercentile.Enable = onOff(strcmp(mode, 'percentile'));
app.EdgeT.Enable          = onOff(strcmp(mode, 'manual'));
end

function onBrowsePython(app)
[f, p] = uigetfile({'python*.exe;python*', 'Python'; '*.*', 'Semua file'}, 'Pilih python');
figure(app.Figure);
if ~isequal(f, 0)
    app.SemPython.Value = fullfile(p, f);
end
end

function onBrowseModel(app)
[f, p] = uigetfile({'*.pth', 'Model PyTorch (*.pth)'}, 'Pilih model');
figure(app.Figure);
if ~isequal(f, 0)
    app.SemModel.Value = fullfile(p, f);
end
end

% ---------------------------------------------------------------------------
function onProcess(app)
if isempty(app.Original)
    uialert(app.Figure, 'Muat citra dulu sebelum memproses.', 'Citra belum dimuat');
    return;
end

[method, params] = collectInputs(app);

% split and merge dan CNN bisa beberapa detik, jadi tampilkan dialog tunggu
label = app.MethodBox.Items{strcmp(app.MethodBox.ItemsData, method)};
dlg = uiprogressdlg(app.Figure, 'Title', 'Memproses', 'Indeterminate', 'on', ...
    'Message', sprintf('%s pada %s ...', label, app.FileName));
try
    out = applySegmentationMethod(app.Original, method, params);
catch ex
    close(dlg);
    uialert(app.Figure, sprintf('%s\n\nPerbaiki parameter lalu tekan Proses lagi.', ...
        ex.message), 'Segmentasi gagal');
    return;
end
close(dlg);

app.Result = out;
app.Method = method;
showResult(app);

app.TabGroup.SelectedTab = app.ResultTab;
end

function onSave(app)
if isempty(app.Result), return; end

outDir = fullfile(app.RootFolder, 'results', 'gui');
if ~isfolder(outDir)
    mkdir(outDir);
end
[~, base] = fileparts(app.FileName);
suffix = app.Method;
if strcmp(app.Method, 'edge')
    suffix = ['edge_' app.EdgeOperator.Value];
end
path = fullfile(outDir, sprintf('%s_%s.png', base, suffix));

% gambar ulang ke figure tersembunyi supaya PNG bersih tanpa kontrol GUI
fig = figure('Visible', 'off', 'Position', [0 0 1500 420], 'Theme', 'light');
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('%s - %s', app.FileName, app.Result.methodName), ...
    'Interpreter', 'none', 'FontWeight', 'bold');
for k = 1:4
    ax = nexttile(tl);
    drawView(ax, app.Result.views(k), app.Result.legend);
    t = title(ax, app.Result.views(k).title);
    t.Visible = 'on';   % axes legenda disembunyikan, judulnya tetap tampil
end
try
    exportgraphics(fig, path, 'Resolution', 120);
    close(fig);
catch ex
    close(fig);
    uialert(app.Figure, sprintf('Gagal menyimpan:\n%s', ex.message), 'Simpan hasil');
    return;
end
uialert(app.Figure, sprintf('Tersimpan di:\n%s', path), 'Simpan hasil', 'Icon', 'success');
end

function onCopyAxes(app, ax)
% salin isi axes ke clipboard sebagai gambar
try
    copygraphics(ax, 'ContentType', 'image', 'Resolution', 300);
catch ex
    uialert(app.Figure, sprintf('Gagal menyalin gambar:\n%s', ex.message), 'Salin gambar');
end
end

% ===========================================================================
% Pembacaan input & penyegaran tampilan
% ===========================================================================

function [method, params] = collectInputs(app)
% method dan params sesuai daftar field di applySegmentationMethod.m
method = app.MethodBox.Value;

switch method
    case 'edge'
        params = struct( ...
            'Operator',       app.EdgeOperator.Value, ...
            'Sigma',          app.EdgeSigma.Value, ...
            'LogSigma',       app.EdgeLogSigma.Value, ...
            'ThresholdMode',  app.EdgeThrMode.Value, ...
            'Percentile',     app.EdgePercentile.Value, ...
            'Threshold',      app.EdgeT.Value, ...
            'MinEdgeLength',  app.EdgeMinLength.Value, ...
            'CloseRadius',    app.EdgeCloseR.Value, ...
            'MaxCloseRadius', app.EdgeMaxCloseR.Value);

    case 'splitmerge'
        params = struct( ...
            'Predicate',      app.SmPredicate.Value, ...
            'SplitThreshold', app.SmSplitT.Value, ...
            'MergeThreshold', app.SmMergeT.Value, ...
            'MinBlockSize',   app.SmMinBlock.Value);

    case 'semantic'
        params = struct( ...
            'PythonExe', app.SemPython.Value, ...
            'ModelPath', app.SemModel.Value);
end
end

function showResult(app)
% tab Hasil, tab Tahapan, dan log sesuai app.Result

if isempty(app.Result)
    % belum diproses: panel 1 citra asli, sisanya kosong
    for k = 1:4
        app.ViewPanels(k).Title = '';
        drawView(app.ViewAxes(k), struct('title', '', 'image', []), []);
    end
    app.ViewPanels(1).Title = 'CITRA ASLI';
    drawImage(app.ViewAxes(1), app.Original);
    showSteps(app, []);
    app.SaveButton.Enable = 'off';
    showLog(app);
    return;
end

views = app.Result.views;
for k = 1:4
    app.ViewPanels(k).Title = upper(views(k).title);
    drawView(app.ViewAxes(k), views(k), app.Result.legend);
end
showSteps(app, app.Result.steps);
app.SaveButton.Enable = 'on';
showLog(app);
end

function showSteps(app, steps)
% tahapan hanya ada untuk deteksi tepi; metode lain mengosongkan tab
for k = 1:numel(app.StepPanels)
    if k <= numel(steps)
        app.StepPanels(k).Title = upper(steps(k).title);
        drawImage(app.StepAxes(k), steps(k).image);
    else
        app.StepPanels(k).Title = sprintf('TAHAP %d', k);
        drawImage(app.StepAxes(k), []);
    end
end
if isempty(steps)
    app.StepPanels(1).Title = 'PROSES DETEKSI TEPI DULU';
end
end

function showLog(app)
if isempty(app.Original)
    app.LogText.Value = {'Muat citra dulu, pilih metode, lalu tekan Proses.'};
    return;
end
lines = {sprintf('Citra   : %s (%dx%d)', app.FileName, size(app.Original, 2), size(app.Original, 1))};
if isempty(app.Result)
    lines{end + 1} = 'Belum diproses. Pilih metode lalu tekan Proses.';
else
    r = app.Result;
    lines = [lines, { ...
        sprintf('Metode  : %s', r.methodName), ...
        sprintf('Param   : %s', r.paramText), ...
        sprintf('Waktu   : %.2f detik', r.elapsed), ...
        'Hasil   :'}, strcat({'  '}, r.summary)];
end
app.LogText.Value = lines;
end

function drawView(ax, view, legend)
% satu panel hasil: citra, atau legenda kelas kalau .image kosong
if isempty(view.image) && ~isempty(legend)
    drawLegend(ax, legend);
else
    drawImage(ax, view.image);
end
end

function drawImage(ax, img)
% tampilkan citra; [] mengosongkan axes
cla(ax);
ax.Visible = 'off';
if isempty(img)
    return;
end
h = imshow(img, 'Parent', ax);
h.ContextMenu = ax.ContextMenu;     % klik kanan di citra tetap memunculkan menu salin
end

function drawLegend(ax, legend)
% kotak warna + nama kelas + persentase piksel
cla(ax);
% axes yang sebelumnya dipakai imshow masih bersumbu y terbalik dan
% berasio aspek citra, jadi dikembalikan ke sumbu biasa
axis(ax, 'normal');
ax.YDir = 'normal';
n = numel(legend.names);
hold(ax, 'on');
for k = 1:n
    y = n + 1 - k;
    rectangle(ax, 'Position', [0.05 y - 0.4 0.12 0.8], ...
        'FaceColor', legend.colors(k, :), 'EdgeColor', 'k');
    text(ax, 0.22, y, sprintf('%-10s %5.1f%%', legend.names{k}, 100 * legend.ratio(k)), ...
        'FontName', 'Consolas', 'FontSize', 10, 'Interpreter', 'none');
end
hold(ax, 'off');
axis(ax, [0 1 0.4 n + 0.6]);
ax.Visible = 'off';
end

function s = onOff(flag)
if flag, s = 'on'; else, s = 'off'; end
end
