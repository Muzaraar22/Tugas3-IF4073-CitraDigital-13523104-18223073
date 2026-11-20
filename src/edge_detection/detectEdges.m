function E = detectEdges(I, method, params)
% deteksi tepi dengan operator pilihan -> citra tepi biner
%
% INPUT:
%   I      - citra masukan (RGB / grayscale)
%   method - 'laplace' / 'log' / 'sobel' / 'prewitt' / 'roberts' / 'canny'
%   params - (opsional) struct, field yang tidak diisi pakai default:
%     .Sigma     - sigma Gaussian sebelum Sobel/Prewitt/Roberts/Laplace,
%                  0 = tanpa pelembutan                          (default 1.0)
%     .Threshold - ambang magnitudo gradien (skala 0..1),
%                  [] = otomatis dengan Otsu                     (default [])
%     .LogSigma  - sigma mask LoG                                (default 2.0)
%     .ZcScale   - ambang zero-crossing = ZcScale * mean(|R|)
%                  (default 1.5 untuk laplace, 0.75 untuk log)
%     .CannyThreshold - T_high Canny (skala 0..1, T_low = 0.4 * T_high),
%                  [] = otomatis bawaan MATLAB                   (default [])
%
% OUTPUT:
%   E - citra tepi biner (logical), ukuran sama dengan I

if nargin < 3
    params = struct();
end

sigma = getFieldOrDefault(params, 'Sigma', 1.0);

if size(I, 3) == 3
    I = rgb2gray(I);
end
G = im2double(I);   % grayscale double 0..1

switch lower(method)
    % ---------- turunan pertama: gradien + ambang ----------
    case {'sobel', 'prewitt', 'roberts'}
        Gs = smooth(G, sigma);   % redam derau dulu supaya tidak jadi tepi
        switch lower(method)
            case 'sobel',   mag = sobelOperator(Gs);
            case 'prewitt', mag = prewittOperator(Gs);
            case 'roberts', mag = robertsOperator(Gs);
        end

        % normalisasi ke [0, 1] supaya ambang tidak bergantung skala citra
        mag = mag / max(max(mag(:)), eps);

        T = getFieldOrDefault(params, 'Threshold', []);
        if isempty(T)
            T = otsuThreshold(mag);
        end
        % mag > 0 supaya daerah datar tidak ikut jadi tepi kalau T = 0
        E = mag >= T & mag > 0;

    % ---------- turunan kedua: zero-crossing ----------
    case 'laplace'
        R = laplaceOperator(smooth(G, sigma));
        zcScale = getFieldOrDefault(params, 'ZcScale', 1.5);
        E = zeroCrossing(R, zcScale * mean(abs(R(:))));

    case 'log'
        R = logOperator(G, getFieldOrDefault(params, 'LogSigma', 2.0));
        zcScale = getFieldOrDefault(params, 'ZcScale', 0.75);
        E = zeroCrossing(R, zcScale * mean(abs(R(:))));

    % ---------- Canny (built-in, diizinkan spesifikasi) ----------
    case 'canny'
        % otomatis: T_high = persentil 70 gradien, jadi ~30% piksel selalu
        % jadi kandidat tepi -> pada citra berderau lebih baik diisi manual
        E = cannyOperator(G, getFieldOrDefault(params, 'CannyThreshold', []));

    otherwise
        error('detectEdges:unknownMethod', ...
            'method harus laplace/log/sobel/prewitt/roberts/canny, bukan "%s"', method);
end

E = logical(E);
end


% pelembutan Gaussian, sigma = 0 berarti citra tidak diubah
function Gs = smooth(G, sigma)
if sigma > 0
    Gs = convolve2D(G, gaussianKernel(sigma));
else
    Gs = G;
end
end
