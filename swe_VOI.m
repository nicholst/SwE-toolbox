function [TabDat,xSVC] = swe_VOI(SwE,xSwE,hReg,xY)
% List of local maxima and adjusted p-values for a small Volume of Interest
% =========================================================================
% FORMAT [TabDat,xSVC] = swe_VOI(SwE,xSwE,hReg,[xY])
% -------------------------------------------------------------------------
% Inputs:
% 
% SwE    - Structure containing analysis details (see spm_spm)
%
% xSwE   - Structure containing SwE, distribution & filtering details
%          Required fields are:
% .swd     - SwE working directory - directory containing current SwE.mat
% .Z       - minimum of n Statistics {filtered on u and k}
% .n       - number of conjoint tests
% .STAT    - distribution {Z, T, X or F}
% .df      - degrees of freedom [df{interest}, df{residual}]
% .u       - height threshold
% .k       - extent threshold {resels}
% .XYZ     - location of voxels {voxel coords}
% .XYZmm   - location of voxels {mm}
% .S       - search Volume {voxels}
% .R       - search Volume {resels}
% .FWHM    - smoothness {voxels}
% .M       - voxels -> mm matrix
% .VOX     - voxel dimensions {mm}
% .DIM     - image dimensions {voxels} - column vector
% .Vspm    - mapped statistic image(s)
% .Ps      - uncorrected P values in searched volume (for voxel FDR)
% .Pp      - uncorrected P values of peaks (for peak FDR)
% .Pc      - uncorrected P values of cluster extents (for cluster FDR)
% .uc      - 0.05 critical thresholds for FWEp, FDRp, FWEc, FDRc
%
% hReg   - Handle of results section XYZ registry (see spm_results_ui.m)
% xY     - VOI structure
%
% TabDat - Structure containing table data (see spm_list.m)
% xSVC   - Thresholded xSwE data (see spm_getSwE.m)
%__________________________________________________________________________
%
% spm_VOI is  called by the SwE results section and takes variables in
% SwE to compute p-values corrected for a specified volume of interest.
%
% The volume of interest may be defined as a box or sphere centred on
% the current voxel or by a mask image.
%
% If the VOI is defined by a mask this mask must have been defined
% independently of the SwE (e.g. using a mask based on an orthogonal
% contrast).
%
% External mask images should be in the same orientation as the SwE
% (i.e. as the input used in stats estimation). The VOI is defined by
% voxels with values greater than 0.
%
% See also: spm_list
% Adapted version of `spm_VOI.m`. 
% Author of Adaptation: Tom Maullin (07/09/2018)
% Version Info:  $Format:%ci$ $Format:%h$
%__________________________________________________________________________
% Copyright (C) 1999-2014 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% Based on: spm_VOI.m 6080 2014-07-01 16:00:22Z guillaume


%-Parse arguments
%--------------------------------------------------------------------------
if nargin < 2, error('Not enough input arguments.'); end
if nargin < 3, hReg = []; end
if nargin < 4, xY = []; end

Num = spm_get_defaults('stats.results.svc.nbmax');   % maxima per cluster
Dis = spm_get_defaults('stats.results.svc.distmin'); % distance among maxima {mm}

%-Title
%--------------------------------------------------------------------------
spm('FigName',['SwE{',xSwE.STAT,'}: Small Volume Correction']);

%-Warning, if this is a WB analysis.
%--------------------------------------------------------------------------
if xSwE.WB
    warning(['No FWE (voxel or cluster) results available for small ',...
             'volumes. Create a new WB analysis with a restricted ',...
             'analysis mask to obtain FWE results on a small volume.'])
end

%-Get current location {mm}
%--------------------------------------------------------------------------
try
    xyzmm  = xY.xyz;
catch
    xyzmm  = spm_results_ui('GetCoords');
end
    
%-Specify search volume
%--------------------------------------------------------------------------
if isfield(xY,'def')
    switch xY.def
        case 'sphere'
            SPACE = 'S';
        case 'box'
            SPACE = 'B';
        case 'mask'
            SPACE = 'I';
        otherwise
            error('Unknown VOI type.');
    end
else
    str    = sprintf(' at [%.0f,%.0f,%.0f]',xyzmm(1),xyzmm(2),xyzmm(3));
    SPACE  = spm_input('Search volume...',-1,'m',...
             {['Sphere',str],['Box',str],'Image'},['S','B','I']);
end

