function H = gaussianKernel(sigma, n)
% membuat mask penapis Gaussian 2D ukuran n x n
% dipakai untuk pelembutan citra sebelum deteksi tepi
%
% INPUT:
%   sigma - standar deviasi Gaussian
%   n     - (opsional) ukuran mask, default 2*ceil(3*sigma)+1
%
% OUTPUT:
%   H - mask Gaussian, jumlah koefisiennya = 1

if nargin < 2 || isempty(n)
    n = 2 * ceil(3 * sigma) + 1;   
end

half = (n - 1) / 2;
[x, y] = meshgrid(-half:half, -half:half);

H = exp(-(x.^2 + y.^2) / (2 * sigma^2));
H = H / sum(H(:));   % normalisasi
end
