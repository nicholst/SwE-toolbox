function status = swe_matlab_version_chk(varargin)
% Replacement for depricated spm_matlab_version_chk
% =========================================================================
% FORMAT:  status = spm_matlab_version_chk(chk,tbx)
% -------------------------------------------------------------------------
%  
% If spm_matlab_version_chk exists it is used; otherwise its replacement
% spm_check_version is used.
%
% =========================================================================
% Version Info:  $Format:%ci$ $Format:%h$

if exist('spm_matlab_version_chk')==2
    status = spm_matlab_version_chk(varargin{:})
else
    if nargin==0
        error('No input!')
    elseif nargin>=1
        chk=varargin{1};
        status = spm_check_version('matlab',chk);
        if nargin>=2
            tbx=varargin{2};
            status = spm_check_version(tbx,chk);
        end
    end
end

    