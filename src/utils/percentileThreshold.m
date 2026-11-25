function T = percentileThreshold(V, P)
% nilai persentil ke-P dari data V (tanpa Statistics Toolbox)
% P% data bernilai <= T, jadi V > T menyisakan (100 - P)% data teratas
%
% INPUT:
%   V - data (vektor / matriks)
%   P - persentil, 0 < P < 100
%
% OUTPUT:
%   T - nilai ambang (0 kalau V kosong)

V = sort(V(:));
n = numel(V);
if n == 0
    T = 0;
    return;
end
k = min(max(ceil(P / 100 * n), 1), n);
T = V(k);
end
