function R = laplaceOperator(G, variant)
% operator Laplace (turunan kedua) pada citra G.
% lokasi tepi ada di zero-crossing R (zeroCrossing.m)
%
% INPUT:
%   G       - citra grayscale double
%   variant - (opsional) jenis mask, default '4':
%               '4'        -> [0 1 0; 1 -4 1; 0 1 0]   (diferensial mundur)
%               '8'        -> [1 1 1; 1 -8 1; 1 1 1]   (ikut arah diagonal)
%               'weighted' -> [1 4 1; 4 -20 4; 1 4 1]  (bobot lebih di tengah)
%
% OUTPUT:
%   R - respon Laplace, ukuran sama dengan G

if nargin < 2 || isempty(variant)
    variant = '4';
end
if isnumeric(variant)
    variant = num2str(variant);
end

switch lower(variant)
    case '4'
        H = [0 1 0; 1 -4 1; 0 1 0];
    case '8'
        H = [1 1 1; 1 -8 1; 1 1 1];
    case 'weighted'
        H = [1 4 1; 4 -20 4; 1 4 1];
    otherwise
        error('laplaceOperator:unknownVariant', ...
            'variant harus ''4'', ''8'', atau ''weighted'', bukan "%s"', variant);
end

R = convolve2D(G, H);
end
