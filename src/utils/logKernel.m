function H = logKernel(sigma, n)
% membuat mask Laplacian of Gaussian (LoG) ukuran n x n
%
% LoG(x,y) = ((x^2 + y^2 - 2*sigma^2) / sigma^4) * exp(-(x^2 + y^2) / (2*sigma^2))
%
% INPUT:
%   sigma - standar deviasi Gaussian
%   n     - (opsional) ukuran mask, default 2*ceil(3*sigma)+1
%
% OUTPUT:
%   H - mask LoG, jumlah koefisiennya = 0

if nargin < 2 || isempty(n)
    n = 2 * ceil(3 * sigma) + 1;
end

half = (n - 1) / 2;
[x, y] = meshgrid(-half:half, -half:half);
r2 = x.^2 + y.^2;

H = ((r2 - 2 * sigma^2) / sigma^4) .* exp(-r2 / (2 * sigma^2));

% LoG itu operator turunan kedua: jumlah koefisien harus 0 (daerah
% homogen responnya 0). karena kurvanya dipotong ke n x n jumlahnya
% tidak pas 0, jadi dikoreksi dengan dikurangi rata-ratanya
H = H - mean(H(:));
end
