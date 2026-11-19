function flag = isHomogeneous(patch, th, predType)
% Mengevaluasi apakah suatu blok citra bersifat homogen atau tidak
%
% INPUT :
%   patch           - submatrix citra grayscale (double 0..1)
%   th              - ambang batas homogenitas (skala 0..1)
%   predType   - 'std' (standar deviasi) atau range (max - min)
%
% OUTPUT :
%   flag            - bernilai true jika region homogine false jika perlu
%   displit

    if numel(patch) <= 1
        flag = true;
        return;
    end

    switch lower(predType)
        case 'std'
            val = std(patch(:));
        case 'range'
            val = max(patch(:)) - min(patch(:));
        otherwise
            error('Error predType');
    end

    flag = (val <= th);
end
