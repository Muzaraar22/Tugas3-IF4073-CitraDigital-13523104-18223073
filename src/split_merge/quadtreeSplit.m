function [splitLabel, numRegions] = quadtreeSplit(Img, splitTh, minSize, predType)
% membagi citra menjadi region disjoint (quadtree)
%
% INPUT:
%   Img         - citra grayscale (double 0..1)
%   splitTh     - threshold homogenitas untuk proses split
%   minSize     - ukuran blok minimum agar pembelahan berhenti
%   predType    - jenis predikat (std atau range)
%
% OUTPUT:
%   splitLabel  - matriks label integer (1..numRegions) hasil fase split
%   numRegions  - jumlah total region leaf yang terbentuk

    [H, W] = size(Img);
    splitLabel = zeros(H, W, 'uint32');
    nextId = uint32(1);

    splitRecursive(1, H, 1, W);
    numRegions = double(nextId - 1);

    function splitRecursive(r1, r2, c1, c2)
        h = r2 - r1 + 1;
        w = c2 - c1 + 1;
        patch = Img(r1:r2, c1:c2);

        if h <= minSize || w <= minSize || isHomogeneous(patch, splitTh, predType)
            splitLabel(r1:r2, c1:c2) = nextId;
            nextId = nextId + 1;
            return;
        end

        rm = floor((r1 + r2) / 2);
        cm = floor((c1 + c2) / 2);

        splitRecursive(r1, rm, c1, cm);
        if cm < c2
            splitRecursive(r1, rm, cm + 1, c2);
        end
        if rm < r2
            splitRecursive(rm + 1, r2, c1, cm);
        end
        if rm < r2 && cm < c2
            splitRecursive(rm + 1, r2, cm + 1, c2);
        end
    end
end
