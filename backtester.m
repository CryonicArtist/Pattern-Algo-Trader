%% 1. Setup: Create 1 Day of 5-Minute Data
clear; clc; close all;

% Define Time
startTime = datetime(2023,1,1,9,30,0);
endTime = datetime(2023,1,1,16,0,0);
timeVector = (startTime : minutes(5) : endTime)';
numBars = length(timeVector);

% Generate Synthetic Data
rng(42); 
volatility = 0.2; 
startPrice = 150;
change = randn(numBars, 1) * volatility;
closeP = startPrice + cumsum(change);

%% 2. Calculate StochRSI Manually
rsiPeriod = 14; stochPeriod = 14; 
smoothK = 3; smoothD = 3;

% Standard RSI
rawRSI = rsindex(closeP, rsiPeriod);

% StochRSI Calculation
stochRsiRaw = nan(size(rawRSI));
for i = (rsiPeriod + stochPeriod):length(rawRSI)
    rsiWindow = rawRSI(i-stochPeriod+1 : i);
    minRSI = min(rsiWindow); maxRSI = max(rsiWindow);
    if maxRSI - minRSI == 0, stochRsiRaw(i) = 0;
    else, stochRsiRaw(i) = (rawRSI(i) - minRSI) / (maxRSI - minRSI); end
end

% Smoothing (%K and %D)
stochRsiRaw = stochRsiRaw * 100; 
K = nan(size(stochRsiRaw));
for i = smoothK:length(stochRsiRaw), K(i) = mean(stochRsiRaw(i-smoothK+1 : i)); end
D = nan(size(K));
for i = smoothD:length(K), D(i) = mean(K(i-smoothD+1 : i)); end

%% 3. Run Strategy Logic (With Filter)
buySignal = nan(size(closeP));
sellSignal = nan(size(closeP));

for t = 2:numBars
    currK = K(t);       prevK = K(t-1);
    currD = D(t);       prevD = D(t-1);
    
    if isnan(currK) || isnan(currD) || isnan(prevK) || isnan(prevD), continue; end

    % --- MODIFIED BUY RULE ---
    % 1. Crossover: K crosses OVER D
    % 2. Filter: Must be BELOW 60
    if (prevK < prevD) && (currK > currD) && (currK < 60)
        buySignal(t) = closeP(t);
    end

    % --- ORIGINAL SELL RULE ---
    % 1. Crossover: K crosses UNDER D (No filter applied)
    if (prevK > prevD) && (currK < currD)
        sellSignal(t) = closeP(t);
    end
end

%% 4. Night Mode Visualization (Aligned)
fig = figure('Position', [100, 100, 1200, 800], 'Color', [0.15 0.15 0.15]);

% Top Plot: Price Action
ax1 = subplot(2,1,1);
set(ax1, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9], ...
         'GridColor', [1 1 1], 'GridAlpha', 0.15);
hold on;
plot(timeVector, closeP, 'w-', 'LineWidth', 1.5);
plot(timeVector, buySignal, '^', 'Color', '#00FF00', 'MarkerFaceColor', '#00FF00', 'MarkerSize', 8);
plot(timeVector, sellSignal, 'v', 'Color', '#FF0000', 'MarkerFaceColor', '#FF0000', 'MarkerSize', 8);
title('Price Action (Buy Filter: < 60)', 'Color', 'w');
ylabel('Price ($)');
legend('Price', 'Filtered Buy (<60)', 'Sell (Any)', 'TextColor', 'w', 'Color', [0.2 0.2 0.2]);
grid on;

% Bottom Plot: StochRSI
ax2 = subplot(2,1,2);
set(ax2, 'Color', [0.1 0.1 0.1], 'XColor', [0.9 0.9 0.9], 'YColor', [0.9 0.9 0.9], ...
         'GridColor', [1 1 1], 'GridAlpha', 0.15);
hold on;
plot(timeVector, K, 'c-', 'LineWidth', 1.5); 
plot(timeVector, D, 'm-', 'LineWidth', 1.5); 

% Plot the new Threshold Line (60)
yline(60, '--', 'Label', 'Buy Filter (60)', 'Color', 'y', 'LabelHorizontalAlignment', 'left');
yline(20, '--', 'Color', [0.5 0.5 0.5]);
yline(80, '--', 'Color', [0.5 0.5 0.5]);

title('StochRSI', 'Color', 'w');
ylabel('0 - 100');
grid on;

% Link Axes
linkaxes([ax1, ax2], 'x');
xlim(ax1, [startTime endTime]);