function [mergeLabel, numMerged] = mergeRegions(Img, splitLabel, mergeTh, predType)
% Menggabungkan region bertetangga jika Q(Ri U Rj) = TRUE
%
% INPUT:
%   Img         - citra grayscale (double 0..1)
%   splitLabel  - matriks label hasil tahap quadtreeSplit
%   mergeTh     - threshold T pada predikat homogenitas Q(Ri U Rj) <= T
%   predType    - range atau std
%
% OUTPUT:
%   mergeLabel  - matriks label akhir setelah tidak ada lagi region yang
%   bisa digabung
%   numMerged   - jumlah region akhir yang terbentuk

    numRegions = double(max(splitLabel(:)));
    idx = double(splitLabel(:));
    vals = Img(:);

    area = accumarray(idx, 1, [numRegions, 1]);
    sumVal = accumarray(idx, vals, [numRegions, 1]);
    sumSq = accumarray(idx, vals.^2, [numRegions, 1]);
    minVal = accumarray(idx, vals, [numRegions, 1], @min);
    maxVal = accumarray(idx, vals, [numRegions, 1], @max);

    parent = (1:numRegions)';

    merged = true;
    while merged
        merged = false;

        for k = 1:numRegions
            parent(k) = findRoot(k);
        end
        currLabel = parent(splitLabel);

        left = currLabel(:, 1:end-1);
        right = currLabel(:, 2:end);
        maskH = (left ~= right);

        top = currLabel(1:end-1, :);
        bottom = currLabel(2:end, :);
        maskV = (top ~= bottom);

        adjPairs = [left(maskH), right(maskH); top(maskV), bottom(maskV)];
        if isempty(adjPairs)
            break;
        end

        adjPairs = unique([min(adjPairs, [], 2), max(adjPairs, [], 2)], 'rows');

        scores = zeros(size(adjPairs, 1), 1);
        for p = 1:size(adjPairs, 1)
            a = adjPairs(p, 1);
            b = adjPairs(p, 2);
            scores(p) = evalUnionPredicate(a, b);
        end

        [~, order] = sort(scores, 'ascend');
        adjPairs = adjPairs(order, :);

        for p = 1:size(adjPairs, 1)
            r1 = findRoot(adjPairs(p, 1));
            r2 = findRoot(adjPairs(p, 2));
            if r1 == r2
                continue;
            end

            if evalUnionPredicate(r1, r2) <= mergeTh
                parent(r2) = r1;
                area(r1) = area(r1) + area(r2);
                sumVal(r1) = sumVal(r1) + sumVal(r2);
                sumSq(r1) = sumSq(r1) + sumSq(r2);
                minVal(r1) = min(minVal(r1), minVal(r2));
                maxVal(r1) = max(maxVal(r1), maxVal(r2));
                merged = true;
            end
        end
    end
    
    for k = 1:numRegions
        parent(k) = findRoot(k);
    end
    
    finalMap = parent(splitLabel);
    [~, ~, newIds] = unique(finalMap);
    mergeLabel = reshape(newIds, size(splitLabel));
    numMerged = max(mergeLabel(:));

    function val = evalUnionPredicate(i, j)
        switch lower(predType)
            case 'range'
                val = max(maxVal(i), maxVal(j)) - min(minVal(i), minVal(j));
            case 'std'
                n = area(i) + area(j);
                mu = (sumVal(i) + sumVal(j)) / n;
                varVal = max(0, ((sumSq(i) + sumSq(j)) / n) - mu^2);
                val = sqrt(varVal);
            otherwise
                error("Unknown Predicate %s", predType);
        end
    end

    function root = findRoot(x)
        while parent(x) ~= x
            parent(x) = parent(parent(x));
            x = parent(x);
        end
        root = x;
    end
end
