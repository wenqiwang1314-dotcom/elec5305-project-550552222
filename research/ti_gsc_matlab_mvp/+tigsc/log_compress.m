function logMel = log_compress(E)
%LOG_COMPRESS Apply the legacy absolute floor followed by the natural log.
% ln(max(E,1e-10)) prevents log(0). It is neither log10 nor decibels.
% Preserve the absolute floor; a data-dependent epsilon changes quiet bins.
logMel = log(max(E,1e-10));
end
