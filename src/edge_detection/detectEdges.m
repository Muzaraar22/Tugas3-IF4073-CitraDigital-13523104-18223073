function [E, info] = detectEdges(I, method, params)
% deteksi tepi dengan operator pilihan -> citra tepi biner
%
% alur yang sama untuk semua operator:
%   1. konvolusi operator -> respons (ditampilkan di GUI, belum biner)
%   2. peta kekuatan tepi S di [0, 1]:
%        Sobel/Prewitt/Roberts/Canny : magnitudo gradien / maksimum
%        Laplace/LoG                 : kecuraman zero-crossing / maksimum
%   3. ambang T dari S (Otsu / persentil / manual) -> tepi biner
%      (Canny: T = T_high, T_low = 0.4 * T_high, lalu NMS + hysteresis)
%
% INPUT:
%   I      - citra masukan (RGB / grayscale)
%   method - 'laplace' / 'log' / 'sobel' / 'prewitt' / 'roberts' / 'canny'
%   params - (opsional) struct, field yang tidak diisi pakai default:
%     .Sigma         - sigma Gaussian (opsional) sebelum Sobel/Prewitt/
%                      Roberts/Laplace, 0 = operator langsung pada citra
%                      asli tanpa pelembutan                     (default 0)
%     .LogSigma      - sigma mask LoG                            (default 2.0)
%     .ThresholdMode - 'otsu' / 'percentile' / 'manual'
%                      (default 'manual' kalau .Threshold diisi; selain itu
%                      'percentile' untuk Laplace/LoG dan 'otsu' untuk lainnya)
%     .Percentile    - mode persentil: P% kandidat terlemah dibuang
%                      (default 70 untuk Laplace/LoG, 90 untuk lainnya)
%     .Threshold     - mode manual: ambang di skala S 0..1        (default 0.2)
%
% OUTPUT:
%   E    - citra tepi biner (logical), ukuran sama dengan I
%   info - struct:
%     .response - respons operator untuk ditampilkan (double 0..1)
%     .strength - kekuatan tepi S (0..1) yang diambang; untuk Laplace/LoG
%                 bernilai 0 pada piksel yang bukan zero-crossing
%     .T        - ambang yang dipakai (skala S)
%     .modeText - keterangan ambang, mis. 'Otsu, T = 0.143'

if nargin < 3
    params = struct();
end

sigma = getFieldOrDefault(params, 'Sigma', 0);

if size(I, 3) == 3
    I = rgb2gray(I);
end
G = im2double(I);   % grayscale double 0..1

switch lower(method)
    % ---------- turunan pertama: magnitudo gradien ----------
    case {'sobel', 'prewitt', 'roberts'}
        Gs = smooth(G, sigma);   % redam derau dulu supaya tidak jadi tepi
        switch lower(method)
            case 'sobel',   mag = sobelOperator(Gs);
            case 'prewitt', mag = prewittOperator(Gs);
            case 'roberts', mag = robertsOperator(Gs);
        end

        % normalisasi ke [0, 1] supaya ambang tidak bergantung skala citra
        S = mag / max(max(mag(:)), eps);
        [T, modeText] = pickThreshold(S(:), params);
        % S > 0 supaya daerah datar tidak ikut jadi tepi kalau T = 0
        E = S >= T & S > 0;
        response = stretch(S);

    % ---------- turunan kedua: zero-crossing ----------
    case {'laplace', 'log'}
        if strcmpi(method, 'laplace')
            R = laplaceOperator(smooth(G, sigma));
        else
            R = logOperator(G, getFieldOrDefault(params, 'LogSigma', 2.0));
        end
        [~, Szc] = zeroCrossing(R);
        S = Szc / max(max(Szc(:)), eps);
        % ambang hanya dihitung dari piksel yang memang zero-crossing,
        % karena sebagian besar piksel S = 0
        % default persentil 70: Otsu pada kecuraman zero-crossing terlalu
        % tinggi sehingga kontur objek jarang tertutup (uji 8 citra BSDS)
        [T, modeText] = pickThreshold(S(S > 0), params, 'percentile', 70);
        E = S >= T & S > 0;
        % tampilan seperti slide: uint8(convn(I, H)) memotong nilai negatif,
        % jadi hanya sisi positif tepi yang terlihat terang
        response = stretch(max(R, 0));

    % ---------- Canny (built-in, diizinkan spesifikasi) ----------
    case 'canny'
        % magnitudo gradien citra yang sudah dihaluskan Gaussian sigma = sqrt(2)
        % (sama dengan sigma bawaan edge canny), dipakai untuk tampilan
        % respons dan untuk memilih T_high
        mag = sobelOperator(smooth(G, sqrt(2)));
        S = mag / max(max(mag(:)), eps);
        [T, modeText] = pickThreshold(S(:), params);
        T = min(max(T, 1e-3), 0.999);           % edge() butuh 0 < T_high < 1
        E = cannyOperator(G, [0.4 * T, T]);
        modeText = sprintf('%s (T_high), T_low = %.3f', modeText, 0.4 * T);
        response = stretch(S);

    otherwise
        error('detectEdges:unknownMethod', ...
            'method harus laplace/log/sobel/prewitt/roberts/canny, bukan "%s"', method);
end

E = logical(E);
info = struct('response', response, 'strength', S, 'T', T, 'modeText', modeText);
end


% pelembutan Gaussian, sigma = 0 berarti citra tidak diubah
function Gs = smooth(G, sigma)
if sigma > 0
    Gs = convolve2D(G, gaussianKernel(sigma));
else
    Gs = G;
end
end

% pilih ambang dari nilai kekuatan tepi (skala 0..1)
% defMode / defP: default operator kalau params tidak mengisinya
function [T, txt] = pickThreshold(values, params, defMode, defP)
if nargin < 3
    defMode = 'otsu';
    defP = 90;
end
mode = lower(getFieldOrDefault(params, 'ThresholdMode', ''));
if isempty(mode)
    if isempty(getFieldOrDefault(params, 'Threshold', []))
        mode = defMode;
    else
        mode = 'manual';
    end
end

switch mode
    case 'otsu'
        T = otsuThreshold(values);
        txt = sprintf('Otsu, T = %.3f', T);
    case 'percentile'
        P = getFieldOrDefault(params, 'Percentile', defP);
        T = percentileThreshold(values, P);
        txt = sprintf('Persentil %g, T = %.3f', P, T);
    case 'manual'
        T = getFieldOrDefault(params, 'Threshold', []);
        if isempty(T)
            T = 0.2;
        end
        txt = sprintf('Manual, T = %.3f', T);
    otherwise
        error('detectEdges:unknownThresholdMode', ...
            'ThresholdMode harus otsu/percentile/manual, bukan "%s"', mode);
end
end

% kontras tampilan: dibagi persentil 99 lalu dipotong ke [0, 1], supaya
% beberapa tepi yang sangat kuat tidak membuat tepi lain nyaris hitam
function D = stretch(V)
top = percentileThreshold(V(V > 0), 99);
if top <= 0
    D = zeros(size(V));
else
    D = min(V / top, 1);
end
end
