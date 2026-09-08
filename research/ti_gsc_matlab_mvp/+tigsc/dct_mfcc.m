function [M, C] = dct_mfcc(logMel, cfg)
%DCT_MFCC Apply an orthonormal DCT-II and retain c0 through c9.
% C(k+1,q+1)=alpha(k)*cos(pi/40*(q+0.5)*k), alpha(0)=sqrt(1/40),
% alpha(k>0)=sqrt(2/40). c0 is retained, with no energy replacement,
% liftering, cepstral normalization, delta or delta-delta coefficients.
% Transpose once to make rows=time frames and columns=MFCC coefficients.
n = cfg.num_mel; k = (0:cfg.num_mfcc-1)'; q = 0:n-1;
C = cos(pi/n*(q+0.5).*k);
C(1,:) = C(1,:)*sqrt(1/n);
C(2:end,:) = C(2:end,:)*sqrt(2/n);
M = (C*logMel).';
end
