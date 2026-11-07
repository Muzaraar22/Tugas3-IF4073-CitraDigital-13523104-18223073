% bandingkan tahapan segmentFromEdges antara LoG dan Canny, side by side
% kasus: lingkaran sintetis + derau (LoG IoU tinggi, Canny gagal)
%
% output:
%   - figure "Tahapan LoG vs Canny": 1 baris per operator
%       tepi | fragmen dibuang | closing | fill | opening | objek | overlay
%   - angka per tahap di command window (jumlah fragmen, luas region, dll.)
%   - sweep MinEdgeLength untuk Canny: apakah gagalnya karena default 30?

clear; clc; close all;
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(rootDir, 'src')));

% citra uji sama persis dengan test_edge_segmentation.m
rng(0);
[X, Y] = meshgrid(1:320, 1:240);
gt  = (X - 170).^2 + (Y - 115).^2 <= 70^2;
img = 0.25 + 0.5 * gt + 0.04 * randn(size(gt));
img = min(max(img, 0), 1);

methods = {'log', 'canny'};
params  = struct();   % default semua

%% tahapan side by side
figure('Name', 'Tahapan LoG vs Canny', 'Position', [30 80 1700 480], 'Theme', 'light');
tiledlayout(numel(methods), 7, 'TileSpacing', 'compact', 'Padding', 'compact');

for k = 1:numel(methods)
    res = edgeSegmentation(img, methods{k}, params);
    s   = res.steps;
    iou = nnz(res.mask & gt) / nnz(res.mask | gt);
    M   = upper(methods{k});

    nexttile; imshow(res.edges);     title(sprintf('%s 1. tepi', M));
    nexttile; imshow(s.cleaned);     title('2. fragmen < 30 dibuang');
    nexttile; imshow(s.closed);      title(sprintf('3. closing r = %d', s.radius));
    nexttile; imshow(s.filled);      title('4. fill holes');
    nexttile; imshow(s.opened);      title('5. opening');
    nexttile; imshow(res.mask);      title(sprintf('6. objek, IoU %.3f', iou));
    nexttile; imshow(res.overlay);   title('7. overlay');

    % angka per tahap
    fprintf('===== %s =====\n', M);
    fprintf('piksel tepi            : %d (%.1f%%)\n', nnz(res.edges), 100 * mean(res.edges(:)));
    describeFragments('fragmen tepi (awal)   ', res.edges);
    describeFragments('fragmen setelah clean ', s.cleaned);
    describeRegions('region setelah opening', s.opened, gt);
    fprintf('radius closing dipakai : %d\n', s.radius);
    fprintf('IoU objek              : %.3f\n\n', iou);
end

%% apakah karena MinEdgeLength / CloseRadius? coba beberapa nilai untuk Canny
fprintf('===== sweep parameter Canny =====\n');
fprintf('%-14s %-12s %-8s %s\n', 'MinEdgeLength', 'CloseRadius', 'r akhir', 'IoU');
for minLen = [10 30 60 100]
    for r0 = [3 5 7]
        p = struct('MinEdgeLength', minLen, 'CloseRadius', r0);
        res = edgeSegmentation(img, 'canny', p);
        iou = nnz(res.mask & gt) / nnz(res.mask | gt);
        fprintf('%-14d %-12d %-8d %.3f\n', minLen, r0, res.steps.radius, iou);
    end
end

%% atau karena threshold Canny? panggil cannyOperator langsung
% thresh [] = otomatis MATLAB: T_high = persentil 70 magnitudo gradien,
% artinya ~30% piksel SELALU jadi kandidat tepi, apa pun isi citranya
fprintf('\n===== sweep threshold Canny (segmentasi pakai default) =====\n');
fprintf('%-14s %-8s %-10s %s\n', 'thresh', 'sigma', 'tepi', 'IoU');
G = img;
for thr = {[], 0.1, 0.2, 0.3}
    for sigma = [sqrt(2) 3]
        [E, T] = cannyOperator(G, thr{1}, sigma);
        mask = segmentFromEdges(E);
        iou = nnz(mask & gt) / nnz(mask | gt);
        fprintf('%-14s %-8.2f %5.1f%%     %.3f\n', mat2str(T, 3), sigma, 100 * mean(E(:)), iou);
    end
end


%% ---- fungsi lokal

% jumlah & panjang fragmen tepi (komponen terhubung-8)
function describeFragments(label, BW)
CC = bwconncomp(BW, 8);
len = cellfun(@numel, CC.PixelIdxList);
if isempty(len)
    fprintf('%s : 0 fragmen\n', label);
else
    fprintf('%s : %d fragmen, terpanjang %d px, median %d px\n', ...
        label, CC.NumObjects, max(len), round(median(len)));
end
end

% region yang tersisa setelah opening: luas (% citra) dan IoU tiap region
function describeRegions(label, BW, gt)
CC = bwconncomp(BW, 8);
fprintf('%s : %d region\n', label, CC.NumObjects);
for i = 1:CC.NumObjects
    R = false(size(BW));
    R(CC.PixelIdxList{i}) = true;
    fprintf('    region %d: luas %5.1f%%, IoU vs ground truth %.3f\n', ...
        i, 100 * mean(R(:)), nnz(R & gt) / nnz(R | gt));
end
end
