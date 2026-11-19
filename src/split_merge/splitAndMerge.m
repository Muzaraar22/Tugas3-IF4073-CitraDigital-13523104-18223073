function [mergeLabel, splitLabel, info] = splitAndMerge(I, params)
% Segmentasi citra klasik dengan algoritma Split and Merge.
%
% INPUT:
%   I      - citra masukan (RGB / grayscale)
%   params - (opsional) struct parameter:
%            .Threshold      - threshold homogenitas T untuk split & merge (default 0.08)
%            .SplitThreshold - (opsional) override T khusus fase split
%            .MergeThreshold - (opsional) override T khusus fase merge
%            .MinBlockSize   - ukuran blok minimum Quadtree (piksel)      (default 4)
%            .Predicate      - 'range' (sesuai Slide 6) atau 'std'         (default 'std')
%            .Normalize      - true: konversi ke double 0..1               (default true)
%
% OUTPUT:
%   mergeLabel - matriks label integer hasil akhir segmentasi (after merge)
%   splitLabel - matriks label integer hasil fase pembelahan (after split)
%   info       - struct berisi visualisasi RGB & metrik statistik

    if nargin < 2
        params = struct();
    end

    baseThresh  = getFieldOrDefault(params, 'Threshold', 0.08);
    splitThresh = getFieldOrDefault(params, 'SplitThreshold', baseThresh);
    mergeThresh = getFieldOrDefault(params, 'MergeThreshold', baseThresh);
    minSize     = getFieldOrDefault(params, 'MinBlockSize', 4);
    predType    = getFieldOrDefault(params, 'Predicate', 'std');
    doNorm      = getFieldOrDefault(params, 'Normalize', true);

    if size(I, 3) == 3
        I_gray = rgb2gray(I);
    else
        I_gray = I;
    end

    if doNorm
        G = im2double(I_gray);
    else
        G = double(I_gray);
    end

    tStart = tic;

    % Langkah 1 & 2 (Slide 4): Bagi citra menjadi kuadran disjoint hingga Q(Ri) = TRUE
    [splitLabel, numSplit] = quadtreeSplit(G, splitThresh, minSize, predType);

    % Langkah 3 & 4 (Slide 4): Gabung region bertetangga hingga Q(Ri U Rj) = FALSE
    [mergeLabel, numMerge] = mergeRegions(G, splitLabel, mergeThresh, predType);

    elapsed = toc(tStart);

    info.numSplitRegions = numSplit;
    info.numMergeRegions = numMerge;
    info.executionTime   = elapsed;
    info.params          = struct('SplitThreshold', splitThresh, ...
                                  'MergeThreshold', mergeThresh, ...
                                  'MinBlockSize', minSize, ...
                                  'Predicate', predType);

    % Visualisasi warna tanpa ketergantungan Image Processing Toolbox
    info.splitRGB      = labelsToRGB(splitLabel, numSplit);
    info.mergeRGB      = labelsToRGB(mergeLabel, numMerge);
    info.reconstructed = reconstructImage(im2double(I), mergeLabel, numMerge);
end

function rgb = labelsToRGB(labelMap, numRegions)
    % Memetakan setiap label region ke warna kontras menggunakan golden-ratio hue
    if numRegions <= 0
        rgb = zeros([size(labelMap), 3], 'uint8');
        return;
    end

    idxList = (0:numRegions - 1)';
    hues = mod(idxList * 0.618033988749895, 1);
    sats = 0.75 + 0.25 * mod(idxList, 2);
    vals = 0.85 + 0.15 * mod(floor(idxList / 2), 2);
    cmap = uint8(round(hsv2rgb([hues, sats, vals]) * 255));

    [H, W] = size(labelMap);
    rgb = reshape(cmap(labelMap(:), :), H, W, 3);
end

function out = reconstructImage(I_dbl, labelMap, numRegions)
    [H, W, C] = size(I_dbl);
    out = zeros(H, W, C);
    idx = labelMap(:);
    for c = 1:C
        channel = I_dbl(:, :, c);
        meanPerRegion = accumarray(idx, channel(:), [numRegions, 1], @mean);
        out(:, :, c) = reshape(meanPerRegion(idx), H, W);
    end
end