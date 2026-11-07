function BW = zeroCrossing(R, t)
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
%   t - ambang "kecuraman": zero-crossing baru dihitung tepi kalau selisih
%       nilai kedua sisinya > t. tanpa ini derau kecil di daerah homogen
%       juga menghasilkan zero-crossing (tepi)
%
% OUTPUT:
%   BW - citra tepi biner (logical), ukuran sama dengan R

[M, N] = size(R);
BW = false(M, N);

% kasus 1, arah horizontal: pasangan kolom j dan j+1
a = R(:, 1:end-1);
b = R(:, 2:end);
z = (a .* b < 0) & (abs(a - b) > t);   % beda tanda + cukup curam
markA = z & (abs(a) <= abs(b));        % kiri lebih dekat ke 0
markB = z & ~markA;                    % kanan lebih dekat ke 0
BW(:, 1:end-1) = BW(:, 1:end-1) | markA;
BW(:, 2:end)   = BW(:, 2:end)   | markB;

% kasus 1, arah vertikal: pasangan baris i dan i+1
a = R(1:end-1, :);
b = R(2:end, :);
z = (a .* b < 0) & (abs(a - b) > t);
markA = z & (abs(a) <= abs(b));
markB = z & ~markA;
BW(1:end-1, :) = BW(1:end-1, :) | markA;
BW(2:end, :)   = BW(2:end, :)   | markB;

% kasus 2: piksel 0 diapit tetangga yang beda tanda
% (jaraknya 2 piksel, jadi ambangnya 2t).
% kiri-kanan dan atas-bawah dicek terpisah supaya baris/kolom pinggir
% tetap ikut dicek (cukup butuh 2 tetangga, bukan 4)

% kiri-kanan: semua baris, kolom 2..N-1
c = R(:, 2:end-1);
l = R(:, 1:end-2);   r = R(:, 3:end);
z0 = (c == 0) & (l .* r < 0) & (abs(l - r) > 2 * t);
BW(:, 2:end-1) = BW(:, 2:end-1) | z0;

% atas-bawah: semua kolom, baris 2..M-1
c = R(2:end-1, :);
u = R(1:end-2, :);   d = R(3:end, :);
z0 = (c == 0) & (u .* d < 0) & (abs(u - d) > 2 * t);
BW(2:end-1, :) = BW(2:end-1, :) | z0;
end
