function result = semanticSegmentation(I, params)
% segmentasi semantik 1 citra dengan model CNN hasil fine-tuning CamVid.
% inferensi dijalankan di Python (camvid_predict.py) lewat system(),
% hasilnya (kelas tiap piksel) dibaca balik lalu divisualisasikan di MATLAB
%
% INPUT:
%   I      - citra masukan RGB / grayscale
%   params - (opsional) struct:
%     .PythonExe - python yang sudah terpasang torch & torchvision (default 'python')
%     .ModelPath - file model .pth (default <folder ini>/model/camvid_deeplabv3_mbv3.pth)
%
% OUTPUT:
%   result - struct:
%     .original   - citra masukan
%     .labels     - kelas tiap piksel (uint8), 1..11 sesuai urutan classNames
%     .classNames - nama 11 kelas
%     .colormap   - warna tiap kelas (11 x 3, nilai 0..1)
%     .colorLabel - label berwarna (RGB)
%     .overlay    - citra asli ditimpa label berwarna (transparan)
%     .classRatio - fraksi piksel tiap kelas (11 x 1)
%     .elapsed    - waktu proses (detik), termasuk memuat model di Python

if nargin < 2
    params = struct();
end

thisDir    = fileparts(mfilename('fullpath'));
scriptPath = fullfile(thisDir, 'camvid_predict.py');
pythonExe  = getFieldOrDefault(params, 'PythonExe', 'python');
modelPath  = getFieldOrDefault(params, 'ModelPath', ...
                 fullfile(thisDir, 'model', 'camvid_deeplabv3_mbv3.pth'));

if ~isfile(modelPath)
    error('semanticSegmentation:noModel', ...
        'model tidak ditemukan: %s (download hasil training dari Kaggle dulu)', modelPath);
end

tStart = tic;

% python jalan sebagai proses terpisah, jadi citra dioper lewat file sementara
inPath  = [tempname '.png'];
outPath = [tempname '.png'];
cleanup = onCleanup(@() deleteIfExists({inPath, outPath}));   % tetap dihapus walau error
imwrite(I, inPath);

cmd = sprintf('"%s" "%s" --model "%s" --image "%s" --out "%s"', ...
              pythonExe, scriptPath, modelPath, inPath, outPath);
if ispc
    % di Windows, perintah yang diawali tanda kutip harus dibungkus 1 pasang kutip lagi
    % (cmd.exe membuang kutip pertama & terakhir)
    cmd = ['"' cmd '"'];
end

[status, cmdout] = system(cmd);
if status ~= 0
    error('semanticSegmentation:python', 'python gagal (status %d):\n%s', status, cmdout);
end

% python menulis indeks 0..10, di MATLAB digeser jadi 1..11
% (label 0 dianggap "tanpa kelas" oleh label2rgb / labeloverlay)
labels = imread(outPath) + 1;
[classNames, cmap] = camvidClasses();

result.original   = I;
result.labels     = labels;
result.classNames = classNames;
result.colormap   = cmap;
result.colorLabel = label2rgb(labels, cmap);
result.overlay    = labeloverlay(I, labels, 'Colormap', cmap, 'Transparency', 0.4);
result.classRatio = accumarray(double(labels(:)), 1, [numel(classNames) 1]) / numel(labels);
result.elapsed    = toc(tStart);
end


% 11 kelas + warnanya. urutan HARUS sama dengan CLASS_NAMES / PALETTE di camvid_train.ipynb
function [names, cmap] = camvidClasses()
names = {'Sky', 'Building', 'Pole', 'Road', 'Pavement', 'Tree', ...
         'SignSymbol', 'Fence', 'Car', 'Pedestrian', 'Bicyclist'};
cmap = [128 128 128;   % Sky
        128   0   0;   % Building
        192 192 192;   % Pole
        128  64 128;   % Road
         60  40 222;   % Pavement
        128 128   0;   % Tree
        192 128 128;   % SignSymbol
         64  64 128;   % Fence
         64   0 128;   % Car
         64  64   0;   % Pedestrian
          0 128 192] / 255;   % Bicyclist
end


% hapus file sementara kalau ada
function deleteIfExists(paths)
for k = 1:numel(paths)
    if isfile(paths{k})
        delete(paths{k});
    end
end
end
