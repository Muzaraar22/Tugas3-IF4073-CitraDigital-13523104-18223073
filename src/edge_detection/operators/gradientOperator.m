function [mag, gx, gy] = gradientOperator(G, Kx, Ky, magType)
% hitung gradien citra dengan sepasang mask turunan pertama.
% inti bersama Sobel, Prewitt, dan Roberts (yang beda cuma mask-nya)
%
% INPUT:
%   G       - citra grayscale double
%   Kx      - mask turunan arah x
%   Ky      - mask turunan arah y
%   magType - (opsional) cara hitung kekuatan tepi, default 'euclidean':
%               'euclidean' -> sqrt(Gx^2 + Gy^2)
%               'abs'       -> |Gx| + |Gy|        (hampiran, lebih cepat)
%               'max'       -> max(|Gx|, |Gy|)
%
% OUTPUT:
%   mag - kekuatan tepi (magnitudo gradien)
%   gx  - hasil konvolusi citra dengan Kx
%   gy  - hasil konvolusi citra dengan Ky

if nargin < 4 || isempty(magType)
    magType = 'euclidean';
end

gx = convolve2D(G, Kx);
gy = convolve2D(G, Ky);

switch lower(magType)
    case 'euclidean'
        mag = sqrt(gx.^2 + gy.^2);
    case 'abs'
        mag = abs(gx) + abs(gy);
    case 'max'
        mag = max(abs(gx), abs(gy));
    otherwise
        error('gradientOperator:unknownMagType', ...
            'magType harus ''euclidean'', ''abs'', atau ''max'', bukan "%s"', magType);
end
end