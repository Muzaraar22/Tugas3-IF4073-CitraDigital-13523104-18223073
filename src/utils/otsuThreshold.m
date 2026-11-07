function T = otsuThreshold(V, nbins)
% cari nilai ambang dengan metode Otsu
% dipakai untuk memilih ambang pada histogram magnitudo gradien
%
% Otsu memilih ambang k yang memaksimalkan varians antar-kelas:
%   sigmaB^2(k) = (muT * w(k) - mu(k))^2 / (w(k) * (1 - w(k)))
%   w(k)  - peluang kumulatif kelas 0 (piksel <= k)
%   mu(k) - rata-rata kumulatif sampai k
%   muT   - rata-rata seluruh piksel
%
% INPUT:
%   V     - data dengan rentang [0, 1] (mis. magnitudo ternormalisasi)
%   nbins - (opsional) banyak bin histogram, default 256
%
% OUTPUT:
%   T - nilai ambang, skala [0, 1]

if nargin < 2 || isempty(nbins)
    nbins = 256;
end

V = V(:);
V = min(max(V, 0), 1);

% histogram: tiap nilai dipetakan ke bin 1..nbins
idx    = floor(V * (nbins - 1)) + 1;
counts = accumarray(idx, 1, [nbins 1]);
p      = counts / sum(counts);       % peluang tiap bin

levels = (0:nbins - 1)';
w      = cumsum(p);                  % bobot kelas 0
mu     = cumsum(p .* levels);        % rata-rata kumulatif
muT    = mu(end);                    % rata-rata total

sigmaB2 = (muT * w - mu).^2 ./ (w .* (1 - w));
sigmaB2(~isfinite(sigmaB2)) = 0;     % ujung histogram (w = 0 / 1) -> bagi 0

[~, k] = max(sigmaB2);
T = (k - 1) / (nbins - 1);           % balik ke skala [0, 1]
end