%-Voxels in entire search volume {mm}
%--------------------------------------------------------------------------
XYZmm      = SwE.xVol.M(1:3,:)*[SwE.xVol.XYZ; ones(1, SwE.xVol.S)];
Q          = ones(1,size(xSwE.XYZmm,2));
O          = ones(1,size(     XYZmm,2));


switch SPACE

    case 'S' %-Sphere
    %----------------------------------------------------------------------
    if ~isfield(xY,'spec')
        D  = spm_input('radius of VOI {mm}',-2);
    else
        D  = xY.spec;
    end
    str    = sprintf('%0.1fmm sphere',D);
    j      = find(sum((xSwE.XYZmm - xyzmm*Q).^2) <= D^2);
    k      = find(sum((     XYZmm - xyzmm*O).^2) <= D^2);
    D      = D./xSwE.VOX;


    case 'B' %-Box
    %----------------------------------------------------------------------
    if ~isfield(xY,'spec')
        D  = spm_input('box dimensions [k l m] {mm}',-2);
    else
        D  = xY.spec;
    end
    if length(D)~=3, D = ones(1,3)*D(1); end
    str    = sprintf('%0.1f x %0.1f x %0.1f mm box',D(1),D(2),D(3));
    j      = find(all(abs(xSwE.XYZmm - xyzmm*Q) <= D(:)*Q/2));
    k      = find(all(abs(     XYZmm - xyzmm*O) <= D(:)*O/2));
    D      = D./xSwE.VOX;


    case 'I' %-Mask Image
    %----------------------------------------------------------------------
    if ~isfield(xY,'spec')
        [VM,sts] = spm_select([1 Inf],'image','Image defining search volume');
        if ~sts, TabDat = []; xSVC = []; return; end
    else
        VM = xY.spec;
    end
    D      = spm_data_hdr_read(VM);
    if numel(D) > 1
        fprintf('Computing union of all masks.\n');
        spm_check_orientations(D);
        D2 = struct(...
            'fname',   ['virtual_SVC_mask' spm_file_ext],...
            'dim',     D(1).dim,...
            'dt',      [spm_type('uint8') spm_platform('bigend')],...
            'mat',     D(1).mat,...
            'n',       1,...
            'pinfo',   [1 0 0]',...
            'descrip', 'SVC mask');
        D2.dat     = false(D2.dim);
        for i=1:numel(D)
            D2.dat = D2.dat | swe_data_read(D(i));
        end
        D2.dat     = uint8(D2.dat);
        D  = D2;
    end
    str    = spm_file(D.fname,'short30');
    str    = regexprep(str, {'\\' '\^' '_' '{' '}'}, ...
        {'\\\\' '\\^' '\\_' '\\{' '\\}'}); % Escape TeX special characters
    str    = sprintf('image mask: %s',str); 
    VOX    = sqrt(sum(D.mat(1:3,1:3).^2));
    XYZ    = D.mat \ [xSwE.XYZmm; ones(1, size(xSwE.XYZmm, 2))];
    j      = find(spm_sample_vol(D, XYZ(1,:), XYZ(2,:), XYZ(3,:),0) > 0);
    XYZ    = D.mat \ [     XYZmm; ones(1, size(     XYZmm, 2))];
    k      = find(spm_sample_vol(D, XYZ(1,:), XYZ(2,:), XYZ(3,:),0) > 0);

end

xSwE.S     = length(k);
xSwE.Z     = xSwE.Z(j);
xSwE.XYZ   = xSwE.XYZ(:,j);
xSwE.XYZmm = xSwE.XYZmm(:,j);

%-Restrict FDR to the search volume
%--------------------------------------------------------------------------
STAT       = xSwE.STAT;
DIM        = xSwE.DIM;
n          = xSwE.n;
Vspm       = xSwE.Vspm;
u          = xSwE.u;
S          = xSwE.S;
xSwE.svc   = true;

try, xSwE.Ps = xSwE.Ps(k); end
try, xSwE.uc          = [uu up ue uc]; end

%-Tabulate p values
%--------------------------------------------------------------------------
str        = sprintf('search volume: %s',str);
if any(strcmp(SPACE,{'S','B'}))
    str = sprintf('%s at [%.0f,%.0f,%.0f]',str,xyzmm(1),xyzmm(2),xyzmm(3));
end

TabDat     = swe_list('List',xSwE,hReg,Num,Dis,str);

if nargout > 1, xSVC = xSwE; end

%-Reset title
%--------------------------------------------------------------------------
spm('FigName',['SwE{',xSwE.STAT,'}: Results']);
