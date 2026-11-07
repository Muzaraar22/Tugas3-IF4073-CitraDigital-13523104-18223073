function [mag, gx, gy, theta] = robertsOperator(G, magType)
% operator gradien silang Roberts (mask 2x2)
%
%   R+ = [1 0; 0 -1]     R- = [0 1; -1 0]
%
% dengan conv2 (y citra ke bawah) kedua mask ini menghitung:
% R+(x,y) = f(x+1, y+1) - f(x, y)     -> turunan arah diagonal 45 derajat
% R-(x,y) = f(x, y+1)   - f(x+1, y)   -> turunan arah diagonal 135 derajat
%
% mask kecil -> lokasi tepi tajam, tapi paling peka terhadap derau
% INPUT:
%   G       - citra grayscale double
%   magType - (opsional) lihat gradientOperator.m, default 'euclidean'
%
% OUTPUT:
%   mag   - kekuatan tepi
%   gx    - R+
%   gy    - R-
%   theta - arah gradien (radian), koordinat citra: x ke kanan, y ke bawah


if nargin < 2
    magType = 'euclidean';
    % uh ini di slide deteksi tepi bagian 2, page 14 pake absolute, tapi di
    % page 16 codenya euclidian????
end

Rx = [1 0; 0 -1];
Ry = [0 1; -1 0];

[mag, gx, gy] = gradientOperator(G, Rx, Ry, magType);

theta = pi/4 + atan2(gy, gx);
theta = mod(theta + pi, 2*pi) - pi;   % rentang [-pi, pi)
end