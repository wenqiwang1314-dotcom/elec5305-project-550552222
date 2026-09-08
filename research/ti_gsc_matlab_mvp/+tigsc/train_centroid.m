function model = train_centroid(Xtrain, ytrain, cfg)
%TRAIN_CENTROID Fit all normalization parameters on training samples only.
% Each row of Xtrain is a 20-value time summary. Constant dimensions use
% sigma=1, preserving the legacy threshold. No test statistics are used.
model.mu = mean(Xtrain,1);
model.sigma = std(Xtrain,0,1);
model.sigma(model.sigma<1e-8) = 1;
Ztrain = (Xtrain-model.mu)./model.sigma;
model.centroid = zeros(numel(cfg.labels),size(Ztrain,2));
for c=1:numel(cfg.labels)
    model.centroid(c,:) = mean(Ztrain(ytrain==c,:),1);
end
model.labels = cfg.labels;
model.training_domain = 'synthetic speech-like proxy';
end
