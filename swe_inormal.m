function swe_inormal
% Apply rank inverse normal transformation
% FORMAT swe_inormal
%
% For a selected set of images, apply the rank inverse normal tranformation, 
% writing out a copy of the input images with a "_iN" suffix.
%
% Depends on PALM's palm_inormal.m; see 
% https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/PALM
%
%____________________________________________________________________________
% T. Nichols Feb 2019

P = spm_select(Inf,'image');
V = spm_vol(P);
X = spm_read_vols(V);
DIM = size(X);
X = reshape(X,[prod(DIM(1:3)) DIM(4)])';
XiN = swe_palm_inormal(X).*std(X)+mean(X);
Vo = V;
for i=1:length(Vo)
  [Path,Img,Ext] = spm_fileparts(V(i).fname);
  Vo(i).fname = fullfile(Path,[Img '_iN' Ext]);
  Vo(i).pinfo = [1 0 0]';
  Vo(i).dt(1) = spm_type('float32');
  Vo(i).descrip = [ Vo(i).descrip ' iNormal' ];
  Vo(i) = spm_write_vol(Vo(i),reshape(XiN(i,:),[DIM(1:3)]));
end
