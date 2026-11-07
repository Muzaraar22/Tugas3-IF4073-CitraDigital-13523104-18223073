function [mag, gx, gy, theta] = sobelOperator(G, magType)
% operator gradien Sobel (konstanta c = 2)
%
%   Sx = [-1 0 1; -2 0 2; -1 0 1]     Sy = [1 2 1; 0 0 0; -1 -2 -1]
%
% bobot 2 di baris/kolom tengah -> piksel yang paling dekat titik pusat
% lebih berpengaruh, dan sedikit lebih tahan derau dibanding Prewitt
%
% soal arah (theta):
% conv2 membalik mask 180 derajat sebelum dikalikan ke piksel, jadi
% gx = conv(f, Sx) = kiri - kanan  = -df/dx
% gy = conv(f, Sy) = bawah - atas  = +df/dy 
%
% INPUT:
%   G       - citra grayscale double
%   magType - (opsional) lihat gradientOperator.m, default 'euclidean'
%
% OUTPUT:
%   mag   - kekuatan tepi
%   gx    - hasil konvolusi dengan Sx
%   gy    - hasil konvolusi dengan Sy
%   theta - arah gradien (radian), koordinat citra: x ke kanan, y ke bawah
%           (sudut positif = searah jarum jam di layar)

if nargin < 2
    magType = 'euclidean';
end

Sx = [-1 0 1; -2 0 2; -1 0 1];
Sy = [ 1 2 1;  0 0 0; -1 -2 -1];

[mag, gx, gy] = gradientOperator(G, Sx, Sy, magType);
theta = atan2(gy, -gx);
end