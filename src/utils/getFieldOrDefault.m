function val = getFieldOrDefault(s, fieldName, defaultVal)
% ambil field dari struct parameter, kalau tidak ada / kosong pakai default.
% tujuan field opsional di params tidak wajib diisi user/GUI.
%
% INPUT:
%   s          - struct parameter (boleh struct kosong)
%   fieldName  - nama field yang dicari
%   defaultVal - nilai yang dipakai kalau field tidak ada / []
%
% OUTPUT:
%   val - nilai field atau defaultVal

if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    val = s.(fieldName);
else
    val = defaultVal;
end
end
