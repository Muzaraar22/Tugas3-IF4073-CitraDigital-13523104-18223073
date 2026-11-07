function J = convolve2D(I, H)
% konvolusi 2D citra I dengan mask H, ukuran output = ukuran I
%
% INPUT:
%   I - citra grayscale double
%   H - mask konvolusi, boleh ukuran genap (mis. Roberts 2x2)
%
% OUTPUT:
%   J - hasil konvolusi, ukuran sama dengan I

[kh, kw] = size(H);
[M, N]   = size(I);

% banyak piksel padding atas/bawah dan kiri/kanan
% (mask genap -> padding atas/kiri lebih banyak 1)
padTop  = floor(kh / 2);  padBottom = kh - 1 - padTop;
padLeft = floor(kw / 2);  padRight  = kw - 1 - padLeft;

% indeks di luar [1, M] / [1, N] di-replicate
rowIdx = min(max((1 - padTop):(M + padBottom), 1), M);
colIdx = min(max((1 - padLeft):(N + padRight), 1), N);
P = I(rowIdx, colIdx);

% 'valid' pada citra yang sudah di-pad -> ukurannya pas M x N
J = conv2(P, double(H), 'valid');
end
