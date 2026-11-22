function [mask, steps] = segmentFromEdges(E, params)
% bentuk objek utama dari citra tepi biner
%
% ide dasarnya (slide Bagian 3, "Kontur"): rangkaian piksel tepi yang
% membentuk kontur TERTUTUP mengelilingi suatu region, dan isi region itu
% bisa didapat dengan pengisian (filling). hasil deteksi tepi jarang
% langsung tertutup, jadi langkahnya:
%   1. buang fragmen tepi pendek (derau/tekstur)          -> bwareaopen
%   2. sambung celah antar fragmen tepi                    -> closing disk r
%   3. isi bagian dalam kontur tertutup                    -> imfill 'holes'
%   4. buang sisa garis tepi yang tidak mengapit region    -> opening disk r
%   5. pilih region utama (lihat pickMainRegion)
%   kalau belum ada region, r diperbesar (+2) sampai MaxCloseRadius
%
% INPUT:
%   E      - citra tepi biner (logical)
%   params - (opsional) struct:
%     .MinEdgeLength  - panjang minimal fragmen tepi, piksel  (default 30)
%     .CloseRadius    - radius awal closing                    (default 3)
%     .MaxCloseRadius - radius closing maksimum                (default 15)
%
% OUTPUT:
%   mask  - objek utama (logical), kosong kalau tidak ketemu
%   steps - citra antara untuk analisis: .cleaned .closed .filled .opened,
%           dan .radius (radius closing yang akhirnya dipakai)

if nargin < 2
    params = struct();
end

minEdge = getFieldOrDefault(params, 'MinEdgeLength', 30);
r0      = getFieldOrDefault(params, 'CloseRadius', 3);
rMax    = getFieldOrDefault(params, 'MaxCloseRadius', 15);

% 1. buang komponen tepi (terhubung-8) yang lebih pendek dari minEdge
cleaned = bwareaopen(logical(E), minEdge, 8);

for r = r0:2:rMax
    se = strel('disk', r, 0);
    closed = imclose(cleaned, se);         % 2. celah < ~2r piksel tersambung
    filled = imfill(closed, 'holes');      % 3. isi region di dalam kontur tertutup
    opened = imopen(filled, se);           % 4. garis tipis hilang, region tebal tetap
    mask   = pickMainRegion(opened);       % 5.
    if any(mask(:))
        break;
    end
end

steps = struct('cleaned', cleaned, 'closed', closed, 'filled', filled, ...
               'opened', opened, 'radius', r);
end


% pilih 1 region dengan skor tertinggi:
%   skor = jumlah bobot W semua piksel region
%   W(x, y) = exp(-(x^2 + y^2) / (2 * CENTER_SIGMA^2)),  x, y = posisi -1..1
% alasannya: objek utama di foto biasanya besar dan ada di sekitar tengah.
% bobot dihitung per piksel (bukan dari centroid) supaya region latar yang
% melebar di pinggir citra tidak mendapat skor tinggi hanya karena luas.
% region yang terlalu kecil (derau) / terlalu besar (latar) diabaikan
function mask = pickMainRegion(BW)
MIN_AREA_FRAC = 0.01;
MAX_AREA_FRAC = 0.90;
CENTER_SIGMA  = 0.42;                  % makin kecil, makin mengutamakan tengah

[M, N] = size(BW);
mask  = false(M, N);
stats = regionprops(BW, 'Area', 'PixelIdxList');

[X, Y] = meshgrid(linspace(-1, 1, N), linspace(-1, 1, M));
W = exp(-(X.^2 + Y.^2) / (2 * CENTER_SIGMA^2));

bestScore = -Inf;
for i = 1:numel(stats)
    frac = stats(i).Area / (M * N);
    if frac < MIN_AREA_FRAC || frac > MAX_AREA_FRAC
        continue;
    end
    score = sum(W(stats(i).PixelIdxList));
    if score > bestScore
        bestScore = score;
        best = i;
    end
end

if bestScore > -Inf
    mask(stats(best).PixelIdxList) = true;
    mask = imfill(mask, 'holes');      % pastikan objek tidak bolong
end
end
