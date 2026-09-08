function [pred, D, Z] = predict_centroid(features, model)
%PREDICT_CENTROID Use mean squared standardized distance; choose its minimum.
% Distances are not probabilities. Do not apply a cosmetic softmax and call
% it a calibrated posterior. This classifier is not a trained TI DSCNN.
Z = (features-model.mu)./model.sigma;
D = zeros(size(Z,1),size(model.centroid,1));
for c=1:size(model.centroid,1)
    D(:,c)=mean((Z-model.centroid(c,:)).^2,2);
end
[~,pred]=min(D,[],2);
end
