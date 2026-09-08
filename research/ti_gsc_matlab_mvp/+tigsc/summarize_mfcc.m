function features = summarize_mfcc(M)
%SUMMARIZE_MFCC Produce the existing centroid baseline's 20-value input.
% The first 10 values are temporal means; the next 10 are sample standard
% deviations (N-1 denominator). The 49 x 10 map remains the feature export.
% This time pooling is a baseline-only branch, not a DSCNN input transform.
features = [mean(M,1), std(M,0,1)];
end
