function [windowed, w] = window_frames(frames)
%WINDOW_FRAMES Apply the original symmetric (not periodic) Hamming window.
% w[n]=0.54-0.46*cos(2*pi*n/(L-1)), n=0,...,L-1. Multiplication reduces
% edge discontinuities; no pre-emphasis, gain normalization or DC removal
% is inserted. Changing any of those would change the original features.
L = size(frames,1);
w = 0.54 - 0.46*cos(2*pi*(0:L-1)'/(L-1));
windowed = frames.*w;
end
