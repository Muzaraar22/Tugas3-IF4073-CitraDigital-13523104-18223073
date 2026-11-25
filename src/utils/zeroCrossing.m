function [BW, S] = zeroCrossing(R, t)
% cari persilangan nol (zero-crossing) dari respon turunan kedua
% (Laplace / LoG). lokasi tepi = tempat tanda R berubah + <-> -
%
% ada 2 kasus (slide Bagian 1):
%   1) tepi curam  : 2 piksel bertetangga beda tanda, mis. 4 | -4
%   2) tepi landai : piksel bernilai 0 diapit tetangga beda tanda,
%                    mis. 3 | 0 | -3
%
% INPUT:
%   R - respon konvolusi dengan mask Laplace / LoG
%   t - (opsional) ambang "kecuraman": zero-crossing baru dihitung tepi
%       kalau kecuramannya > t. tanpa ini derau kecil di daerah homogen
%       juga menghasilkan zero-crossing (tepi). default 0
%
% OUTPUT:
%   BW - citra tepi biner (logical), ukuran sama dengan R, BW = S > t
%   S  - kecuraman tiap zero-crossing, 0 untuk piksel yang bukan crossing:
%          kasus 1: |a - b|      (selisih kedua piksel bertetangga)
%          kasus 2: |l - r| / 2  (jarak kedua tetangga 2 piksel)
%        dipakai detectEdges.m untuk memilih ambang (Otsu / persentil)

if nargin < 2
    t = 0;
end

[M, N] = size(R);
S = zeros(M, N);

% kasus 1, arah horizontal: pasangan kolom j dan j+1.
% kecuramannya ditaruh di piksel yang lebih dekat ke 0
a = R(:, 1:end-1);
b = R(:, 2:end);
s = abs(a - b) .* (a .* b < 0);        % 0 kalau tidak beda tanda
nearA = abs(a) <= abs(b);
S(:, 1:end-1) = max(S(:, 1:end-1), s .* nearA);
S(:, 2:end)   = max(S(:, 2:end),   s .* ~nearA);

% kasus 1, arah vertikal: pasangan baris i dan i+1
a = R(1:end-1, :);
b = R(2:end, :);
s = abs(a - b) .* (a .* b < 0);
nearA = abs(a) <= abs(b);
S(1:end-1, :) = max(S(1:end-1, :), s .* nearA);
S(2:end, :)   = max(S(2:end, :),   s .* ~nearA);

% kasus 2: piksel 0 diapit tetangga yang beda tanda.
% kiri-kanan dan atas-bawah dicek terpisah supaya baris/kolom pinggir
% tetap ikut dicek (cukup butuh 2 tetangga, bukan 4)

% kiri-kanan: semua baris, kolom 2..N-1
c = R(:, 2:end-1);
l = R(:, 1:end-2);   r = R(:, 3:end);
s = abs(l - r) / 2 .* ((c == 0) & (l .* r < 0));
S(:, 2:end-1) = max(S(:, 2:end-1), s);

% atas-bawah: semua kolom, baris 2..M-1
c = R(2:end-1, :);
u = R(1:end-2, :);   d = R(3:end, :);
s = abs(u - d) / 2 .* ((c == 0) & (u .* d < 0));
S(2:end-1, :) = max(S(2:end-1, :), s);

BW = S > t;
end
