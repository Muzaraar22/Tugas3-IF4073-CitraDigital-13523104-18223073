function [mag, gx, gy, theta] = prewittOperator(G, magType)
% operator gradien Prewitt (sama seperti Sobel tapi c = 1)
%
%   Px = [-1 0 1; -1 0 1; -1 0 1]     Py = [-1 -1 -1; 0 0 0; 1 1 1]
%
% soal arah (theta):
% conv2 membalik mask 180 derajat sebelum dikalikan ke piksel, jadi
% gx = conv(f, Px) = kiri - kanan  = -df/dx
% gy = conv(f, Py) = atas - bawah  = -df/dy   (y citra ke bawah)
%
% INPUT:
%   G       - citra grayscale double
%   magType - (opsional) lihat gradientOperator.m, default 'euclidean'
%
% OUTPUT:
%   mag   - kekuatan tepi
%   gx    - hasil konvolusi dengan Px
%   gy    - hasil konvolusi dengan Py
%   theta - arah gradien (radian), koordinat citra: x ke kanan, y ke bawah

if nargin < 2
    magType = 'euclidean';
end

Px = [-1 0 1; -1 0 1; -1 0 1];
Py = [-1 -1 -1; 0 0 0; 1 1 1];

[mag, gx, gy] = gradientOperator(G, Px, Py, magType);
theta = atan2(-gy, -gx);
end