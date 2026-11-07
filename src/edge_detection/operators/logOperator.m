function [R, H] = logOperator(G, sigma, n)
% operator Laplacian of Gaussian (LoG) pada citra G.
%
% citra langsung dikonvolusi dengan 1 mask LoG, Laplace(f * G) = f * Laplace(G)
%
% sigma besar -> cuma tepi skala besar yang muncul (lebih tahan derau)
% sigma kecil -> detail halus ikut muncul
%
% INPUT:
%   G     - citra grayscale double
%   sigma - (opsional) standar deviasi Gaussian, default 2
%   n     - (opsional) ukuran mask, [] -> otomatis (logKernel.m)
%
% OUTPUT:
%   R - respon LoG, ukuran sama dengan G (nilai bisa + / -)
%   H - mask LoG yang dipakai

if nargin < 2 || isempty(sigma)
    sigma = 2;
end
if nargin < 3
    n = [];
end

H = logKernel(sigma, n);
R = convolve2D(G, H);
end
