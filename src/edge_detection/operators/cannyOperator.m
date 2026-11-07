function [BW, thresh] = cannyOperator(G, thresh, sigma)
% deteksi tepi Canny pakai fungsi built-in MATLAB
%
% tahapan Canny: pelembutan Gaussian -> gradien -> non-maximum suppression
% (tepi setebal 1 piksel) -> ambang ganda + hysteresis
%
% INPUT:
%   G      - citra grayscale double
%   thresh - (opsional) [] = otomatis, skalar T_high, atau [T_low T_high]
%            skala 0..1
%   sigma  - (opsional) standar deviasi Gaussian, default sqrt(2)
%
% OUTPUT:
%   BW     - citra tepi biner (logical)
%   thresh - [T_low T_high] yang dipakai

if nargin < 2
    thresh = [];
end
if nargin < 3 || isempty(sigma)
    sigma = sqrt(2);
end

[BW, thresh] = edge(G, 'canny', thresh, sigma);
end
